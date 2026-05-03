# Manual de Notificaciones FCM en Flutter

Manual reusable para implementar **Firebase Cloud Messaging (FCM)** en Flutter, basado en la experiencia real de QueHacemos: una app que pasó por **128 commits de iteración dolorosa** (WorkManager abandonado, HTTP push descartado, 4 fixes seguidos por minification en Android 9) antes de llegar al **estado limpio actual en producción** (30 commits, vivo en Play Store + App Store).

Este manual NO es un copy-paste de la documentación de Firebase. Es la **destilación de lo que SÍ funciona** después de tirar a la basura lo que no.

> Para notificaciones **locales** (programadas sin backend), ver `manual_notificaciones_locales.md`. Este manual asume que ya leíste o conocés ese setup, porque FCM y locales coexisten en la misma app.

---

## 1. Decisión previa: ¿necesitás FCM?

Antes de tocar Firebase, definí qué problema querés resolver. FCM tiene costo (backend, mantenimiento, complejidad). Decidir mal acá te lleva a 100 commits de pelea.

| Caso de uso | Solución |
|-------------|----------|
| Recordatorios programados desde la app (vencimientos, alarmas) | **Notif locales** (`flutter_local_notifications` solo) |
| Aviso 1x al día de eventos del día (calendario) | **Notif locales** programadas con `zonedSchedule` |
| Push genéricos a todos los usuarios | **FCM con topic** (un solo topic, tipo `'all_users'`) |
| Push segmentados por usuario | **FCM con tokens individuales** + backend |
| "Despertar" la app diariamente para tareas | **NO usar WorkManager** — usar FCM silent + recovery on-resume (ver §11) |

**Lección de QueHacemos:** intentaron WorkManager para tareas diarias en background. **Falló en producción durante semanas.** Lo reemplazaron por FCM silent + recovery on app open. Si tu caso es "ejecutar algo cada día", esa es la combinación.

---

## 2. Stack mínimo

```yaml
# pubspec.yaml — versiones probadas en producción (Mayo 2026)
dependencies:
  firebase_core: ^4.0.0
  firebase_messaging: ^16.0.1
  flutter_local_notifications: ^21.0.0   # FCM foreground re-show + scheduling
  timezone: ^0.11.0                       # ZonedSchedule
  flutter_timezone: ^4.1.0                # Zona real del device
  permission_handler: ^11.0.0             # Permisos avanzados
  shared_preferences: ^2.5.3              # Throttling + flags persistentes
```

> **Por qué `flutter_local_notifications` también en una app FCM:** en Android **e iOS en foreground**, FCM **NO muestra la notificación automáticamente**. Hay que re-mostrarla con notif local. Es invisible al usuario pero crítico en código.

---

## 3. Setup Firebase (proyecto)

### 3.1 Pasos one-time (consola de Firebase)

1. Crear proyecto en https://console.firebase.google.com
2. Agregar app Android (package name: `com.tuempresa.tuapp`).
3. Agregar app iOS (bundle ID matcheando Xcode).
4. Descargar `google-services.json` (Android) y `GoogleService-Info.plist` (iOS).
5. **iOS adicional**: subir certificado APNs (Apple Push Notification) o key `.p8` desde Apple Developer en Firebase → Project Settings → Cloud Messaging.

### 3.2 Archivos de configuración — NO commitearlos

```
# .gitignore
google-services.json
GoogleService-Info.plist
.env
```

> En producción usar `flutter_dotenv` o variables de entorno de CI (Codemagic env vars), generar `firebase_options.dart` con `flutterfire configure`. NUNCA commitear keys reales.

### 3.3 Ubicación de los archivos

| Archivo | Path |
|---------|------|
| `google-services.json` | `android/app/google-services.json` |
| `GoogleService-Info.plist` | `ios/Runner/GoogleService-Info.plist` (agregar al target en Xcode) |
| `firebase_options.dart` | `lib/firebase_options.dart` (generado por `flutterfire`) |

---

## 4. Setup Android

### 4.1 `android/build.gradle.kts` (proyecto)

Agregar el classpath de Google Services:

```kotlin
buildscript {
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}
```

### 4.2 `android/app/build.gradle.kts`

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")   // ← FCM plugin
}

android {
    defaultConfig {
        minSdk = 23   // Android 6.0+ (Firebase requiere mínimo)
        // ...
    }
}
```

### 4.3 `AndroidManifest.xml`

Antes de `<application>`:

```xml
<!-- Internet (FCM) -->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

<!-- Notif (Android 13+) -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<!-- Si además usás scheduling local (recomendado) -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE"/>
```

Dentro de `<application>`, los receivers de `flutter_local_notifications` (necesarios para el re-show de FCM foreground):

```xml
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
    </intent-filter>
</receiver>
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsReceiver"/>
```

**Ícono de FCM por default** (opcional pero recomendado, evita el cuadrado gris):

```xml
<meta-data
    android:name="com.google.firebase.messaging.default_notification_icon"
    android:resource="@drawable/ic_notification" />
<meta-data
    android:name="com.google.firebase.messaging.default_notification_color"
    android:resource="@color/notification_color" />
```

### 4.4 ProGuard / R8 — la gran lección de Android 9

> **🔥 Lección histórica de QueHacemos**: 4 commits seguidos llamados `"api 28 fix"` (Android 9 = API 28). El bug: con `isMinifyEnabled = true`, R8 ofuscaba clases internas de `firebase_messaging` y FCM **fallaba en silencio en release** sobre Android 9. En debug funcionaba perfecto.

**Fix obligatorio en `android/app/proguard-rules.pro`:**

```proguard
# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Para flutter_local_notifications (FCM foreground re-show)
-keep class com.dexterous.** { *; }
-keepclassmembers class com.dexterous.** { *; }

# Atributos requeridos por la deserialización Gson interna
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Si usás Firestore/Auth además de Messaging:
-keep class com.google.firestore.** { *; }
-keep class com.google.android.gms.** { *; }
```

**Ícono de notificación — `android/app/src/main/res/raw/keep.xml`** (mismo fix que en notif locales):

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@drawable/ic_notification" />
```

> Sin estas reglas, **release en Android 9 (API 28) falla silenciosamente** y nunca te enterás hasta que un usuario reporta que no le llegan los avisos.

---

## 5. Setup iOS

### 5.1 Capabilities en Xcode

Abrir `ios/Runner.xcworkspace` y en el target Runner → Signing & Capabilities, agregar:

- **Push Notifications**
- **Background Modes** → marcar:
  - `Remote notifications`
  - `Background fetch`
  - `Background processing` (si vas a usar `BGTaskScheduler`)

### 5.2 `ios/Runner/Info.plist`

```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>processing</string>
    <string>remote-notification</string>   <!-- ← FCM background -->
</array>

<!-- Solo si usás BGTaskScheduler para tareas diarias -->
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>daily-sync</string>
    <string>daily-notifications</string>
</array>

<key>MinimumOSVersion</key>
<string>15.0</string>
```

### 5.3 `ios/Runner/AppDelegate.swift`

Mantenerlo **mínimo**. Flutter + `firebase_messaging` se encargan del resto:

```swift
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### 5.4 APNs — el detalle que se olvida

- En Apple Developer → Certificates → crear key `.p8` con APNs habilitado.
- Subirlo a Firebase Console → Project Settings → Cloud Messaging → Apple app configuration.
- Sin esto, los push **se envían en Firebase pero nunca llegan al device**.

> En iOS, después de obtener el FCM token puede ser necesario esperar ~2 segundos a que APNs esté listo. Si `getAPNSToken()` retorna `null`, hacé `await Future.delayed(Duration(seconds: 2))` y reintentá.

---

## 6. Inicialización en main.dart (orden CRÍTICO)

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'firebase_options.dart';

/// Background message handler — DEBE ser top-level (no método de clase)
/// y tener @pragma('vm:entry-point') para que el AOT compiler no lo elimine
/// y para que Dart pueda registrarlo desde un isolate background.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Acá NO podés acceder al estado de Provider/Riverpod ni a la UI.
  // Si necesitás SharedPreferences o SQLite, importarlos directamente.
  // Mantener el handler corto: <30 segundos en Android o el SO lo mata.
  debugPrint('[FCM-bg] ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase ANTES que todo lo que dependa de él.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Registrar el background handler INMEDIATAMENTE después de initializeApp.
  //    Esto debe ejecutarse en cada cold start, no solo la primera vez.
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  // 3. Timezone (si vas a programar notif locales además de FCM)
  tz_data.initializeTimeZones();
  final tzName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(tzName));

  // 4. NO inicialices NotificationManager / NotificationService acá.
  //    Eso va en addPostFrameCallback dentro del primer widget — necesita Activity.

  runApp(const MyApp());
}
```

> **Errores típicos en main.dart:**
> - **Olvidar `@pragma('vm:entry-point')`**: el handler es eliminado por el tree-shaker en release y nunca se ejecuta.
> - **Registrar el handler dentro de un `if (!_initialized)`**: en cold start de background, el handler debe registrarse SIEMPRE.
> - **Inicializar `firebase_messaging` antes de `Firebase.initializeApp()`**: crash silencioso.

---

## 7. NotificationManager — servicio FCM de referencia

Patrón en producción (basado en `notification_manager.dart` de QueHacemos):

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationManager {
  static final NotificationManager _instance = NotificationManager._();
  factory NotificationManager() => _instance;
  NotificationManager._();

  bool _initialized = false;
  static const _topic = 'all_users';   // o segmentado: 'es_users', 'premium', etc.

  /// Llamar UNA vez después del primer frame. NO en main().
  Future<void> initialize({bool bypassCheck = false}) async {
    if (_initialized && !bypassCheck) return;

    // 1. Pedir permisos (iOS muestra dialog, Android 13+ también)
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
      provisional: false,                  // poné true si querés "quiet" notif en iOS
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] permiso denegado');
      return;
    }

    // 2. iOS: esperar APNs token antes del FCM token
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      String? apns = await FirebaseMessaging.instance.getAPNSToken();
      if (apns == null) {
        await Future.delayed(const Duration(seconds: 2));
        apns = await FirebaseMessaging.instance.getAPNSToken();
      }
    }

    // 3. FCM token (loggeálo en debug, comentá en producción)
    final token = await FirebaseMessaging.instance.getToken();
    debugPrint('[FCM] token: ${token?.substring(0, 20)}...');

    // 4. Suscripción a topic (idempotente, podés llamarlo siempre)
    await FirebaseMessaging.instance.subscribeToTopic(_topic);

    // 5. Token refresh listener — si Firebase rota el token, vuelve acá
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      // Re-suscribir si hace falta, o notificar a tu backend.
      await FirebaseMessaging.instance.subscribeToTopic(_topic);
    });

    // 6. Handlers de los 3 estados (foreground / opened / initial)
    _setupHandlers();

    _initialized = true;
  }

  void _setupHandlers() {
    // FOREGROUND: app abierta. FCM NO muestra la notif automáticamente,
    // hay que re-mostrarla con flutter_local_notifications.
    FirebaseMessaging.onMessage.listen((message) async {
      await _showAsLocalNotification(message);
      _onMessageReceived(message);
    });

    // BACKGROUND CON TAP: app en background, user tapea la notif.
    // El SO ya mostró la notif (FCM la pintó); este callback corre cuando
    // el usuario la toca y la app vuelve a foreground.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleTap(message);
    });

    // TERMINATED: app cerrada, user tapea la notif y abre la app.
    // Llamar UNA vez al startup, NO en cada init.
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleTap(message);
    });
  }

  Future<void> _showAsLocalNotification(RemoteMessage m) async {
    // Re-mostrar como notif local — ver §8 sobre canales.
    await NotificationService.showFromFcm(m);
  }

  void _onMessageReceived(RemoteMessage m) {
    // Lógica de negocio: invalidar cache, refrescar UI, agregar a campanita, etc.
    // NO navegar acá; solo cuando el usuario tapea (_handleTap).
  }

  void _handleTap(RemoteMessage m) {
    // Persistir el deep link para que el primer widget root lo procese.
    final eventCode = m.data['event_code'] as String?;
    if (eventCode == null) return;
    SharedPreferences.getInstance().then((p) {
      p.setString('pending_event_code', eventCode);
    });
    // Navegación real va a ocurrir cuando el widget tree esté listo.
  }

  /// Llamar al volver a foreground (didChangeAppLifecycleState resumed).
  Future<void> checkOnAppOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getString('pending_event_code');
    if (pending != null) {
      await prefs.remove('pending_event_code');
      // Navegar al detalle. Usa GlobalKey<NavigatorState> guardado en una clase
      // accesible desde acá (no contexto de widget).
      AppNavigator.openEventDetail(pending);
    }
  }
}
```

### Notas críticas sobre el código

- **Singleton, NO inicializado en main**: necesita Activity activa (en Android) y permisos solicitables (en iOS) → siempre dentro de `addPostFrameCallback`.
- **`bypassCheck`**: útil para forzar re-inicialización después de cambios de versión de la app o reset de permisos.
- **Foreground re-show con local notif**: si lo olvidás, el usuario nunca ve los avisos cuando la app está abierta. Es el bug más común "no me llegan las notif" cuando en realidad sí llegan, solo que invisibles.
- **`getInitialMessage()` UNA vez**: si lo llamás en cada init, vas a abrir el deep link cada vez que la app se reanude.

---

## 8. Canales y coexistencia FCM + notif locales

### 8.1 Por qué necesitás 3 canales en Android

QueHacemos usa estos en producción:

| Canal | Usado para | Importance | Sound |
|-------|------------|------------|-------|
| `general` | Notif locales misceláneas (sync OK, error, etc.) | Default | No |
| `fcm_messages` | FCM re-mostrado en foreground | High | Sí |
| `reminders` | Notif locales programadas (recordatorios) | High | Sí |

**Por qué separados:**
- El usuario puede silenciar canales individuales desde Ajustes del sistema. Si poniendo todo en `default` el user lo silencia, perdés las críticas.
- Cada canal tiene su propio sonido/vibración/LED.
- Auditoría: `adb shell dumpsys notification` muestra por canal.

### 8.2 Re-mostrar FCM como local notification (foreground)

```dart
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> showFromFcm(RemoteMessage m) async {
    final notification = m.notification;
    if (notification == null) return;

    await _plugin.show(
      m.hashCode,                          // ID derivado para evitar colisiones
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'fcm_messages',
          'Mensajes de la nube',
          channelDescription: 'Avisos enviados desde el servidor',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(m.data),         // payload completo para deep link
    );
  }
}
```

> **Lección de QueHacemos:** durante meses creyeron que "FCM no funciona en Android" porque las notif no aparecían con la app abierta. **Sí funcionaba** — lo que faltaba era el re-show. Es el bug invisible más caro de FCM.

### 8.3 Diferenciación de IDs

Si usás FCM **e** notif locales programadas, evitá colisiones de ID:

| Tipo | Rango de IDs |
|------|--------------|
| Locales programadas (item-based) | `itemId * 10 + offset` (ej. 1230, 1231, 1232) |
| FCM re-mostradas | `message.hashCode` |
| Tests | `99996-99999` |

---

## 9. Manejo de los 3 estados (cheat sheet)

| Estado | Cómo llega | Quién muestra la notif | Tap handler |
|--------|------------|-------------------------|-------------|
| **Foreground** (app abierta) | `FirebaseMessaging.onMessage` | **Vos** con `flutter_local_notifications` | Tu callback de `flutter_local_notifications` |
| **Background** (app minimizada) | El SO la pinta vía la payload `notification` de FCM | Android/iOS automáticamente | `FirebaseMessaging.onMessageOpenedApp` |
| **Terminated** (app cerrada) | Idem background | Android/iOS automáticamente | `FirebaseMessaging.instance.getInitialMessage()` (UNA vez al cold start) |

### 9.1 Payload de FCM — `notification` vs `data`

```json
// Mensaje "display" (el SO lo muestra solo en background/terminated):
{
  "notification": {
    "title": "Hola",
    "body": "Mundo"
  },
  "data": {
    "event_code": "EVT123",
    "type": "reminder"
  }
}

// Mensaje "silent" / data-only (NUNCA se muestra solo, vos decidís):
{
  "data": {
    "action": "daily_recovery",
    "event_code": "EVT123"
  },
  "content_available": true,    // ← iOS requiere esto para silent push
  "priority": "high"            // ← Android requiere esto para wake del Doze
}
```

> **Patrón silent push (de QueHacemos):** el backend manda data-only con `action: 'daily_recovery'`. El handler background lo recibe, hace su lógica, y opcionalmente programa una notif local visible. **Es la base del recovery sin WorkManager** (ver §11).

### 9.2 Cold start con sync — el caso peligroso

Si tu deep link necesita datos que vienen de un sync remoto, hay race condition:

```dart
// MAL — abre el modal antes de que el sync termine, datos vacíos
final code = m.data['event_code'];
openDetailModal(code);   // ← evento aún no está en SQLite
```

```dart
// BIEN — espera al sync si lo necesita, sino abre directo
final code = m.data['event_code'];
if (await needsSyncToday()) {
  await syncService.run();
}
// Retry loop por si el evento aún no llegó:
for (int i = 0; i < 5; i++) {
  final event = await db.getEvent(code);
  if (event != null) return openDetailModal(event);
  await Future.delayed(const Duration(seconds: 1));
}
```

QueHacemos midió: **8-12 segundos** desde tap hasta modal cuando hay sync, **2-3 segundos** sin sync. Hacelo asíncrono con un loading state, no bloquees el cold start.

---

## 10. Permisos — flujo correcto

### 10.1 Cuándo pedir

**NO pidas permisos en `main()` ni en el splash.** Los quemás. Lecciones:

- **iOS**: el primer `requestPermission()` muestra el dialog del sistema. Si el usuario lo niega, **nunca más** se muestra → tenés que mandarlo a Ajustes.
- **Android 13+**: idem con `POST_NOTIFICATIONS`. Si lo niega 2 veces, el dialog desaparece para siempre.

### 10.2 Cuándo SÍ pedir

- En **onboarding**, después de que el usuario entendió qué va a recibir.
- En **Settings**, cuando activa explícitamente un toggle "Recibir avisos".
- En **el primer momento útil**: cuando crea su primer favorito / recordatorio / cuenta. Contexto = aceptación.

### 10.3 Verificar antes de pedir

```dart
final settings = await FirebaseMessaging.instance.getNotificationSettings();
switch (settings.authorizationStatus) {
  case AuthorizationStatus.authorized:
  case AuthorizationStatus.provisional:
    // Ya tenés permiso, seguir
    break;
  case AuthorizationStatus.notDetermined:
    // Primer pedido — mostrar dialog
    await FirebaseMessaging.instance.requestPermission(/* ... */);
    break;
  case AuthorizationStatus.denied:
    // Ya negó. NO volver a pedir, mandar a Ajustes.
    await openAppSettings();   // permission_handler
    break;
}
```

---

## 11. Recovery diario sin WorkManager

> **🔥 La gran lección de QueHacemos**: instalaron WorkManager (`fd9610a workmanager instalado en daily`), pelearon **semanas** de bugs de background, y terminaron sacándolo (`7eae1d7 sin workmanager`). Lo reemplazaron por:
>
> 1. **FCM silent push diario** desde el backend (Cloud Function con cron).
> 2. **Recovery on app open** (`DailyTaskManager.checkOnAppOpen()`).
>
> En `repo4` (versión actual en producción) **NO hay WorkManager**.

### 11.1 Patrón "FCM silent + on-resume recovery"

```dart
class DailyTaskManager {
  static const _kLastRunKey = 'last_daily_run';

  /// Llamar en didChangeAppLifecycleState(resumed) y al startup.
  Future<void> checkOnAppOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRun = prefs.getString(_kLastRunKey);
    final today = _yyyymmdd(DateTime.now());
    if (lastRun == today) return;   // ya corrió hoy
    if (DateTime.now().hour < 6) return;   // no antes de las 6 AM

    // Connectivity check → si no hay internet, programar Timer de retry.
    if (!await _hasInternet()) {
      Timer(const Duration(minutes: 20), checkOnAppOpen);
      return;
    }

    await _runDailyTask();
    await prefs.setString(_kLastRunKey, today);
  }

  Future<void> _runDailyTask() async {
    // Sync, scheduling de notif del día, lo que sea.
  }
}
```

### 11.2 Backend manda silent push diario

Cloud Function con cron (Cloud Scheduler) que dispara FCM data-only a un topic:

```js
// pseudocódigo Cloud Function
exports.dailyKick = scheduler.cron('0 8 * * *')(async () => {
  await admin.messaging().send({
    topic: 'all_users',
    data: { action: 'daily_recovery' },
    android: { priority: 'high' },
    apns: { headers: { 'apns-priority': '5' }, payload: { aps: { contentAvailable: true } } },
  });
});
```

El handler en Dart:

```dart
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage m) async {
  if (m.data['action'] == 'daily_recovery') {
    // Throttling: evitar dobles ejecuciones (FCM puede entregar 2x).
    final prefs = await SharedPreferences.getInstance();
    final lastTrigger = prefs.getInt('last_daily_trigger') ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - lastTrigger < 60_000) return;
    await prefs.setInt('last_daily_trigger', DateTime.now().millisecondsSinceEpoch);

    // Lógica corta acá. Mantener <30s o el SO mata el handler.
  }
}
```

### 11.3 Por qué este patrón funciona

| Problema | Cómo lo resuelve este patrón |
|----------|------------------------------|
| WorkManager no se ejecuta en OEMs agresivos | FCM silent **sí** atraviesa Doze (priority high) |
| Tareas largas matadas a los 30s | El silent solo dispara, el trabajo real corre cuando el user abre la app |
| Sincronizar la lógica con login/permisos | Recovery on-resume usa el contexto completo del app |
| Reboot pierde alarmas | FCM no depende de alarmas locales |
| Doble ejecución | Flag de timestamp en SharedPreferences |

---

## 12. Topics vs Tokens individuales

| Estrategia | Cuándo |
|------------|--------|
| **Topic único** (`'all_users'`) | App con un solo segmento. Cambios de versión / reinstall no rompen suscripción. **Esto eligió QueHacemos.** |
| **Topics por idioma/región** (`'es_AR'`, `'en_US'`) | Segmentación simple sin backend. |
| **Tokens individuales** | Mensajes 1:1 (chat, transacciones, alertas personales). Requiere backend que mantenga el token actualizado. |

### 12.1 Topic — patrón en QueHacemos

```dart
// En init, idempotente:
await FirebaseMessaging.instance.subscribeToTopic('eventos_cordoba');

// En onTokenRefresh, re-suscribir por las dudas:
FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
  await FirebaseMessaging.instance.subscribeToTopic('eventos_cordoba');
});
```

### 12.2 Token — patrón con backend

```dart
final token = await FirebaseMessaging.instance.getToken();
await myBackend.registerToken(userId, token);

FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
  await myBackend.updateToken(userId, newToken);
});
```

> **Token refresh** ocurre cuando: el usuario reinstala la app, restaura backup, borra datos, o Firebase rota internamente. Si tu backend no escucha `onTokenRefresh`, perdés a ese usuario para siempre.

---

## 13. Bugs silenciosos conocidos (de la historia real)

Tabla destilada de los 128 commits de QueHacemos:

| # | Síntoma | Causa real | Fix |
|---|---------|------------|-----|
| 1 | Notif no aparecen con app abierta | FCM **NO** muestra automáticamente en foreground | Re-mostrar con `flutter_local_notifications` (§8.2) |
| 2 | Release Android 9 (API 28) sin notif, debug OK | R8 ofusca `firebase_messaging` | ProGuard rules + `-keepattributes` (§4.4) — 4 commits seguidos en QueHacemos |
| 3 | Background handler nunca corre | Falta `@pragma('vm:entry-point')` o no es top-level | Función top-level + pragma (§6) |
| 4 | iOS: `getToken()` retorna null | APNs aún no listo | Esperar 2s y reintentar |
| 5 | iOS: notif llegan a Firebase pero no al device | Falta certificado APNs en Firebase Console | Subir `.p8` desde Apple Developer |
| 6 | Tap abre el deep link cada vez que la app reanuda | `getInitialMessage()` llamado en cada init | Llamar UNA vez en cold start |
| 7 | Cold start abre detalle vacío | Deep link procesado antes del sync | Retry loop o esperar al sync (§9.2) |
| 8 | WorkManager nunca dispara en Motorola/Xiaomi | OEMs matan tareas de WorkManager en background | Reemplazar por FCM silent + on-resume (§11) |
| 9 | Notif duplicadas | FCM puede entregar 2x el mismo mensaje (at-least-once) | Throttle por timestamp en SharedPreferences |
| 10 | Token cambia silenciosamente y backend manda a token muerto | No escucha `onTokenRefresh` | Listener de refresh con re-registro |
| 11 | Permisos negados, dialog ya no aparece | Android/iOS no muestran el dialog tras 2 rechazos | `openAppSettings()` (permission_handler) |
| 12 | Background handler tarda > 30s y se mata | El SO le da ventana corta al isolate background | Mantener handler corto, delegar trabajo pesado al on-resume |
| 13 | Topic sub falla en Android 9 | Mismo issue de minification | Misma fix que #2 |
| 14 | Cuadrado gris como ícono FCM | Falta `default_notification_icon` en manifest | `<meta-data>` con drawable monocromo (§4.3) |
| 15 | iOS: notif silent no despiertan la app | Falta `content_available: true` en payload o `remote-notification` en `UIBackgroundModes` | Setear ambos |
| 16 | Notif local programada perdida tras reboot | `RECEIVE_BOOT_COMPLETED` no declarado | Permiso + `ScheduledNotificationBootReceiver` (§4.3) |
| 17 | Try/catch silenciosos comen errores reales | 22+ `catch (e) { }` sin logging en QueHacemos | Loggear con `debugPrint` mínimo, mejor con un sink de telemetría |
| 18 | iOS: FCM token funciona en simulador pero no en device físico | Push notifications no funciona en simulador iOS | Probar siempre en device físico |
| 19 | App no recibe push tras "force stop" del usuario | Comportamiento by-design de Android | No hay fix; documentarlo |
| 20 | `subscribeToTopic` retorna OK pero no llegan mensajes | Topic mal escrito (typo, espacios) | Constante `static const _topic = 'all_users'`, no string literal disperso |

---

## 14. Lecciones — qué NO hacer

Destiladas de los 128 commits de iteración real:

1. **NO uses WorkManager para tareas diarias en una app FCM.** Reemplazá por FCM silent + on-resume recovery (§11). En QueHacemos: `fd9610a workmanager instalado` → `7eae1d7 sin workmanager`.
2. **NO inicialices FCM en `main()`** (necesita Activity). Usá `addPostFrameCallback` en el primer widget.
3. **NO pidas permisos sin contexto** (en main, splash, primer arranque). Los quemás.
4. **NO confíes en que `isMinifyEnabled = false`** te salve en release. Configurá ProGuard correctamente desde el día 1.
5. **NO uses topics literales esparcidos** por el código. Una constante. Cambiar el nombre del topic más tarde es muy doloroso.
6. **NO mezcles canales**. 3 separados (`general`, `fcm_messages`, `reminders`) te dan control granular en Ajustes del SO.
7. **NO te olvides del re-show foreground.** Es el bug más invisible y más común.
8. **NO commit los archivos de Firebase** (`google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart` con keys).
9. **NO hagas trabajo pesado en el background handler.** <30s. Delegá al on-resume.
10. **NO confíes en `getInitialMessage()` repetido**. Llamarlo solo en cold start.
11. **NO ignores `onTokenRefresh`** si usás tokens individuales. El usuario desaparece de tu base.
12. **NO probás en simulador iOS** y declarás "funciona". Push notifications NO funcionan en simulador iOS — probá en device físico siempre.
13. **NO uses FCM para "alarmas exactas"**. La latencia es de segundos a minutos. Si necesitás precisión de hora, usá notif locales con `exactAllowWhileIdle`.
14. **NO escribas 22 try/catch silenciosos.** Loggeá. Si no querés mostrar al usuario, mandalo a un sink de telemetría.

---

## 15. Checklist de QA antes de release

### Funcional
- [ ] Cold start con app cerrada → tap en notif → abre el detalle correcto.
- [ ] App en background → notif del SO visible → tap → abre detalle.
- [ ] App en foreground → notif local re-mostrada → tap → abre detalle.
- [ ] Token registrado en backend / topic suscripto al primer init.
- [ ] `onTokenRefresh` re-registra token (probar borrando datos de la app).
- [ ] Silent push en background ejecuta el handler (loggear con `debugPrint` y verificar en `adb logcat`).

### Plataforma
- [ ] Android 13+: dialog de POST_NOTIFICATIONS aparece y se respeta.
- [ ] Android 9 (API 28) en **release** con minify ON: notif llegan. (Sin esto pasaste por alto la trampa #2.)
- [ ] iOS: probar en **device físico**, no simulador.
- [ ] iOS: certificado APNs subido a Firebase Console.
- [ ] iOS: capabilities Push Notifications + Background Modes (`remote-notification`).

### Build
- [ ] `google-services.json` y `GoogleService-Info.plist` están en el build pero NO commiteados.
- [ ] ProGuard rules: `-keep com.google.firebase.**`, `-keep com.dexterous.**`, `-keepattributes` x4.
- [ ] `keep.xml` en `res/raw/` para `ic_notification`.
- [ ] `firebase_options.dart` generado por `flutterfire configure` con los IDs correctos.

### Edge cases
- [ ] App con sync pendiente al cold start desde tap: maneja el race condition.
- [ ] Mismo mensaje entregado 2x: throttle activo.
- [ ] App matada con "Force Stop" desde Ajustes: documentar que no recibirá push hasta abrir manualmente.
- [ ] Reboot del device: notif locales programadas re-aparecen, FCM sigue llegando.

---

## 16. Mapa de archivos del patrón final

Estructura de `repo4_QueHacemosClean` (versión en producción):

```
lib/
├── main.dart                                       # Firebase init + bg handler + tz
├── firebase_options.dart                           # Generado por flutterfire
└── src/
    ├── services/
    │   ├── notification_manager.dart               # FCM (init, handlers, topic, token)
    │   ├── notification_service.dart               # Local notif (canales, scheduling, badge)
    │   ├── notification_config_service.dart        # Setup wizard one-time
    │   └── daily_task_manager.dart                 # On-resume recovery (reemplaza WM)
    └── providers/
        └── notifications_provider.dart             # UI state (campanita, lista in-app)

android/
└── app/
    ├── google-services.json                        # NO commitear
    ├── build.gradle.kts                            # plugin com.google.gms.google-services
    ├── proguard-rules.pro                          # Firebase + keepattributes
    └── src/main/
        ├── AndroidManifest.xml                     # permisos + 3 receivers + meta-data ic_notification
        └── res/raw/keep.xml                        # tools:keep ic_notification

ios/
└── Runner/
    ├── GoogleService-Info.plist                    # NO commitear
    ├── AppDelegate.swift                           # Mínimo
    └── Info.plist                                  # UIBackgroundModes + APNs config
```

### Resumen funcional por archivo

| Archivo | Responsabilidad |
|---------|-----------------|
| `main.dart` | Bootstrap: Firebase, background handler, timezone, runApp |
| `notification_manager.dart` | FCM puro: init, permisos, token, topic, los 3 handlers |
| `notification_service.dart` | Notif locales: canales, scheduling con `zonedSchedule`, re-show de FCM, badge |
| `notification_config_service.dart` | Setup one-time con estados (idle, requesting, configured, error) |
| `daily_task_manager.dart` | Recovery on-resume: connectivity check, throttle, retry timer |
| `notifications_provider.dart` | Estado de UI para la campanita / lista de avisos in-app |

---

## 17. TL;DR

1. **FCM solo para push remotos.** Para programados locales, usar `flutter_local_notifications` (ver manual aparte).
2. **Stack**: `firebase_core ^4.0.0` + `firebase_messaging ^16.0.1` + `flutter_local_notifications ^21.0.0`.
3. **Background handler**: top-level + `@pragma('vm:entry-point')`, registrado en `main()` después de `Firebase.initializeApp()`.
4. **Init de FCM**: en `addPostFrameCallback`, NO en `main()`.
5. **3 estados**: foreground (re-mostrá vos), background (SO pinta + `onMessageOpenedApp` para tap), terminated (`getInitialMessage()` UNA vez).
6. **Re-show foreground es OBLIGATORIO** o el usuario nunca ve nada con la app abierta.
7. **ProGuard**: `-keep com.google.firebase.**` + 4 `-keepattributes` o release falla en silencio en Android 9.
8. **Permisos**: NUNCA en main/splash. Solo cuando el user activa algo explícito.
9. **Para tareas diarias**: NO WorkManager. Usá FCM silent + on-resume recovery.
10. **Topics > tokens** salvo que necesites mensajería 1:1.
11. **iOS**: APNs key `.p8` subido a Firebase, capabilities en Xcode, probar en device físico.
12. **Throttle FCM**: at-least-once delivery → flag de timestamp en SharedPreferences para evitar duplicados.

---

## 18. Referencias de código

### Repo1 (`repo1_QueHacemos`, 128 commits) — historia de iteraciones
- Útil para entender **qué se intentó y falló**: WorkManager (`fd9610a` → `7eae1d7`), HTTP push a Cloud Function (`a5c2911`), 4 fixes de minification API 28 (`2051d3e`, `a10e985`, `d132931`, `0705e33`).
- Buenos commits para `git show <hash>`: `7eae1d7 sin workmanager`, `0705e33 api 28 fix 4 º`, `86ac30b fix notific release`.

### Repo4 (`repo4_QueHacemosClean`, 30 commits) — versión actual en producción
- Estado limpio post-aprendizaje. **Sin** WorkManager, **sin** HTTP push, **con** DailyTaskManager simplificado.
- Stack: `flutter_local_notifications ^21.0.0` (más nuevo que repo1).
- Archivos clave de referencia:
  - `lib/main.dart` (líneas 28-59) — bootstrap correcto
  - `lib/src/services/notification_manager.dart` — patrón singleton FCM
  - `lib/src/services/daily_task_manager.dart` — recovery sin WorkManager
  - `android/app/src/main/AndroidManifest.xml` — permisos + receivers + meta-data
  - `ios/Runner/Info.plist` — capabilities y background modes

### Manual relacionado
- `.context/manual_notificaciones_locales.md` — para el setup de notif locales programadas (necesarias incluso en una app FCM por el re-show foreground y por scheduling local).

---

## 19. Patrones avanzados de UX y edge cases

Patrones extraídos del código de producción (repo4 `QueHacemosClean`). Cada uno está **verificado contra el código real**, con la cita al archivo:línea para que puedas leerlo directo si dudás.

### 19.1 Retry loop esperando NavigatorState en cold start

**Problema:** cuando el usuario tap en una notif con la app cerrada, el cold start abre el Navigator, pero **el `_navigatorKey.currentContext` aún es `null`** durante los primeros 100-500ms. Si intentás abrir el deep link inmediatamente, falla en silencio.

**Patrón** (`main.dart:241-242`):

```dart
WidgetsBinding.instance.addPostFrameCallback((_) async {
  int attempts = 0;
  while ((_navigatorKey.currentContext == null || !mounted) && attempts < 40) {
    await Future.delayed(const Duration(milliseconds: 50));
    attempts++;
  }
  if (_navigatorKey.currentContext == null) return;   // 2s sin Navigator → skip
  await _openEventFromNotification(eventCode);
});
```

**Por qué 40 × 50ms = 2s**: empíricamente cubre el 99% de los cold starts. Más allá de 2s sin Navigator es síntoma de otro bug, no race condition normal.

### 19.2 Flag global `appOpenedByFCM` para skipear prompts

**Problema:** si el usuario llegó a la app vía tap-en-FCM, ya tiene una intención clara (ver el evento). Mostrarle prompts de login/permisos en ese momento es **interrumpirlo** y aumenta el churn.

**Patrón** (`main.dart:34, 223, 230, 273, 283`):

```dart
bool appOpenedByFCM = false;   // top-level

// En _setupInteractedMessage(), si initialMessage existe:
appOpenedByFCM = true;

// En didChangeAppLifecycleState(paused):
appOpenedByFCM = false;        // resetear cuando se va a background

// En el evaluador de prompts:
if (!appOpenedByFCM) {
  // mostrar prompts solo si NO entró por FCM
}
```

**Lección:** un flag global feo es a veces mejor que pasar contexto por 5 capas. En este caso justifica el "smell" porque cruza muchísima distancia (main → home → tabs → prompts).

### 19.3 Guard `_hasOpenedPendingEvent` contra taps múltiples

**Problema:** el usuario tiene 3 notif acumuladas, las tapea rápido seguidas. Sin guard, abrís 3 modales encima (o crash de navegación).

**Patrón** (`main.dart:98, 170-171` y `sync_snackbar_widget.dart:29, 135, 144`):

```dart
class _AppContentState extends State<AppContent> {
  bool _hasOpenedPendingEvent = false;

  Future<void> _openEventFromNotification(String code) async {
    if (_hasOpenedPendingEvent) return;
    _hasOpenedPendingEvent = true;
    try {
      // ... abrir modal ...
    } finally {
      _hasOpenedPendingEvent = false;   // resetear cuando el modal cierra
    }
  }
}
```

**Cuidado:** resetear en `finally`, NO al final del try. Si el modal lanza exception, el flag queda lockeado y nunca más abrís nada.

### 19.4 Dual fetch cache + DB para abrir el detalle

**Problema:** abrir el modal del evento necesita dos cosas con timings distintos:
- **Datos básicos** (colores, formato, rating) para la animación Hero del card → **YA están en el cache en memoria**.
- **Datos completos** (descripción full, links, imágenes) → solo en SQLite.

Si esperás solo a la DB, la animación Hero arranca tarde. Si solo usás el cache, te falta info.

**Patrón** (`main.dart:178, 184`):

```dart
// 1. Cache (sync, inmediato) → permite arrancar la animación Hero
final cacheEvent = simpleHomeProvider.events.firstWhere(
  (e) => e.spacecode == eventCode,
);

// 2. DB (async) → completa los datos
final fullEventList = await repository.getEventsByCodes([eventCode]);
final fullEvent = fullEventList.first;

// 3. Modal con ambos
EventDetailModal.show(context, cacheEvent, fullEvent);
```

**Generalizable:** cuando un destino necesita datos rápidos (UI shell) + datos completos (contenido), separá las dos lecturas y arrancá la UI con los datos rápidos mientras se cargan los completos.

### 19.5 Token tracking minimizado (20 caracteres)

**Problema:** `onTokenRefresh` no siempre se dispara cuando debería (reinstall, restore de backup, clear data). Para detectar cambios necesitás guardar el token. Pero guardar el token completo en SharedPreferences es innecesario — solo necesitás detectar que cambió.

**Patrón** (`notification_manager.dart:51`):

```dart
final currentToken = await FirebaseMessaging.instance.getToken() ?? '';
final currentTokenShort = currentToken.length > 20
    ? currentToken.substring(0, 20)
    : currentToken;

final lastStoredToken = await UserPreferences.getLastFCMToken();
if (lastStoredToken != currentTokenShort) {
  await FirebaseMessaging.instance.subscribeToTopic('all_users');
  await UserPreferences.setLastFCMToken(currentTokenShort);
}
```

**Por qué 20 chars**: la probabilidad de colisión en 20 caracteres alfanuméricos es despreciable (~10^-30). Storage minimizado, lógica idéntica.

### 19.6 WeeklyPromptService con progresión exponencial

**Problema:** después que el usuario rechazó un prompt (login, notif, lo que sea), ¿cuándo volvés a preguntar? Inmediatamente es molesto. Nunca más es perder oportunidades reales.

**Patrón** (`weekly_prompt_service.dart:94-105`, **verbatim**):

```dart
// Progresión: primera vez inmediata, luego 3, 7, 20, 30, 60, 90 días
static int _getRequiredDays(int declineCount) {
  switch (declineCount) {
    case 0: return 0;        // primera vez — inmediato
    case 1: return 3;
    case 2: return 7;
    case 3: return 20;
    case 4: return 30;
    case 5: return 60;
    case 6: return 90;
    default: return 999999;  // 7º rechazo → nunca más
  }
}
```

**Persistencia** en SharedPreferences con formato `"timestamp_declineCount"`:

```dart
final data = prefs.getString('login_prompt_data') ?? '0_0';
final parts = data.split('_');
final lastPrompt = int.parse(parts[0]);
final declineCount = int.parse(parts[1]);
final daysPassed = (DateTime.now().millisecondsSinceEpoch - lastPrompt) ~/ 86400000;

return daysPassed >= _getRequiredDays(declineCount);
```

**Aplica a:** login, permisos de notificación, prompts de upgrade, pedido de review en App Store. Mismo patrón con keys distintas.

### 19.7 Detección de "primera apertura del día" + dual path en cold start

**Problema:** cuando el cold start es por tap-en-FCM, ¿corro el sync diario primero o abro el modal directo? Depende:
- Si **es la primera vez del día**: hay eventos nuevos en Firestore que el modal va a necesitar → esperar sync.
- Si **ya abrí hoy**: la DB ya está actualizada → abrir modal directo (más rápido).

**Patrón** (`main.dart:232-234`):

```dart
final isFirstOpenToday = await DailyTaskManager().needsSyncToday();

if (isFirstOpenToday) {
  // Path A: guardar pending y esperar sync
  await UserPreferences.setPendingEventCode(eventCode);
  // SyncSnackbarWidget abrirá el modal cuando sync complete
} else {
  // Path B: abrir directo con retry loop (§19.1)
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    int attempts = 0;
    while (_navigatorKey.currentContext == null && attempts < 40) {
      await Future.delayed(const Duration(milliseconds: 50));
      attempts++;
    }
    await _openEventFromNotification(eventCode);
  });
}
```

**Timing real medido en QueHacemos:**
- Path A (con sync): **8-12s** desde tap hasta modal.
- Path B (sin sync): **2-3s**.

### 19.8 Doze mode bypass — config del servidor, NO del cliente

> **⚠️ Caveat verificado:** este patrón es real pero **se implementa en el backend, no en la app**. Lo incluyo porque se confunde fácilmente.

**Problema:** Android Doze mode (pantalla apagada >1h) retiene FCM normales y los entrega "al rato". Para avisos importantes, hay que pedir entrega inmediata.

**Patrón (en el backend / Cloud Function que envía el FCM):**

```js
// Node.js / Firebase Admin SDK
await admin.messaging().send({
  topic: 'all_users',
  notification: { title: '...', body: '...' },
  data: { event_code: 'EVT123' },
  android: {
    priority: 'high',                 // ← clave: bypass Doze
  },
  apns: {
    headers: { 'apns-priority': '10' },   // ← equivalente iOS
  },
});
```

**En el lado app (Flutter): nada.** No hay configuración. El `Priority.high` que aparece en `notification_service.dart:109, 138, 190` es del canal Android del **re-show local en foreground** (§8.2), un asunto distinto.

**Costo de `priority: high`:** Google penaliza apps que abusan (FCM puede degradar tu envío a `normal` si mandás high siempre). Reservalo para los avisos que realmente justifican despertar el SO.

---

## 20. Resumen de patrones (cheat sheet)

Cuando vayas a implementar FCM en otra app, este es el orden mental:

1. **Decidí** si necesitás FCM o solo locales (§1).
2. **Setup base**: Firebase + permisos + receivers + ProGuard (§2-5).
3. **main.dart**: `Firebase.initializeApp()` + `onBackgroundMessage()` + timezone (§6).
4. **NotificationManager** singleton, init en `addPostFrameCallback` (§7).
5. **3 canales** Android distintos: general / fcm_messages / reminders (§8).
6. **Re-show foreground** o el usuario nunca ve nada con la app abierta (§8.2).
7. **Manejo de los 3 estados** con cheat sheet (§9).
8. **Permisos**: NUNCA en main, solo cuando el user activa algo explícito (§10).
9. **Recovery diario**: FCM silent + on-resume, NO WorkManager (§11).
10. **Topic** o tokens según necesidad (§12).
11. **Si entrás a edge cases** (cold start con sync, taps múltiples, prompts no cargosos): leé §19.

