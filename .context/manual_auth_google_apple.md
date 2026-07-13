# Manual de Auth con Google + Apple Sign-In en Flutter

Manual reusable para implementar autenticación con **Google Sign-In** + **Apple Sign-In** + **anónimo de fallback** + **persistencia automática** + **delete account** (requisito Apple Store) en Flutter.

Consolida la experiencia real de **QueHacemos Córdoba** (Play Store + App Store): 6 commits de iteración del login en agosto 2025, un rollback de 30 minutos, un rechazo de Apple por falta de delete account, **un descubrimiento sobre la persistencia en `google_sign_in v7` que NO está en docs oficiales** (publicado en r/FlutterDev y rechazado por sospecha de IA — ver §8), y 3 bugs vivos en producción que se documentan acá para que no los copies.

Si arrancás un proyecto nuevo con auth social, copiá este flujo entero antes de improvisar.

---

## 1. ¿Cuándo usar este patrón?

Usalo si:
- Querés autenticar usuarios sin levantar tu propio backend.
- Necesitás Apple Sign-In porque vas a publicar en App Store y mostrás Google Sign-In (Apple lo exige por reglas de la store).
- Te alcanza con identidad + email + foto de perfil + UID estable (sin claims custom, sin tabla de roles).

NO lo uses si:
- Necesitás claims custom o flujos complejos de roles → usar Firebase Auth con Cloud Functions o backend propio con tokens JWT firmados.
- Tu app es solo Android y no querés depender de Google → preferí auth con magic link (email link) o phone auth.
- Manejás datos sensibles que requieran MFA fuerte → Firebase soporta MFA pero el flujo es más complejo que esto.

**Decisión clave:** Firebase Auth ya persiste la sesión cross-restart **sin que escribas una línea de código** para eso. No te dejes tentar por "guardar el email del último login" en SharedPreferences ni por sincronizar el `User` con Firestore. Es trabajo perdido (ver §12 — lecciones de iteración).

---

## 2. Stack mínimo

```yaml
# pubspec.yaml
dependencies:
  firebase_core: ^4.1.1          # init Firebase
  firebase_auth: ^6.1.0          # Auth core + authStateChanges + reauth + delete
  google_sign_in: ^7.2.0         # OAuth Google (API 2025: GoogleSignIn.instance + authenticate)
  sign_in_with_apple: ^7.0.1     # Apple ID + nonce CSRF
  crypto: ^3.0.6                 # SHA-256 del nonce de Apple
  flutter_dotenv: ^5.1.0         # .env para serverClientId + Firebase keys
```

Versiones leídas de `pubspec.lock` de QueHacemos en producción (mayo 2026). Las **transitivas** que importan:
- `google_sign_in_ios: 6.2.1` — Plugin nativo iOS, lee `GoogleService-Info.plist` para resolver client IDs.
- `sign_in_with_apple_platform_interface: 2.0.0`.
- `firebase_auth_platform_interface: 8.1.2`.

> **Migración del API de google_sign_in.** En v6 (legacy) usabas `GoogleSignIn().signIn()` (instancia + método `signIn`). En v7 (2025) es `GoogleSignIn.instance` + `await initialize(serverClientId: ...)` + `authenticate(scopeHint: ['email'])`. Si tenés código viejo, no compila contra v7 — refactor obligatorio. Repo viejo de QueHacemos `repo2_keaCmos` aún tenía la API legacy (`final _googleSignIn = GoogleSignIn();` con `signIn()`); fue reescrito íntegro en agosto 2025.

---

## 3. Setup Android

### 3.1 Firebase + google-services.json

1. En Firebase Console → tu proyecto → ícono Android → registrar app.
2. Bajar `google-services.json` y poner en `android/app/`.
3. En `android/app/build.gradle.kts`:

```kotlin
plugins {
  id("com.google.gms.google-services")    // al final del bloque plugins
}
```

Y en `android/build.gradle.kts` (proyecto):

```kotlin
plugins {
  id("com.google.gms.google-services") version "4.4.0" apply false
}
```

> **Flutter 3.x (settings.gradle.kts):** En proyectos generados con Flutter 3.x el plugin management se hace en `android/settings.gradle.kts`, no en `build.gradle.kts` raíz. Si `android/build.gradle.kts` raíz no tiene bloque `plugins {}`, agregá el plugin en `settings.gradle.kts` así:
>
> ```kotlin
> // android/settings.gradle.kts
> plugins {
>     id("dev.flutter.flutter-plugin-loader") version "1.0.0"
>     id("com.android.application") version "8.x.x" apply false
>     id("org.jetbrains.kotlin.android") version "x.x.x" apply false
>     id("com.google.gms.google-services") version "4.4.0" apply false  // ← agregar esta línea
> }
> ```
>
> Sin este entry el build falla con un error críptico de plugin no encontrado, aunque el `google-services.json` esté en su lugar. Verificado al armar el repo demo en mayo 2026.

### 3.2 SHA-1 / SHA-256 fingerprints

**Crítico** para Google Sign-In en Android. Si los fingerprints no están registrados en Firebase Console, el sign-in retorna error genérico tipo `ApiException 10` y nunca te enterás del motivo real.

```bash
# debug
cd android && ./gradlew signingReport

# release (después de generar tu keystore)
keytool -list -v -keystore release.jks -alias key
```

Pegar **SHA-1 y SHA-256** ambos en Firebase Console → Project Settings → Your Android App → Add Fingerprint. Después bajar **un nuevo `google-services.json`** y reemplazar el viejo.

> **Bug clásico**: agregar SHA pero olvidar bajar el JSON nuevo. La compilación pasa, pero el sign-in falla en runtime sin mensaje claro.

### 3.3 AndroidManifest.xml

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
```

**No hace falta nada más para Google Sign-In en Android** con `google_sign_in: ^7.2.0`. El plugin no requiere intent-filters ni Activities adicionales — usa Activity transient internamente.

Verificado en repo3 `android/app/src/main/AndroidManifest.xml:5-7` (publicado en Play Store).

### 3.4 ProGuard / R8

Si tu `build.gradle.kts` tiene `isMinifyEnabled = true`, en general Firebase Auth + Google Sign-In funcionan sin keep rules específicas porque tienen sus propias `consumer-rules.pro`. Pero verificalo en release con un device real antes de subir a Play Store: hubo casos en plugins pasados donde R8 ofuscaba clases internas de OAuth.

---

## 4. Setup iOS

iOS requiere más fricción que Android. Hay dos caminos: hacerlo a mano (rápido para desarrollo, doloroso para release) o **inyectar todo desde Codemagic** (lo que hace QueHacemos en producción).

### 4.1 Apple Sign-In capability — el entitlement obligatorio

Apple Sign-In **REQUIERE** la capability `com.apple.developer.applesignin` en `ios/Runner/Runner.entitlements`. Sin esto, `SignInWithApple.getAppleIDCredential()` falla en runtime con `AuthorizationErrorCode.unknown` y **el botón de Apple te lo rechaza la App Store** en review.

Contenido mínimo de `Runner.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.applesignin</key>
    <array>
        <string>Default</string>
    </array>
    <key>aps-environment</key>
    <string>production</string>
</dict>
</plist>
```

> **Patrón QueHacemos**: el archivo NO está en el repo. Codemagic lo genera en cada build con un `PlistBuddy` script (ver §4.5). Ventaja: el `aps-environment` puede ser `development` o `production` según el workflow. Desventaja: builds locales no tienen la capability si no la creás vos a mano.

Además, en Apple Developer Console:
- App ID con capability **"Sign In with Apple"** habilitada.
- Si usás Firebase Auth: configurar el Apple provider en Firebase Console con el Service ID + private key (.p8) generados en Apple Developer.

### 4.2 Google Sign-In en iOS — REVERSED_CLIENT_ID + GIDClientID

Google Sign-In iOS necesita 3 cosas en `Info.plist`:

```xml
<!-- 1. URL scheme con REVERSED_CLIENT_ID (callback OAuth) -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.998972257036-xxxxxxxxx</string>
        </array>
    </dict>
</array>

<!-- 2. iOS Client ID (formato 12345-xxx.apps.googleusercontent.com) -->
<key>GIDClientID</key>
<string>998972257036-xxxxxxxxx.apps.googleusercontent.com</string>

<!-- 3. Web Client ID (para idToken Firebase) -->
<key>GIDServerClientID</key>
<string>998972257036-yyyyyyyyy.apps.googleusercontent.com</string>
```

> **REVERSED_CLIENT_ID** es el `GIDClientID` invertido: `com.googleusercontent.apps.<numérico>-<sufijo>`. Lo lee Google Sign-In iOS para validar el callback OAuth.

> **GIDServerClientID** es el **Web Client ID**, NO el iOS Client ID. Confusión común. Si ponés el iOS, el `idToken` que Firebase recibe no valida y `signInWithCredential()` falla con `INVALID_IDP_RESPONSE`.

**Patrón QueHacemos:** Info.plist en el repo NO tiene ninguno de estos 3 campos. Codemagic los inyecta en CI vía PlistBuddy desde env vars (`$IOS_CLIENT_ID`, `$IOS_REVERSED_CLIENT_ID`, `$WEB_CLIENT_ID`). Verificado en `codemagic.yaml:142-170`.

### 4.3 GoogleService-Info.plist

Apple equivalente del `google-services.json`. Contiene Firebase config + Google Sign-In client ID.

Dos opciones:
- **A: lo descargás de Firebase Console** y lo pegás en `ios/Runner/GoogleService-Info.plist`. Simple. Compromete el archivo al repo (decidí si te molesta — son IDs públicos, no API secrets).
- **B (QueHacemos): lo generás en CI** desde env vars. Verificado en `codemagic.yaml:91-139`. El archivo se crea con `cat > ... << 'EOF'`. El repo no contiene credenciales. Rotar claves se hace en Codemagic env vars sin tocar código.

### 4.4 AppDelegate.swift mínimo

```swift
import Flutter
import UIKit
import GoogleSignIn          // ← obligatorio

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // ← obligatorio: callback OAuth de Google
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    return GIDSignIn.sharedInstance.handle(url)
  }
}
```

Verificado en `repo3_quehacemos_desarr/ios/Runner/AppDelegate.swift:1-23`. **No** se llama `FirebaseApp.configure()` acá — `Firebase.initializeApp()` desde Dart se encarga vía `firebase_options.dart`.

> **Sin el override `application(_:open:options:)`** el flujo OAuth de Google "vuelve" a la app pero Google Sign-In nunca recibe el `URL` del callback → el `authenticate()` queda colgado para siempre.

### 4.5 Inyección completa via Codemagic (resumen)

Si usás CI, esto va en `codemagic.yaml` antes del build de iOS:

| Script | Qué hace | Líneas (codemagic.yaml) |
|--------|----------|-------------------------|
| `Generate GoogleService-Info.plist` | `cat > ios/Runner/GoogleService-Info.plist` con `$IOS_CLIENT_ID`, `$IOS_REVERSED_CLIENT_ID`, `$ANDROID_CLIENT_ID`, `$FIREBASE_API_KEY`, etc. | 91-139 |
| `Configure iOS Info.plist for Google Sign In` | `PlistBuddy Add :CFBundleURLTypes` con scheme `$IOS_REVERSED_CLIENT_ID`. | 142-155 |
| `Add GIDClientID to Info.plist` | `PlistBuddy Add :GIDClientID string $IOS_CLIENT_ID` + `:GIDServerClientID string $WEB_CLIENT_ID`. | 157-170 |
| `Enable Sign in with Apple capability` | Crea `ios/Runner/Runner.entitlements` con `com.apple.developer.applesignin` array y `aps-environment`. | 172-204 |
| `Enable Keychain Sharing` | Agrega `keychain-access-groups` con `$(AppIdentifierPrefix)$BUNDLE_ID`. | 205-209 |

Variables que tenés que setear en Codemagic env (encryption ON):
- `IOS_CLIENT_ID`, `IOS_REVERSED_CLIENT_ID`, `ANDROID_CLIENT_ID`, `WEB_CLIENT_ID`
- `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_STORAGE_BUCKET`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_APP_ID_IOS`, `FIREBASE_APP_ID_ANDROID`
- `BUNDLE_ID` (ej. `com.quehacemos.cba`)

> **Trade-off**: con CI inyectando todo, los builds locales no funcionan a menos que crees los archivos a mano. Para desarrollo iOS local, mantené un `Runner.entitlements` y un `GoogleService-Info.plist` en `.gitignore` con valores de tu Firebase de desarrollo.

---

## 5. Inicialización en main.dart (orden CRÍTICO)

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. dotenv ANTES de Firebase (firebase_options lee de dotenv.env)
  await dotenv.load(fileName: ".env");

  // 2. Firebase ANTES de runApp.
  //    authStateChanges depende de FirebaseApp inicializada.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}
```

Y el árbol con providers:

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),  // listener arranca acá
        // ...otros providers
      ],
      child: const _AppContent(),
    );
  }
}

class _AppContentState extends State<_AppContent> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAuthInBackground();
    });
  }

  void _initializeAuthInBackground() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.initializeAuth();   // signInAnonymously() si no hay user
  }
}
```

### Reglas de oro de la inicialización

1. **`Firebase.initializeApp()` SIEMPRE en `main()` antes de `runApp()`.** Si lo movés más tarde (ej. al `initState` del primer widget), el constructor del `AuthProvider` ejecuta `_initializeAuthListener()` antes de tener Firebase listo → el listener queda mal armado y `authStateChanges` nunca emite. **Bug real:** repo1 commit `c80d586 fix loguin` movió `Firebase.initializeApp()` a `_AppContentState._initializeApp()`. **30 minutos después**, `fc34c01 rollbac loguin` lo revirtió porque el auth dejó de funcionar al cold start. Ver §12.

2. **`AuthProvider()` se construye en `MultiProvider` ANTES del primer frame** — el constructor activa `authStateChanges.listen(...)` (ver §7), que va a recibir el user persistido por Firebase no bien Dart procese el siguiente microtask.

3. **`initializeAuth()` corre en `addPostFrameCallback`** — necesita `BuildContext` para los providers. Si lo llamás en `initState` directamente, cuando todavía no se montó el árbol, `Provider.of<AuthProvider>(context, listen: false)` puede fallar.

4. **NO pidas permisos en `main()`.** Esto vale para notif, location, etc. — pero también para Apple/Google: el primer prompt OAuth se dispara desde el botón del LoginModal, nunca al boot.

---

## 6. AuthService — código de referencia

Archivo único, sin estado mutable visible. Toda interacción con Firebase Auth pasa por acá.

```dart
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isGoogleInitialized = false;

  // ── Init ────────────────────────────────────────────────────────────

  Future<void> initializeGoogleSignIn() async {
    if (_isGoogleInitialized) return;
    await _googleSignIn.initialize(
      // Web Client ID (NO el iOS). Sirve para que el idToken valide en Firebase.
      serverClientId: const String.fromEnvironment(
        'GOOGLE_SERVER_CLIENT_ID',
        defaultValue: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com',
      ),
    );
    _isGoogleInitialized = true;
  }

  // ── Anonymous (fallback para que SIEMPRE haya user) ─────────────────

  Future<User?> signInAnonymously() async {
    try {
      final result = await _auth.signInAnonymously();
      return result.user;
    } catch (e) {
      return null;   // sin red → sigue sin user, la app no debe explotar
    }
  }

  // ── Google Sign-In (API v7 2025) ────────────────────────────────────

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await initializeGoogleSignIn();
      if (!_googleSignIn.supportsAuthenticate()) return null;

      final googleUser = await _googleSignIn.authenticate(scopeHint: ['email']);
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
      final result = await _auth.signInWithCredential(credential);

      // Notificación in-app de bienvenida (opcional)
      _notifyLoginSuccess(result.user);
      return result;
    } catch (e) {
      // El plugin lanza con "cancel" cuando el user cierra el dialog → no es error
      if (!e.toString().contains('cancel')) {
        _notifyLoginError();
      }
      return null;
    }
  }

  // ── Apple Sign-In (iOS only, con nonce CSRF) ────────────────────────

  Future<UserCredential?> signInWithApple() async {
    try {
      if (!Platform.isIOS) return null;
      if (!await SignInWithApple.isAvailable()) return null;

      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      // accessToken: appleCredential.authorizationCode → CRÍTICO en producción.
      // Sin él, ciertos flujos server-side de Firebase no validan correctamente.
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );
      final result = await _auth.signInWithCredential(oauthCredential);

      // Apple no siempre manda displayName en el primer login.
      // Si el user dio nombre y Firebase no lo tiene, lo seteamos manualmente.
      if (result.user?.displayName == null && appleCredential.givenName != null) {
        await result.user?.updateDisplayName(
          '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'.trim(),
        );
      }

      _notifyLoginSuccess(result.user);
      return result;
    } catch (e) {
      if (!e.toString().contains('cancel')) {
        _notifyLoginError();
      }
      return null;
    }
  }

  // ── Sign Out (vuelve a anónimo) ─────────────────────────────────────

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      await signInAnonymously();   // mantenemos invariante: SIEMPRE hay user
    } catch (_) {
      // silencioso — no interrumpir UX
    }
  }

  // ── Delete Account (con re-auth obligatoria) ────────────────────────

  Future<bool> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.isAnonymous) return false;

      final reAuthOk = await _reauthenticateUser(user);
      if (!reAuthOk) return false;

      await user.delete();           // borra de Firebase Auth
      await signInAnonymously();     // restaura invariante
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _reauthenticateUser(User user) async {
    try {
      final providerId = user.providerData.first.providerId;

      if (providerId == 'google.com') {
        await initializeGoogleSignIn();
        final googleUser = await _googleSignIn.authenticate(scopeHint: ['email']);
        final googleAuth = googleUser.authentication;
        final credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
        await user.reauthenticateWithCredential(credential);
        return true;
      }

      if (providerId == 'apple.com' && Platform.isIOS) {
        final rawNonce = _generateNonce();
        final nonce = _sha256ofString(rawNonce);
        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [AppleIDAuthorizationScopes.email],
          nonce: nonce,
        );
        final credential = OAuthProvider('apple.com').credential(
          idToken: appleCredential.identityToken,
          rawNonce: rawNonce,
        );
        await user.reauthenticateWithCredential(credential);
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Stream + getters ────────────────────────────────────────────────

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  bool get isLoggedIn => currentUser != null && !currentUser!.isAnonymous;
  bool get isAnonymous => currentUser?.isAnonymous ?? true;

  // ── Helpers nonce Apple ─────────────────────────────────────────────

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }
}
```

### Notas sobre el código

- **`serverClientId` desde `String.fromEnvironment`** (line 23-24 de QueHacemos `auth_service.dart`). Permite override en build. Verificado en producción.
- **`if (!e.toString().contains('cancel'))`** — el plugin lanza una excepción cuyo mensaje contiene `"cancel"` cuando el user toca afuera o cancela el dialog. NO es error real. Filtralo antes de mostrar notificación.
- **`accessToken: appleCredential.authorizationCode`** — agregado tardíamente en repo3 (línea 97 de `auth_service.dart`). Sin esto, repo1 tenía un bug donde Apple Sign-In funcionaba "a veces" en Firebase.
- **`signInWithApple` revisa `Platform.isIOS` Y `SignInWithApple.isAvailable()`** — ambos. El primero descarta Android. El segundo descarta iOS muy viejos (<13) o builds con la capability faltante.
- **Apple `displayName` workaround** — Apple solo manda nombre en el PRIMER login. Si tu app reinstalla después, ya nunca recibís el nombre. Por eso lo guardás vía `updateDisplayName` cuando llega.
- **`signOut()` es silencioso por diseño** — `_googleSignIn.signOut()` puede tirar si Google ya estaba desconectado. No tenés nada que mostrar al usuario por eso. Tragar la excepción y seguir.

---

## 7. AuthProvider — ChangeNotifier reactivo

```dart
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = false;

  // Getters expuestos a UI
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _authService.isLoggedIn;
  bool get isAnonymous => _authService.isAnonymous;

  String get userName {
    if (!isLoggedIn) return 'Usuario';
    return _user?.displayName ?? _user?.email?.split('@')[0] ?? 'Usuario';
  }

  String get userEmail => isLoggedIn ? (_user?.email ?? '') : '';
  String get userPhotoUrl => _user?.photoURL ?? '';

  /// Iniciales del avatar:
  /// - "Mario García" → "MG"
  /// - "mario@gmail.com" → "M"
  /// - anónimo → "?"
  String get userInitials {
    if (!isLoggedIn) return '?';
    final name = _user?.displayName;
    if (name != null && name.isNotEmpty) {
      final parts = name.trim().split(' ');
      if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      return parts[0][0].toUpperCase();
    }
    final email = _user?.email;
    if (email != null && email.isNotEmpty) return email[0].toUpperCase();
    return '?';
  }

  /// Color determinista del avatar (mismo email → mismo color, sin guardar nada).
  Color getAvatarColor() {
    if (!isLoggedIn) return Colors.grey.withAlpha(179);
    final email = _user?.email ?? '';
    if (email.isEmpty) return Colors.blue;
    final colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple,
      Colors.red,  Colors.teal,  Colors.indigo, Colors.pink,
    ];
    return colors[email.hashCode.abs() % colors.length];
  }

  AuthProvider() {
    _initializeAuthListener();
  }

  /// CLAVE PARA LA PERSISTENCIA: este listener emite el user restaurado por
  /// Firebase Auth al startup, ANTES de que la UI se construya.
  void _initializeAuthListener() {
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      notifyListeners();
    });
    _user = _authService.currentUser;
  }

  /// Llamado desde main.dart en addPostFrameCallback.
  /// - Si Firebase ya tiene user persistido (anónimo o real): no hace nada (el listener ya actualizó).
  /// - Si no: dispara signInAnonymously para que SIEMPRE haya user.
  Future<void> initializeAuth() async {
    _isLoading = true;
    notifyListeners();
    try {
      final existingUser = _authService.currentUser;
      if (existingUser != null && !existingUser.isAnonymous) {
        // ya logueado — el listener ya emitió, no hacemos nada
      } else {
        await _authService.signInAnonymously();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true; notifyListeners();
    try {
      final result = await _authService.signInWithGoogle();
      return result != null;
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  Future<bool> signInWithApple() async {
    _isLoading = true; notifyListeners();
    try {
      final result = await _authService.signInWithApple();
      return result != null;
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  Future<bool> deleteAccount() async {
    _isLoading = true; notifyListeners();
    try {
      return await _authService.deleteAccount();
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true; notifyListeners();
    try {
      await _authService.signOut();
    } finally {
      _isLoading = false; notifyListeners();
    }
  }
}
```

### Notas

- **El listener se conecta en el constructor.** No hace falta `dispose`: cuando el `AuthProvider` muere (cierre de app), Firebase también muere — no hay leaks reales. Si te preocupa pruritus, guardá la `StreamSubscription` y cancelala en `dispose()`.
- **`notifyListeners()` en cada cambio** — `Consumer<AuthProvider>` arriba se rebuilds y la UI refresca. Sin loading "modal" propio: el `isLoading` lo lee la vista.
- **`getAvatarColor()` con `email.hashCode % 8`** — 8 colores en producción, no 10 como decía un doc viejo de QueHacemos (caso de "doc desactualizado", documenté la diferencia). 8 alcanzan: la probabilidad de colisión visual no importa porque el color es un detalle estético.

---

## 8. Persistencia automática — el hallazgo "v7 = llave, Firebase = casa"

> **Esta es la sección más importante del manual.** La solución que sigue **NO está en la documentación oficial** del plugin `google_sign_in`. La descubrió QueHacemos en agosto 2025 después de tres días de iteraciones épicas. Al intentar publicarla en r/FlutterDev fue rechazada por sospecha de "respuesta hecha con IA" porque **invierte la intuición** que tienen miles de devs migrando de v6 a v7.
>
> **Contexto histórico:** el insight emergió iterando entre varios asistentes IA en chat web, en una época en que ninguno podía buscar en internet ni leer issues de GitHub. La solución se construyó únicamente a fuerza de pensar el problema en voz alta y descartar caminos. Las citas que aparecen en este §8 son del intercambio real donde el "click" finalmente sucedió.

### 8.1 El problema que rompe v7

En **google_sign_in v6** (legacy):
- `GoogleSignIn().signInSilently()` re-autenticaba en background al cold start.
- `_googleSignIn.currentUser` quedaba poblado tras el restart.
- La gente armaba mental model: "google_sign_in mantiene la sesión Google, Firebase Auth solo la valida".

En **google_sign_in v7** (2025) — breaking changes:
- **`signInSilently()` fue eliminado** del API. No compila.
- `attemptLightweightAuthentication()` parece reemplazarlo, **pero muestra UI**: el usuario ve un dialog/transition aunque sea fugaz. **NO es silent.** Confirmado en repo1 commit `9407247` cuando lo probaron.
- `_googleSignIn.currentUser` queda `null` al cold start, **siempre**.
- Resultado: si tu mental model era el de v6, todos tus users "se desloguean" cada vez que el SO mata la app.

**"Soluciones" comunes que NO funcionan en v7:**

| Intento | Por qué falla |
|---------|---------------|
| Llamar `signInSilently()` | No compila — método removido |
| Llamar `attemptLightweightAuthentication()` | Muestra UI, no es silent |
| Cachear último email/foto en SharedPreferences | Simula UI logueada pero no es sesión real — y Firebase ya tenía el user persistido aparte |
| Sincronizar el `User` en Firestore | Trabajo perdido — Firestore no resuelve sesión OAuth |
| Caching manual de tokens | Frágil, complejo, cae en cuanto Google rota algo |

### 8.2 El insight

> **"Google Sign-In v7 should be treated as 'the key to open the front door' — once you're inside, Firebase Auth is your permanent residence."**

Esa es la frase que QueHacemos publicó en r/FlutterDev y que les rechazaron. Operacionalmente significa:

- `google_sign_in` se usa **una sola vez por sesión nueva**: el handshake inicial que produce el `idToken`.
- Después del handshake, **`google_sign_in` queda fuera del flujo de persistencia**.
- La sesión la mantiene **`firebase_auth`**, no el plugin de Google.
- `firebase_auth` guarda tokens en almacenamiento nativo seguro:
  - **iOS**: Keychain.
  - **Android**: EncryptedSharedPreferences.
- Al cold start, `Firebase.initializeApp()` los lee.
- El stream `_auth.authStateChanges()` emite el `User` restaurado **antes** de que la UI se construya.
- Tu listener (`AuthProvider._initializeAuthListener`) recibe el evento y llama `notifyListeners()`.
- La UI muestra al user logueado en 50–200ms.

**Tu código no necesita saber qué pasó con `google_sign_in` post-handshake.** Para todos los efectos, después del handshake ese plugin podría desinstalarse y el user seguiría logueado por Firebase.

> **Cita exacta del intercambio donde el problema se nombró por primera vez (agosto 2025):**
>
> *"Estás intentando mantener **DOS sesiones sincronizadas** cuando solo necesitas UNA."*
>
> Hasta que alguien lo dice así, no se ve. La sensación previa es que `google_sign_in` y `firebase_auth` son dos engranajes que tienen que **estar sincronizados**. La verdad es que `google_sign_in` se apaga después del handshake y `firebase_auth` queda como única fuente de verdad.

### 8.3 ¿Por qué nadie lo ve?

> *"Google Sign-In documentation te hace pensar que **necesitás** su SDK para 'mantener la sesión' — cuando en realidad Firebase ya lo hace por vos."*
>
> — del mismo intercambio.

La doc oficial del plugin `google_sign_in` describe minuciosamente `signIn()`, `signInSilently()` (en v6), `attemptLightweightAuthentication()` (en v7), `currentUser`, etc. La narrativa implícita es: **este plugin maneja la sesión**. Cuando v7 rompe ese contrato (por diseño, no por bug), el dev asume que tiene que arreglarlo manualmente. Y ahí empezás el desvío.

La doc de `firebase_auth`, del otro lado, no te grita "yo persisto sesiones OAuth". Asume que ya lo sabés. Y si no lo sabés, no lo descubrís leyendo cualquiera de las dos docs por separado — solo lo descubrís cuando alguien te dice **"estás manteniendo dos sesiones, solo necesitás una"**.

### 8.4 Por qué va contra la intuición

Si venís de v6 + Firebase Auth, tu mental model probablemente era:

```
google_sign_in   ──── mantiene sesión Google ────┐
                                                  ├── ambos juntos = "logueado"
firebase_auth    ──── mantiene sesión Firebase ──┘
```

Al pasar a v7 ves que `_googleSignIn.currentUser` es `null` al cold start y asumís que tenés que **arreglarlo**. Por ahí es donde miles de devs caen.

El mental model correcto es:

```
google_sign_in:  HANDSHAKE one-shot → produce idToken válido.
                 Después del handshake, NO se usa más para esta sesión.

firebase_auth:   recibe idToken una vez, MANTIENE la sesión solo,
                 renueva tokens automáticamente, sobrevive cold start,
                 sobrevive matada del SO, sobrevive reboot del device.
```

### 8.5 El detour: lo que probamos antes de entender

Cronología real en repo1 (agosto 2025):

| Iteración | Commit | Qué probaron | Por qué falló |
|-----------|--------|--------------|----------------|
| 1 | `9407247 loguin EXITOSO` | Guardar `last_google_email` en SharedPreferences + `attemptLightweightAuthentication()` con ese email | Lightweight muestra UI — no es silent. Y la "persistencia" era falsa: Firebase ya tenía el user persistido en paralelo. |
| 2 | `7529f0e loguin EXITOSO con fix` | Mantener email guardado pero quitar lightweight | El email guardado no servía para nada — Firebase ya emitía el user al startup vía `authStateChanges`. |
| 3 | `386283f final auth` | Quitar TODO el código de SharedPreferences y el import | Comprobación final: con solo `authStateChanges`, la persistencia funcionaba perfecto sin escribir una línea extra. |

El "click" llegó cuando alguien probó **NO hacer absolutamente nada extra** y verificó que el user seguía logueado al cold start. **Toda la lógica que habían escrito era ruido.**

### 8.6 Cómo se ve el flujo completo en código

```dart
// 1. main.dart — solo init Firebase, nada de google_sign_in acá
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

// 2. AuthProvider — el listener arranca en el constructor
class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    // Este listener emite el user persistido por Firebase al cold start,
    // ANTES de que la UI se construya. Es lo único que necesitás.
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }
}

// 3. signInWithGoogle se llama UNA SOLA VEZ — solo cuando el user toca
//    "Continuar con Google" en el modal. Después no se llama más.
//    El cold start del día siguiente NO necesita pasar por acá.
```

**Timing real**: 50–200ms entre cold start y avatar visible con datos del user. Sin dialog. Sin loading screen. Sin red. Firebase lee Keychain/EncryptedSharedPreferences localmente.

### 8.7 NO uses Firestore para persistir el user

A veces ves apps que sincronizan el `User` en Firestore (`/users/{uid}`) supuestamente "para persistir la sesión". Es trabajo perdido:
- Firebase Auth ya tiene `uid`, `email`, `displayName`, `photoURL` accesibles offline.
- El refresh automático de tokens lo hace solo Firebase Auth.

Firestore tiene sentido **solo** si guardás datos asociados al user (preferencias cross-device, suscripciones, historial) — no para auth en sí.

### 8.8 Caso edge: token expirado

Tokens OAuth de Google y Apple duran ~1 hora. Cuando expiran, Firebase Auth los **renueva automáticamente** con el refresh token. El stream `authStateChanges` puede emitir un nuevo `User` con el token renovado. Tu UI no necesita saber que pasó.

Si el refresh token mismo se invalida (user cambió contraseña en Google, revocó acceso desde Google Account, eliminó la app de "Apps with access", etc.), `currentUser` queda `null` y el listener emite `null`. Tu lógica `initializeAuth()` debería caer en `signInAnonymously()` para mantener la invariante "siempre hay user".

### 8.9 Resumen para el dev apurado

```
v7 = LLAVE (handshake una vez)
firebase_auth = CASA (vivís acá, persiste solo)
```

Si tu app no sigue esta separación de responsabilidades, vas a estar peleando contra v7 indefinidamente.

### 8.10 Estado del problema en mayo 2026 (verificación con fuentes)

> Verificación realizada en mayo 2026 contra el repositorio público `flutter/flutter`, la API pública de GitHub, el changelog oficial de `google_sign_in` en pub.dev y la documentación oficial de FlutterFire. Todas las citas son textuales con fecha, autor verificado y URL. La regla de "cita verificable" del manual aplica acá también: lo que no se pudo confirmar en fuente primaria no entró.

#### Tres issues abiertos por usuarios independientes — todos cerrados sin fix

| Issue | Título | Fecha | Status |
|-------|--------|-------|--------|
| [#171745](https://github.com/flutter/flutter/issues/171745) | "[google_sign_in] how to save login google" | 8 jul 2025 | Closed — duplicate of #172066 |
| [#172066](https://github.com/flutter/flutter/issues/172066) | "attemptLightweightAuthentication() always shows account selection" | 12 jul 2025 | **Closed as NOT PLANNED** |
| [#174736](https://github.com/flutter/flutter/issues/174736) | "google_sign_in does not silently re-auth after app restart" | 29 ago 2025 | Closed — duplicate of #172066 |

Tres developers diferentes, en tres meses distintos, reportando exactamente el mismo síntoma. Todos cerrados sin solución, dos como duplicados del tercero, el tercero como "not planned".

#### Posición oficial del maintainer del plugin — por qué Google no lo va a arreglar

**Stuart Morgan** ([@stuartmorgan-g](https://github.com/stuartmorgan-g)), maintainer oficial de `google_sign_in` (Flutter team), comentario en [#172066](https://github.com/flutter/flutter/issues/172066) del **12 julio 2025**:

> *"`google_sign_in` 7.x does not have a silent login option, specifically because some platforms—including Android—do not provide an option in the currently supported authentication SDKs that will guarantee silent sign in. Closing as out of scope since we can't control this behavior at the plugin level."*

Mismo maintainer en [#174736](https://github.com/flutter/flutter/issues/174736) del **30 agosto 2025**, respondiendo a un dev que llamó al cambio "regression":

> *"Not from the perspective of the plugin. The goal of the plugin is to wrap the recommended Google Sign In SDK; `google_sign_in` 7.x switched from a deprecated, no-longer-supported SDK to the only SDK that is currently supported. **That was, and still is, the intended behavior of the update.**"*

Y aclarando que tampoco es responsabilidad del Flutter team:

> *"The fact that you happen to be calling that SDK via a Dart wrapper in the context of a Flutter application is irrelevant to the request; a non-Flutter app would have exactly the same behavior. [...] The Flutter team has no opinion about what Google Sign In experience on Android should be, as that is not our role."*

**Lo que esto significa**, traducido:

1. v6 usaba un SDK que Google dejó de soportar (la legacy `play-services-auth`).
2. v7 usa el único SDK actualmente soportado por Google (Credential Manager en Android).
3. Credential Manager **no garantiza silent sign-in por diseño** — Google quiere que el usuario vea la pantalla de selección por seguridad/UX.
4. **No hay fix planeado.** No es bug, es comportamiento intencional.
5. Cualquier app nativa Android que use el SDK oficial de Google Sign-In tiene el mismo comportamiento. El plugin Flutter no agrega ni quita problema.

#### Confirmación verbatim de Firebase Auth como solución (FlutterFire docs)

Documentación oficial de FlutterFire ([firebase.flutter.dev/docs/auth/usage](https://firebase.flutter.dev/docs/auth/usage/)):

> *"On native platforms such as Android & iOS, this behavior is not configurable and the user's authentication state will be persisted on-device between app restarts."*

Y un dato bonus muy relevante para iOS que la primera versión del manual no tenía:

> *"Note: uninstalling your application on iOS or macOS can still preserve your users authentication state between app re-installs as the underlying Firebase iOS SDK persists authentication state to keychain."*

Es decir: en iOS, la sesión sobrevive incluso a la **desinstalación + reinstalación** de la app, gracias a la integración con Keychain. Si un user borra QueHacemos del iPhone y la vuelve a instalar la semana siguiente, abre la app y ya está logueado.

#### Changelog oficial de `google_sign_in` v7.0.0 (pub.dev)

[pub.dev/packages/google_sign_in/changelog](https://pub.dev/packages/google_sign_in/changelog), notas de v7.0.0 verbatim:

> *"BREAKING CHANGE: Many APIs have changed or been replaced to reflect the current APIs and best practices of the underlying platform SDKs. The GoogleSignIn instance is now a singleton. Clients must call and await the new initialize method before calling any other methods. Authentication and authorization are now separate steps."*

El changelog oficial **no menciona** la pérdida de la persistencia silenciosa como cambio destacado. Las víctimas aprenden recién al ejecutar la migración y ver al user "deslogueado" en cada cold start.

#### Búsqueda exhaustiva — ningún tutorial documenta la solución arquitectural

Búsqueda en mayo 2026 en Medium, dev.to, GeeksforGeeks, dbestech.com, blog de Codemagic y documentación oficial de Firebase + FlutterFire, con keywords *"google_sign_in 7", "Firebase Auth persistence", "authStateChanges", "single source of truth", "handshake"*:

- Todos los tutoriales 2025–2026 muestran **setup básico** (`initialize`, `authenticate`, `signInWithCredential`).
- **Ninguno** documenta el patrón arquitectural "v7 = handshake one-shot, Firebase Auth = source of truth de persistencia".
- **Ninguno** menciona los issues #171745, #172066, #174736 ni la posición de Stuart Morgan.
- La solución sigue siendo **única en este manual** dentro del corpus público auditable.

#### Conclusión: no es workaround, es arquitectura correcta

El insight de §8.2 ("v7 = llave, Firebase = casa") **no es un workaround del bug** — es la **arquitectura correcta** dado que Google cambió el paradigma deliberadamente entre v6 y v7. La doc oficial de Google nunca dijo "use Firebase Auth para persistir la sesión" — pero es lo que toca, porque:

- El SDK oficial de Google Sign-In **no provee** silent re-auth en Android (by design — confirmado por el maintainer).
- Firebase Auth **sí persiste** la sesión nativamente (confirmado por la doc).
- Por lo tanto: el SDK de Google es el handshake, Firebase Auth es la casa.

**Quien siga peleando con `google_sign_in` para mantener la sesión está peleando contra el SDK oficial de Google, no contra el plugin.** Como dijo Stuart Morgan: *"a non-Flutter app would have exactly the same behavior"*.

---

## 9. UI — LoginModal y triggers

### LoginModal (StatelessWidget)

```dart
class LoginModal extends StatelessWidget {
  final AuthProvider authProvider;
  const LoginModal({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Creá tu cuenta 🎭',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text('Registrate gratis y accedé a funciones exclusivas...',
            textAlign: TextAlign.center),
          const SizedBox(height: 32),

          // Botón Google
          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: authProvider.isLoading ? null : () async {
                final ok = await authProvider.signInWithGoogle();
                if (ok && context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.login, size: 20),
              label: Text(authProvider.isLoading
                  ? 'Conectando...' : 'Continuar con Google'),
            ),
          ),

          const SizedBox(height: 16),

          // Botón Apple — SOLO iOS
          if (Theme.of(context).platform == TargetPlatform.iOS) ...[
            SizedBox(width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: authProvider.isLoading ? null : () async {
                  final ok = await authProvider.signInWithApple();
                  if (ok && context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.apple, size: 20),
                label: Text(authProvider.isLoading
                    ? 'Conectando...' : 'Continuar con Apple'),
              ),
            ),
            const SizedBox(height: 16),
          ],

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Quizás más tarde'),
          ),
        ],
      ),
    );
  }
}
```

### Triggers

El modal se abre como `BottomSheet` desde dos lugares:

1. **Tap en avatar del AppBar** (acción manual del user):
```dart
void _handleAvatarTap(BuildContext ctx, AuthProvider ap) {
  if (ap.isLoggedIn) _showLogoutModal(ctx, ap);
  else                _showLoginModal(ctx, ap);
}

void _showLoginModal(BuildContext ctx, AuthProvider ap) {
  showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => LoginModal(authProvider: ap),
  );
}
```

2. **OnboardingCoordinator** (automático, según política — ver §11).

### Atención: `Theme.of(context).platform` vs `Platform.isIOS`

El check de plataforma del LoginModal usa `Theme.of(context).platform == TargetPlatform.iOS`. **`AuthService.signInWithApple()` usa `Platform.isIOS`**. Son distintos:
- `Platform.isIOS` (`dart:io`) — siempre cierto en iOS real, false en Android real.
- `Theme.of(context).platform` — overrideable. En desarrollo podés simular iOS desde Android Studio para ver el theme Cupertino. Si el theme dice iOS pero `dart:io` dice Android, vas a mostrar el botón Apple y al tocarlo `signInWithApple()` retorna `null` sin feedback.

> **Recomendación**: usar `Platform.isIOS` en ambos lados, o castear el override a `Theme.of(context).platform` también dentro de `AuthService` (no recomendado — el service no debería depender de `BuildContext`). En **producción de QueHacemos** este bug existe pero no se manifiesta porque nadie hace override del theme en builds release. Documentado como caso vivo en §14.

### Loading state compartido

`authProvider.isLoading` se setea en `signInWithGoogle()` / `signInWithApple()` / `deleteAccount()` y todos los botones lo leen. **No** uses un `_isLoading` local con `setState` en el modal — vas a tener dos sources of truth y el modal va a quedar "deshabilitado para siempre" si la navegación se cierra antes de que termine la llamada async.

---

## 10. Delete account — el requisito Apple Store

### Por qué Apple lo exige

Desde junio 2022, **App Store Review Guidelines § 5.1.1(v)** exige que toda app que permita crear una cuenta también permita borrarla **desde dentro de la app**. No alcanza con "mandanos un mail a soporte". El botón debe estar visible y el flujo debe ser **completable sin asistencia humana**.

QueHacemos fue rechazada en su primer review por App Store por exactamente esto: tenía Google + Apple Sign-In pero no había botón de eliminar cuenta. El delete account se agregó **después** del rechazo (commits posteriores al fork de repo3, archivos `auth_service.dart:138-217` + `settings_page.dart:437-477`).

### Flujo en UI

```
[Settings] → Card "🔐 Cuenta" (visible solo si !isAnonymous)
                │
                ▼
[Botón "Eliminar cuenta"] (rojo, OutlinedButton.icon delete_forever)
                │
                ▼
[AlertDialog confirmación]
  "⚠️ Eliminar cuenta. Esta acción no se puede deshacer..."
  [Cancelar] [Eliminar permanentemente]
                │
                ▼
[authProvider.deleteAccount()] (loading state shared)
                │
                ▼
        ┌───── Re-auth obligatoria ────┐
        │  Provider Google → dialog    │
        │  Provider Apple  → Face ID   │
        └──────┬───────────────────────┘
                │ ok
                ▼
[user.delete()] → Firebase elimina
                │
                ▼
[signInAnonymously()] (mantiene invariante "siempre hay user")
                │
                ▼
[UI rebuilds → Card de Cuenta desaparece]
```

### Por qué la re-autenticación es obligatoria

Firebase Auth requiere "credenciales recientes" (≤5 min) para `user.delete()`. Si el user lleva una hora con la app abierta, su token está fresco para queries pero stale para borrado. Sin re-auth, `delete()` lanza `requires-recent-login`.

El `_reauthenticateUser()` detecta el provider con `user.providerData.first.providerId`:
- `'google.com'` → nuevo dialog de Google.
- `'apple.com'` → nuevo Face ID/Touch ID.

Después llama `user.reauthenticateWithCredential(credential)` con la credencial fresca.

### Cuidado especial con Apple — el revoke real

Apple, además de borrar la cuenta de Firebase, **exige** que revocás el refresh token de Apple ID. Esto requiere un POST server-side a `https://appleid.apple.com/auth/revoke` con un **client_secret JWT firmado con tu private key (.p8)**. **No se puede hacer client-side** porque expone tu private key.

En QueHacemos producción **no hay backend**, entonces el revoke real no ocurre. El código actual (`_revokeAppleToken` en `auth_service.dart:220-229`) tiene un comentario "best effort" pero **el cuerpo del método llama `await user.delete()` por error, NO al endpoint de revoke**. Esto es un bug vivo (ver §14, caso 1).

Apple **acepta** la app igual mientras el botón de delete account funcione client-side y borre la cuenta de Firebase. La mejor práctica si no tenés backend es:

1. Borrar la cuenta de Firebase Auth ya hace que la app deje de reconocer al user.
2. Documentar en tu privacy policy que para revocación full del Apple ID, el user puede ir a Settings → Apple ID → Sign-In with Apple → revocar manualmente.
3. Si tu app hace cosas server-side con el ID de Apple del user, sí necesitás el revoke real — montá una Cloud Function.

### Botón "Eliminar cuenta" — patrón en Settings

```dart
Consumer<AuthProvider>(
  builder: (context, authProvider, _) {
    if (!authProvider.isLoggedIn) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🔐 Cuenta', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Gestiona tu cuenta y datos personales'),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: authProvider.isLoading ? null
                    : () => _showDeleteAccountDialog(context, authProvider),
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: Text(authProvider.isLoading ? 'Procesando...' : 'Eliminar cuenta',
                    style: const TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  },
)
```

> **Visibilidad**: el card solo se muestra si `isLoggedIn` (i.e. user real, no anónimo). Si el user no se logueó nunca, no tiene "cuenta" para borrar — esconder el botón evita confusión.

---

## 11. Onboarding y prompts — WeeklyPromptService

Si el login es opcional en tu app (anónimo de fallback), querés invitar al user a loguearse sin ser molesto. QueHacemos usa una progresión exponencial: **0, 3, 7, 20, 30, 60, 90 días** entre prompts. Después del 7º rechazo, no se vuelve a preguntar más.

### Storage

SharedPreferences string clave `'login_prompt_data'` con formato `"timestampMillis_declineCount"`:
```
1726512000000_3   ← último prompt el 16/9/2024, declinado 3 veces
```

Verificado en `lib/src/models/user_preferences.dart:63-71`.

### Servicio

```dart
class WeeklyPromptService {
  static Future<bool> shouldShowLoginPrompt(AuthProvider auth) async {
    if (auth.isLoggedIn) return false;
    final data = await UserPreferences.getLoginPromptData();
    final parts = data.split('_');
    if (parts.length != 2) return false;

    final lastPrompt = int.parse(parts[0]);
    final declineCount = int.parse(parts[1]);
    final now = DateTime.now().millisecondsSinceEpoch;
    final daysPassed = ((now - lastPrompt) / (1000 * 60 * 60 * 24)).floor();

    return daysPassed >= _getRequiredDays(declineCount);
  }

  static Future<void> recordLoginDecline() async {
    final data = await UserPreferences.getLoginPromptData();
    final parts = data.split('_');
    final declineCount = (parts.length == 2 ? int.parse(parts[1]) : 0) + 1;
    final now = DateTime.now().millisecondsSinceEpoch;
    await UserPreferences.setLoginPromptData('${now}_$declineCount');
  }

  // Progresión: 0/3/7/20/30/60/90 → después del 7º decline, NUNCA más
  static int _getRequiredDays(int declineCount) {
    switch (declineCount) {
      case 0: return 0;     case 1: return 3;
      case 2: return 7;     case 3: return 20;
      case 4: return 30;    case 5: return 60;
      case 6: return 90;
      default: return 999999;
    }
  }
}
```

Verificado en `lib/src/services/weekly_prompt_service.dart:1-105`.

### Coordinación: OnboardingCoordinator

Singleton que llama a `shouldShowLoginPrompt` + `shouldShowNotificationPrompt` **una sola vez al día** (flag `last_prompt_check_date` en SharedPreferences). En primera instalación dispara una secuencia: snackbar de "eventos descargados" 7s → modal login → modal notificaciones → marca onboarding completado.

Verificado en `lib/src/services/onboarding_coordinator.dart:1-280`.

```dart
Future<void> _showLoginModal(BuildContext ctx, AuthProvider ap) async {
  await showModalBottomSheet(
    context: ctx,
    builder: (_) => LoginModal(authProvider: ap),
  );
  // Si cerró sin loguear, contar como decline
  if (!ap.isLoggedIn) {
    await WeeklyPromptService.recordLoginDecline();
  }
}
```

### Por qué este patrón es bueno

- **No molesta** — después del 3º "no", esperás 20 días.
- **Respeta la decisión** — si el user dijo "no" 7 veces, no preguntás más en su vida útil de la app.
- **No depende del usuario explorar Settings** — el prompt aparece solo cuando corresponde.
- **Fail-safe**: cualquier error de parsing de la string `"timestamp_count"` retorna `false` (no preguntás).

---

## 12. Lecciones de iteración (commits reales)

Toda la historia del login en QueHacemos vive en `repo1_QueHacemos`. El repo de producción `repo3_quehacemos_desarr` (Play Store + App Store) heredó el código de auth con un commit `8633392` y luego le agregó delete account. Cronología:

| Commit | Fecha | Mensaje | Qué pasó realmente |
|--------|-------|---------|---------------------|
| `f35e60c` | 5/8/25 23:54 | loguin 1º etapa | Crea `auth_service.dart` (179 líneas) y `auth_provider.dart` (180 líneas). Primer intento, sin delete account, con `print` debug. |
| `492ffcd` | 6/8/25 00:56 | loguin 2º etapa | Refactor del avatar en `main_app_bar.dart` (291 líneas). |
| `9407247` | 6/8/25 14:15 | loguin EXITOSO | **La "técnica inventada"**: agrega `attemptLightweightAuthentication()` + `last_google_email` en SharedPreferences. Idea: login silencioso si ya hay último email guardado. Funcionó pero se descartó al día siguiente. |
| `7529f0e` | 6/8/25 23:46 | loguin EXITOSO con fix | **Reversa parcial**: quita `attemptLightweightAuthentication`. Mantiene SharedPreferences inútil. Bug colado: `return result; return result;` duplicado. Agrega notificaciones in-app de bienvenida. |
| `386283f` | 7/8/25 00:07 | final auth | Limpia el `return result;` duplicado y el import sobrante de `shared_preferences`. Código quedó 5 líneas más corto. |
| `c80d586` | 16/8/25 23:02 | fix loguin | **Mueve `Firebase.initializeApp()` desde `main()` hacia `_AppContentState._initializeApp()`** (lazy init). Cambia `Future<void> initializeAuth()` → `void initializeAuth()` (sync). Bumpea version `+2` → `+3`. |
| `fc34c01` | 16/8/25 23:32 | rollbac loguin | **Reverte `c80d586` 30 minutos después.** Vuelve `Firebase.initializeApp()` a `main()`. Restaura `Future<void> initializeAuth() async`. Bumpea `+3` → `+4`. El motivo del rollback: con el init lazy, el `authStateChanges` nunca emitía el user persistido al cold start. |
| `bb71d45` | 25/8/25 | fix varius | Cambio cosmético de emoji 🎈 → 🤗. Logs de debug en settings. |

### Lección 1 — Firebase.initializeApp en main(), siempre

El rollback de 30 minutos (`c80d586` ↔ `fc34c01`) es la prueba escrita. Si movés Firebase init a un widget lazy, el árbol de Providers se construye sin Firebase listo, los listeners de `authStateChanges` quedan colgando, y al cold start el user persistido **nunca aparece** aunque esté guardado.

### Lección 2 — `google_sign_in v7` es una llave, no una casa

El experimento de `attemptLightweightAuthentication()` + SharedPreferences (commits `9407247` → `7529f0e` → `386283f`) duró tres días. Lo que parecía "google_sign_in dejó de persistir la sesión y hay que arreglarlo manualmente" en realidad era "v7 nunca persistió la sesión por diseño — Firebase Auth lo hacía silenciosamente del otro lado todo el tiempo". Ver §8 para el insight completo. Esta lección la publicó QueHacemos en r/FlutterDev y se la rechazaron por "parecer respuesta de IA" — porque la solución correcta invierte el mental model que casi todo el mundo trae cuando migra de v6.

### Lección 3 — Apple Sign-In necesita `accessToken: authorizationCode`

repo1 nunca lo tuvo. repo3 lo agregó (`auth_service.dart:97`) silenciosamente. Si tu Apple Sign-In "a veces no funciona en Firebase" en producción, falta este parámetro.

### Lección 4 — el bug `return result; return result;`

En `7529f0e` quedaron dos `return result;` consecutivos en `signInWithGoogle`. Compila. El compilador no avisa porque el segundo es inalcanzable. El IDE marca el segundo como "dead code" pero solo si lo abrís. Lección: **lecturá el diff completo del commit antes de pushear**, especialmente cuando hacés merge de cambios mecánicos. Se limpió en `386283f`.

### Lección 5 — `_initializeAnonymousAuth` placeholder vacío

Tras el rollback `fc34c01`, el método `_initializeAnonymousAuth()` quedó en `main.dart` como cuerpo vacío (`// Auth initialization placeholder`). Sigue invocado en `main()` línea 43. **No rompe nada**, pero es código muerto que se shippeó a Play Store. Verificable en `repo3/lib/main.dart:49-51`. Si limpiás post-rollbacks, mirá si quedaron stubs huérfanos.

---

## 13. Bugs silenciosos conocidos

Estos errores **no lanzan excepciones visibles**: el sign-in falla sin feedback, o el delete account "anda" pero no completa la revocación, o el botón de Apple aparece y al tocarlo no hace nada.

| # | Síntoma | Causa | Fix |
|---|---------|-------|-----|
| 1 | "Sign in cancelled" cada vez que el user toca afuera del dialog | Plugin lanza excepción con mensaje "cancel" — no es error real | `if (!e.toString().contains('cancel'))` antes de mostrar notificación de error |
| 2 | Google Sign-In Android: error genérico `ApiException 10` | SHA-1/SHA-256 no registrados en Firebase Console O `google-services.json` viejo | Registrar fingerprints de debug Y release; bajar el JSON nuevo después |
| 3 | Google Sign-In iOS: `INVALID_IDP_RESPONSE` de Firebase | `GIDServerClientID` en Info.plist es el iOS Client ID en vez del Web Client ID | Usar siempre el Web Client ID en `GIDServerClientID` y en `serverClientId` de Dart |
| 4 | Apple Sign-In: `AuthorizationErrorCode.unknown` en runtime | `Runner.entitlements` falta el key `com.apple.developer.applesignin` | Crear/inyectar el entitlement (a mano o vía Codemagic — §4.5) |
| 5 | Apple Sign-In funciona "a veces" en Firebase | Falta `accessToken: appleCredential.authorizationCode` en `OAuthProvider("apple.com").credential(...)` | Pasar siempre los 3 campos: `idToken`, `rawNonce`, `accessToken` |
| 6 | iOS: el dialog OAuth de Google se abre pero "no vuelve" | Falta `application(_:open:options:)` en `AppDelegate.swift` con `GIDSignIn.sharedInstance.handle(url)` | Override igual al del §4.4 |
| 7 | `authStateChanges` nunca emite el user persistido al cold start | `Firebase.initializeApp()` se llama después de `runApp()` | Mover a `main()` ANTES de `runApp()` (verificado por rollback `fc34c01`) |
| 8 | Apple no manda displayName al user después de la primera vez | Apple solo emite `givenName`/`familyName` en el primer login. Reinstall = se pierde. | Llamar `result.user?.updateDisplayName(...)` con `appleCredential.givenName` cuando esté presente |
| 9 | `user.delete()` lanza `requires-recent-login` | Firebase exige token "fresh" (≤5min) para delete. | Llamar `user.reauthenticateWithCredential(credential)` justo antes con credencial nueva |
| 10 | Botón de Apple aparece en Android (override de Theme) | UI checkea `Theme.of(context).platform == TargetPlatform.iOS` pero `signInWithApple` checkea `Platform.isIOS` | Usar `Platform.isIOS` en ambos lados (consistente con `dart:io`) |
| 11 | Avatar muestra color distinto cada cold start | Usar `Random` o `DateTime.now()` para color del avatar | Hash determinista del email: `colors[email.hashCode.abs() % colors.length]` |
| 12 | LoginModal queda "Conectando..." para siempre | `_isLoading` local con `setState` pero la navegación se cerró antes | Usar `authProvider.isLoading` del Provider, NO state local en el modal |
| 13 | Token expirado durante uso de la app | Tokens OAuth duran ~1h. Sin renovación automática, el user "se desloguea" solo. | Firebase Auth renueva con refresh token automáticamente — confiar en el stream |
| 14 | App rechazada por Apple Store | Falta botón visible de eliminar cuenta dentro de la app | Implementar `deleteAccount()` (§10) y exponerlo en Settings cuando `isLoggedIn` |
| 15 | Delete account de Apple no revoca el token Apple ID | El revoke real requiere POST server-side a appleid.apple.com con JWT firmado | Documentar la limitación en privacy policy si no tenés backend; opcional: Cloud Function |
| 16 | `ClassNotFoundException: Didn't find class "com.tupackage.MainActivity"` al cambiar el package name | Cambiar `namespace`/`applicationId` en `build.gradle.kts` no actualiza el `package` declaration en `MainActivity.kt` — son independientes | Editar `MainActivity.kt` y cambiar la primera línea: `package com.tupackage.nuevo`. El path físico del archivo no importa, solo la declaración. |

---

## 14. Lecciones de producción real

> Bugs vivos hoy en QueHacemos Córdoba (Play Store + App Store, mayo 2026). Cada uno se confirmó leyendo el código publicado en `repo3_quehacemos_desarr/`. Los fixes están en este manual. El propósito de esta sección es que veas la diferencia entre "lo que se shippeó" y "lo que conviene shippear".

### Caso 1 — `_revokeAppleToken` borra dos veces, no revoca nada

**En el código publicado** (`lib/src/services/auth_service.dart:220-229`):

```dart
Future<void> _revokeAppleToken(User user) async {
  try {
    // Apple requiere revocación server-side
    // Como no tenés backend, esto queda como "best effort"
    // Firebase eliminará la cuenta igual
    await user.delete();    // ← ESTO NO ES UN REVOKE, ES UN DELETE
  } catch (e) {
    // Silencioso
  }
}
```

Y arriba en `deleteAccount` (línea 157-162):

```dart
if (user.providerData.any((info) => info.providerId == 'apple.com')) {
  await _revokeAppleToken(user);   // ← llama user.delete() la 1ª vez
}
await user.delete();               // ← llama user.delete() otra vez
```

**Consecuencia:** para usuarios que se loguearon con Apple, `user.delete()` se invoca **dos veces**. La segunda lanza `no-current-user` (capturada en silencio por el try/catch del método). El "revoke real" del token Apple ID nunca ocurre — el endpoint `https://appleid.apple.com/auth/revoke` jamás se llama.

**Por qué nadie lo nota:** App Store no audita esto en review automático. La cuenta se borra de Firebase Auth, que es lo que el user ve. Apple ID queda con el "Sign In with Apple" activo en Settings de iOS pero ya no apunta a una cuenta válida.

**Fix:** o bien removés `_revokeAppleToken` del flujo (y documentás en privacy policy), o agregás una Cloud Function que firme el JWT con tu .p8 y haga el POST a appleid.apple.com.

---

### Caso 2 — `serverClientId` con defaultValue hardcodeado

**En el código publicado** (`auth_service.dart:22-25`):

```dart
await _googleSignIn.initialize(
  serverClientId: const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID',
      defaultValue: '998972257036-llbcet7uc4l7ilclp6uqp9r73o4eo1aa.apps.googleusercontent.com'),
);
```

**Consecuencia:** si `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` no se pasa al build (caso típico: build local, build de testing), se usa el ID real de producción. Aunque los Web Client IDs no son secretos (son públicos en el OAuth flow), tener uno hardcodeado en repo:
- Mezcla auth de dev y prod → si tenés un proyecto Firebase de dev, lo bypaseás.
- Hace difícil rotar el ID si Google lo bloquea por abuso.

**Fix:** usar dotenv (como `firebase_options.dart`) o `String.fromEnvironment` SIN `defaultValue`. Que el build falle a propósito si la env var falta.

---

### Caso 3 — `Theme.of(context).platform` vs `Platform.isIOS` divergen

**En el código publicado:**
- `LoginModal` (`login_modal.dart:57`): `if (Theme.of(context).platform == TargetPlatform.iOS) ...[ /* botón Apple */ ]`.
- `AuthService.signInWithApple()` (`auth_service.dart:75`): `if (!Platform.isIOS) return null;`.

**Consecuencia:** en builds release no se manifiesta porque nadie hace override del theme. Pero en desarrollo, si el user activa "Force iOS theme" en flutter inspector, ve el botón Apple en su Android — y al tocarlo, el AuthService retorna `null` sin feedback (sin notificación de error porque la excepción no se levanta).

**Fix:** usar `Platform.isIOS` en ambos lados.

---

### Caso 4 — `import 'debug_helper.dart'` shippeado a Play Store

**En el código publicado** (`settings_page.dart:12-13`):

```dart
// 🚧 COMENTAR ESTA LÍNEA EN PRODUCCIÓN:
import 'debug_helper.dart';
```

Y en línea 302:

```dart
// 🚧 COMENTAR ESTAS 2 LÍNEAS EN PRODUCCIÓN:
const SizedBox(height: AppDimens.paddingMedium),
DebugTestingHelper.buildDeveloperCard(context),
```

**Consecuencia:** la "Developer Card" sale en producción para todos los usuarios. Probable: botones de testing que activan flujos que un usuario normal no debería disparar (ej. force first install, reset onboarding).

**Por qué nadie lo nota:** los users mayoritarios no exploran Settings hasta el fondo, y los developers ya están acostumbrados a verlo. Hasta que alguien usa un botón de "reset" pensando que limpia caché y pierde sus favoritos.

**Fix:** o bien hacer el card invisible con un flag `kDebugMode`:

```dart
if (kDebugMode) DebugTestingHelper.buildDeveloperCard(context),
```

…o un flavor de build con `--dart-define=DEBUG_TOOLS=true`. El comentario `// 🚧 COMENTAR EN PRODUCCIÓN` es **garantía de que algún día se va a olvidar**.

---

### Caso 5 — el doc analítico viejo dice 10 colores, el código tiene 8

**En el código publicado** (`auth_provider.dart:162-171`):

```dart
final colors = [
  Colors.blue, Colors.green, Colors.orange, Colors.purple,
  Colors.red,  Colors.teal,  Colors.indigo, Colors.pink,
];
```

**El doc analítico** (`repo3/.context/login.md`) dice **10 colores** y enumera `Colors.amber[700]` y `Colors.cyan[700]` que ya no están. Esto no es un bug de código — es **un bug de documentación**. La importancia: si arrancás un proyecto leyendo el doc viejo y "completás" para tener 10, vas a tener inconsistencia visual con la app legacy.

**Fix:** validar siempre el doc contra el código del día. Y este manual: 8 colores, no 10.

---

### Lectura recomendada

Estos 5 bugs son de bajo perfil — no rompen el flujo, no aparecen en Crashlytics, no generan reseñas malas. Se descubren leyendo el código con calma, no en el QA. Si arrancás un proyecto nuevo, **bajá los 5 fixes desde el día 1**. Costo cero de código, eliminan toda esta clase de fallas silenciosas.

---

## 15. Checklist de QA antes de release

### Funcional — Google
- [ ] Tap "Continuar con Google" → dialog nativo aparece.
- [ ] Selección de cuenta → modal se cierra → avatar muestra iniciales/foto.
- [ ] `isLoggedIn = true`, `userName/userEmail` populados.
- [ ] Tap "Cancelar" en dialog → no hay notificación de error.
- [ ] Logout (si está expuesto) → vuelve a anónimo, avatar muestra "?".

### Funcional — Apple (iOS)
- [ ] Botón Apple visible en iOS, oculto en Android.
- [ ] Tap → Face ID / Touch ID aparece.
- [ ] Aprobación → modal se cierra → avatar populado.
- [ ] Si user dio nombre, `displayName` está seteado (no `null`).
- [ ] Apple "Hide my email" → `email` es relay `@privaterelay.appleid.com`, login funciona igual.

### Persistencia
- [ ] Login con Google → matar app (swipe up iOS / back Android) → reabrir → user sigue logueado, avatar correcto, **<200ms**.
- [ ] Login con Apple → matar app → reabrir → idem.
- [ ] Cambiar de red (wifi → 4g → wifi) → user sigue logueado.
- [ ] Cerrar dialog del SO de "permitir notificaciones" no afecta el state de auth.

### Delete account
- [ ] Card "Cuenta" visible solo si `isLoggedIn`.
- [ ] Tap "Eliminar cuenta" → AlertDialog de confirmación.
- [ ] "Cancelar" → cierra dialog, nada más.
- [ ] "Eliminar permanentemente" → re-auth dialog (Google/Apple según provider).
- [ ] Re-auth exitosa → user.delete() → vuelve a anónimo → Card desaparece.
- [ ] Re-auth cancelada → no se elimina, no hay efectos colaterales.

### Build
- [ ] `flutter build apk --release` y `flutter build ipa --release` ambos pasan.
- [ ] iOS: `Runner.entitlements` con `com.apple.developer.applesignin` en el IPA final (verificar con `unzip -l Runner.ipa | grep entitlements` y `codesign -d --entitlements - Runner.app`).
- [ ] iOS: `Info.plist` del IPA tiene `CFBundleURLTypes`, `GIDClientID`, `GIDServerClientID`.
- [ ] Android: SHA-256 fingerprint de release registrado en Firebase Console.
- [ ] `google-services.json` y `GoogleService-Info.plist` actuales (descargados después del último cambio de fingerprints).

### Edge cases
- [ ] Sin red al loguear → notificación de error, no crash.
- [ ] User cierra el modal mientras `isLoading=true` → no hay leak, próxima apertura el state es limpio.
- [ ] Token expirado durante uso → user no nota nada (Firebase renueva).
- [ ] User borra la app de "Apps with access" en Google Account → próximo cold start → vuelve a anónimo silenciosamente.
- [ ] Hot restart durante login en curso → no hay dialog huérfano.

### Apple Store review
- [ ] Botón "Eliminar cuenta" visible y funcional.
- [ ] Privacy policy menciona qué se elimina y qué no (Apple ID revoke si aplica).
- [ ] App ID en Apple Developer tiene capability "Sign In with Apple" Y certificado de Apple Push (para `aps-environment`).

---

## 16. Referencias de código

### QueHacemos producción (repo3_quehacemos_desarr) — estado final
- `lib/src/services/auth_service.dart` (252 líneas) — service core.
- `lib/src/providers/auth_provider.dart` (177 líneas) — ChangeNotifier.
- `lib/src/widgets/login_modal.dart` (90 líneas) — UI del modal.
- `lib/src/widgets/app_bars/main_app_bar.dart:234-303` — trigger del modal desde avatar.
- `lib/src/pages/settings_page.dart:221-276` — Card "Cuenta" + delete account button.
- `lib/src/pages/settings_page.dart:437-477` — `_showDeleteAccountDialog`.
- `lib/src/services/onboarding_coordinator.dart` (280 líneas) — coordinador de prompts.
- `lib/src/services/weekly_prompt_service.dart` (105 líneas) — progresión exponencial.
- `lib/main.dart:34-47` — init de Firebase + Auth.
- `lib/firebase_options.dart` — config Firebase desde dotenv.
- `ios/Runner/AppDelegate.swift:1-23` — Google Sign-In callback.
- `codemagic.yaml:91-209` — generación de `GoogleService-Info.plist`, Info.plist, `Runner.entitlements`.

### QueHacemos repo de iteración (repo1_QueHacemos) — historia
- Commits clave del login en orden: `f35e60c` → `492ffcd` → `9407247` → `7529f0e` → `386283f` → `c80d586` (rollback) → `fc34c01` (revert) → `bb71d45`.

### Repos descartados
- `repo2_keaCmos`: API legacy de google_sign_in (`final _googleSignIn = GoogleSignIn();` con `signIn()`). No comparable con v7.
- `repo4_QueHacemosClean`: snapshot idéntico a repo3 en `auth_service.dart` (`diff` vacío). No agrega información sobre el de producción.

---

## 17. TL;DR

1. **Stack**: `firebase_auth: ^6.1.0` + `google_sign_in: ^7.2.0` + `sign_in_with_apple: ^7.0.1` + `crypto: ^3.0.6`.
2. **Setup Android**: `google-services.json` + SHA-1/SHA-256 fingerprints en Firebase Console + permiso `INTERNET`. Sin manifest custom.
3. **Setup iOS**: 4 piezas — `Runner.entitlements` con `com.apple.developer.applesignin`, `Info.plist` con `CFBundleURLTypes` (REVERSED_CLIENT_ID) + `GIDClientID` + `GIDServerClientID` (web!), `GoogleService-Info.plist`, `AppDelegate.swift` con override `application(_:open:options:)`. Si usás Codemagic, todo se inyecta vía PlistBuddy desde env vars.
4. **Init en main.dart**: `Firebase.initializeApp()` SIEMPRE antes de `runApp()`. Verificado por rollback de 30 minutos en QueHacemos. `AuthProvider` se construye en `MultiProvider` y arranca el listener `authStateChanges`. `initializeAuth()` se llama en `addPostFrameCallback`.
5. **Persistencia v7 — el insight que NO está en docs oficiales**: en `google_sign_in v7` quitaron `signInSilently()` y `attemptLightweightAuthentication()` muestra UI (no es silent). **Tratá v7 como "la llave para abrir la puerta de entrada" — una vez adentro, Firebase Auth es tu residencia permanente.** El stream `authStateChanges` emite el user al cold start desde Keychain/EncryptedSharedPreferences. NO uses SharedPreferences para "guardar el último email" ni Firestore para "persistir el user". Descubrimiento publicado por QueHacemos en r/FlutterDev y rechazado por sospecha de IA (agosto 2025) — porque invierte el mental model que trae todo el mundo viniendo de v6. Ver §8 completa.
6. **Apple Sign-In**: nonce SHA-256, scopes `[email, fullName]`, `OAuthProvider("apple.com").credential` con los **3 campos** (`idToken`, `rawNonce`, `accessToken: appleCredential.authorizationCode`). Capturar `givenName/familyName` y setear `displayName` la primera vez (Apple no manda nombre después).
7. **Anonymous como fallback**: garantiza que SIEMPRE hay user. Permite usar la app sin login wall. Logout y delete account vuelven a anónimo.
8. **Delete account**: requisito Apple Store. Re-auth obligatoria (Firebase exige token <5min). Detectar provider con `user.providerData.first.providerId`. Apple revoke real requiere backend (JWT con .p8) — sin backend, documentar limitación.
9. **UI**: `LoginModal` como `BottomSheet`, botón Apple sólo si `Platform.isIOS` (no `Theme.of(context).platform`). Loading state compartido vía `AuthProvider.isLoading`, NUNCA con `setState` local.
10. **Onboarding prompts**: `WeeklyPromptService` con progresión 0/3/7/20/30/60/90 días. Storage SharedPreferences `"timestamp_declineCount"`. Después del 7º "no", nunca más.
11. **Avatar**: iniciales del `displayName` o primer letra del email, fallback "?". Color determinista con `email.hashCode.abs() % 8`. NO 10 colores como dicen docs viejos.
12. **`if (!e.toString().contains('cancel'))`** antes de mostrar errores: el plugin lanza con "cancel" cuando el user cancela voluntariamente — no es error.
13. **5 bugs vivos en QueHacemos producción** documentados en §14: `_revokeAppleToken` que llama `user.delete()` por error, `serverClientId` con defaultValue hardcodeado, `Theme.of` vs `Platform.isIOS` divergiendo, `debug_helper` shippeado, doc viejo desactualizado. Los fixes están en este manual — bajalos desde el día 1.
14. **Apple revoke real**: solo si tenés backend con la private key (.p8) que puede firmar el JWT y hacer POST a `appleid.apple.com/auth/revoke`. Sin backend, no es realista — documentá la limitación.
15. **Lección dorada**: Firebase Auth + el stream `authStateChanges` resuelven persistencia, refresh de token y revert post-delete sin que escribas una línea de soporte. No te dejes tentar por "ayudarlo".



