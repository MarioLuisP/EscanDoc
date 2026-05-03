# Manual de Notificaciones Locales en Flutter

Manual reusable para implementar notificaciones locales programadas en Flutter que **funcionen en producción** en Android 12/13/14+ e iOS. Consolida la experiencia de **QueHacemos** (recordatorios de eventos favoritos, scheduling agrupado por fecha) y **EscanDoc** (avisos de vencimiento de documentos, scheduling individual por documento).

Cada error documentado acá costó tiempo real. Si arrancás un proyecto nuevo, copiá este flujo entero antes de improvisar.

---

## 1. Stack mínimo

```yaml
# pubspec.yaml
dependencies:
  flutter_local_notifications: ^21.0.0   # scheduling local
  timezone: ^0.11.0                      # zonas horarias
  flutter_timezone: ^4.1.0               # CRÍTICO: leer zona real del device
  permission_handler: ^11.0.0            # opcional: battery optim + open settings
```

> **`flutter_timezone` es imprescindible.** Sin él, `tz.local` queda como UTC y las notificaciones se disparan con el offset equivocado (ej. Argentina UTC-3 → 3 horas tarde).
>
> **Verificado en producción:** repo4 (QueHacemos en Play Store + App Store) **omite** `flutter_timezone` en su pubspec — y por eso `main.dart:57` solo llama `tz.initializeTimeZones()` sin `setLocalLocation()`. Es un bug silencioso real que afecta devices con zona mal configurada. **No copiar ese error.**

### Nota de migración del plugin (v17 → v19 → v21)

El plugin `flutter_local_notifications` cambió la firma de `initialize()` entre v19 y v21:

```dart
// v19 (posicional) — repo1 QueHacemos
await _notifications.initialize(
  initSettings,                              // ← positional
  onDidReceiveNotificationResponse: ...,
);

// v21 (named) — repo4 QueHacemos y EscanDoc
await _notifications.initialize(
  settings: initSettings,                    // ← named parameter
  onDidReceiveNotificationResponse: ...,
);
```

Si actualizás el plugin de una versión vieja, **el código compila pero falla en runtime con error de signature**. Ajustar a `settings:` named.

---

## 2. Setup Android

### 2.1 AndroidManifest.xml — permisos

Antes de `<application>`:

```xml
<!-- Android 13+: runtime permission para mostrar notificaciones -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<!-- Android 12+: alarmas exactas (sin esto las notif no se disparan) -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>

<!-- Restaurar alarmas después de reboot/update de la app -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>

<!-- Vibración (opcional pero recomendado) -->
<uses-permission android:name="android.permission.VIBRATE"/>

<!-- OEM agresivos (Motorola, Xiaomi, Huawei): permitir whitelisting -->
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>
```

### 2.2 AndroidManifest.xml — receivers

Dentro de `<application>`:

```xml
<!-- Ejecuta la notificación a la hora exacta -->
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />

<!-- Restaura notificaciones después de reboot / update de la app -->
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
        <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
    </intent-filter>
</receiver>

<!-- Maneja tap en notificación -->
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsReceiver"/>
```

> **Sin los 3 receivers**, las notif no se muestran, no sobreviven reboot, y el tap no hace nada.

### 2.3 Ícono de notificación

Crear `android/app/src/main/res/drawable*/ic_notification.png`:

- **Monocromo**: solo blanco con canal alpha. Sin colores.
- Si tiene colores, Android 5+ muestra un cuadrado gris sólido.

| Carpeta | Tamaño |
|---------|--------|
| `drawable/` (fallback) | 24×24 px |
| `drawable-mdpi/` | 24×24 px |
| `drawable-hdpi/` | 36×36 px |
| `drawable-xhdpi/` | 48×48 px |
| `drawable-xxhdpi/` | 72×72 px |
| `drawable-xxxhdpi/` | 96×96 px |

### 2.4 ProGuard / R8 (release)

`android/app/build.gradle.kts` con `isMinifyEnabled = true` puede romper notificaciones en release de tres formas:

1. **R8 elimina los receivers** del plugin → notif no se muestran.
2. **R8 ofusca clases internas Gson** del plugin → deserialización falla → `initialize()` retorna error.
3. **Resource shrinker dropea `ic_notification`** → `PlatformException(invalid_icon, ...)` solo en release.

**Fix completo en `android/app/proguard-rules.pro`**:

```proguard
# Keep flutter_local_notifications (R8 puede eliminar receivers)
-keep class com.dexterous.** { *; }
-keepclassmembers class com.dexterous.** { *; }

# Atributos requeridos por la deserialización Gson interna del plugin
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod
```

**Fix para el ícono — `android/app/src/main/res/raw/keep.xml`**:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@drawable/ic_notification" />
```

> Confirmado en EscanDoc (Mayo 2026, Motorola G52 API 33): sin estos fixes, `flutter build apk --release` produce un APK que falla con `invalid_icon` aunque en debug funcione perfecto.

---

## 3. Setup iOS

- **NO requiere** receivers ni permisos en `Info.plist` para notificaciones locales.
- Permisos (alert, badge, sound) se piden en `DarwinInitializationSettings` al `initialize()`.
- `zonedSchedule` con `tz.local` funciona correctamente.
- **Foreground**: las notif **NO** se muestran si la app está en foreground (comportamiento iOS). Manejar con `onDidReceiveNotificationResponse` si hace falta visualización in-app.
- `canScheduleExactAlarms()` siempre retorna `true` en iOS (el concepto no aplica).

---

## 4. Inicialización en main.dart (orden CRÍTICO)

```dart
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Cargar base de datos de zonas horarias
  tz_data.initializeTimeZones();

  // 2. Setear la zona local del device.
  //    Sin esto, tz.local = UTC y las notif se programan con offset incorrecto.
  final tzName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(tzName));

  runApp(MyApp(navigatorKey: navigatorKey));
}

final navigatorKey = GlobalKey<NavigatorState>();
```

En el primer widget raíz, dentro de `addPostFrameCallback` (necesita Activity activa):

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    NotificationService.navigatorKey = widget.navigatorKey;
    await NotificationService.initialize();
    // NO pedir permisos acá: quemás los intentos sin contexto.
    // Los permisos se piden cuando el usuario activa el toggle explícitamente.

    // Cold start desde tap en notificación:
    final docId = await NotificationService.getNotificationLaunchDocumentId();
    if (docId != null) widget.navigatorKey.currentState?.pushNamed('/detail', arguments: docId);
  });
}
```

> **Reglas de oro:**
> - `initialize()` SIEMPRE en `addPostFrameCallback`, nunca en `main()` antes de `runApp()`.
> - **NO** pedir permisos en `main()` ni en onboarding — quemás los intentos del SO.
> - Permisos se piden **solo** cuando el usuario activa explícitamente el toggle.

---

## 5. NotificationService — estructura de referencia

```dart
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static GlobalKey<NavigatorState>? navigatorKey;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Recordatorios',
      channelDescription: 'Avisos programados',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',           // sin "@drawable/" prefix
      color: Color(0xFF7ED321),
    ),
    iOS: DarwinNotificationDetails(),
  );

  // ── Init ────────────────────────────────────────────────────────────

  static Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      const android = AndroidInitializationSettings('ic_notification');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      final ok = await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: _onTap,
      );
      // BUG conocido: en algunos devices (Motorola G52 API 33) `initialize()`
      // retorna null en lugar de true. `ok == true` trataría null como fallo.
      if (ok != false) {
        _initialized = true;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[Notif] initialize error: $e');
      return false;
    }
  }

  static bool get isInitialized => _initialized;

  // ── Estado de permisos ──────────────────────────────────────────────

  static Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final a = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await a?.areNotificationsEnabled() ?? true;
    }
    if (Platform.isIOS) {
      final i = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await i?.requestPermissions(
        alert: true, badge: true, sound: true);
      return granted ?? true;
    }
    return true;
  }

  static Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    final a = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await a?.canScheduleExactNotifications() ?? true;
  }

  // ── Pedir permisos (cada uno por separado, NUNCA juntos en init) ────

  static Future<void> requestNotificationPermissionOnly() async {
    if (!_initialized) return;
    if (Platform.isAndroid) {
      final a = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await a?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      final i = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await i?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  static Future<void> requestExactAlarmPermission() async {
    if (!_initialized || !Platform.isAndroid) return;
    final a = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await a?.requestExactAlarmsPermission();   // abre Ajustes del sistema
  }

  // ── Programar ───────────────────────────────────────────────────────

  static Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {
    if (!_initialized) return;
    if (!when.isAfter(DateTime.now())) return;  // pasado → ignorado en silencio
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        _toTZ(when),
        _details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('[Notif] schedule id=$id error: $e');
    }
  }

  static Future<void> cancel(int id) => _plugin.cancel(id);
  static Future<void> cancelAll() => _plugin.cancelAll();

  // ── Cold start desde tap ────────────────────────────────────────────

  static Future<int?> getNotificationLaunchDocumentId() async {
    final d = await _plugin.getNotificationAppLaunchDetails();
    if (d?.didNotificationLaunchApp != true) return null;
    return _parseId(d?.notificationResponse?.payload);
  }

  static void _onTap(NotificationResponse r) {
    final id = _parseId(r.payload);
    if (id == null) return;
    navigatorKey?.currentState?.pushNamed('/detail', arguments: id);
  }

  static int? _parseId(String? payload) {
    if (payload == null || !payload.startsWith('reminder:')) return null;
    return int.tryParse(payload.split(':').last);
  }

  // ── Helper TZ — incluir SEGUNDOS ────────────────────────────────────
  // Sin segundos, las notif de prueba con delay <60s caen "en el pasado"
  // y se descartan en silencio.
  static tz.TZDateTime _toTZ(DateTime t) => tz.TZDateTime(
      tz.local, t.year, t.month, t.day, t.hour, t.minute, t.second);
}
```

### Notas sobre el código

- **`icon: 'ic_notification'`** — en v21 ambas formas funcionan: sin prefijo (EscanDoc, `notification_service.dart:25`) y con prefijo `'@drawable/ic_notification'` (repo4 QueHacemos, `notification_service.dart:27, 110, 139, 191`). Recomendado: sin prefijo, para evitar builds inestables si el plugin cambia comportamiento.
- **`success != false`** en `initialize()` — `bool?` puede ser `null` en Motorola y otros OEMs. Usar `success == true` deja `_initialized = false` y todo el sistema falla en silencio.
- **`_toTZ()` con segundos** — las pruebas a 20s/40s/60s necesitan el segundo, sin él se truncan al minuto y caen al pasado.
- **Permisos separados** — NUNCA llamar `requestNotificationsPermission()` y `requestExactAlarmsPermission()` juntos en init. Cada uno tiene su contexto y momento (ver sección 6).

---

## 6. Flujo de activación desde el toggle de Settings

Pedir permisos solo cuando el usuario activa explícitamente. Implementar `WidgetsBindingObserver` para retomar el flujo cuando vuelve de Ajustes del sistema.

### Pasos (orden estricto)

```
[Toggle ON]
    │
    ▼
1. initialize()                              ← si no estaba inicializado
    │
    ▼
2. requestNotificationPermissionOnly()       ← POST_NOTIFICATIONS (dialog runtime)
    │
    ▼
3. areNotificationsEnabled()
    │  ├─ false → openAppSettings()          ← dialog ya negado 2 veces, abrir ajustes
    │  │          (esperar resume vía WidgetsBindingObserver)
    │  └─ true → continúa
    ▼
4. canScheduleExactAlarms()
    │  ├─ false → requestExactAlarmPermission()  ← abre Settings de alarmas exactas
    │  │          (esperar resume)
    │  └─ true → continúa
    ▼
5. Permission.ignoreBatteryOptimizations     ← OPCIONAL pero recomendado
    │  ├─ granted → skip
    │  └─ denied → modal explicativo + request (Android only, no bloquea)
    ▼
6. enableNotifications()                     ← reschedule de TODOS los items
    │
    ▼
7. Modal de éxito (auto-cierre 3s)
```

### Por qué este orden

- **`initialize` antes de cualquier `request*`**: el plugin necesita estar inicializado para resolver el `AndroidFlutterLocalNotificationsPlugin`.
- **`POST_NOTIFICATIONS` antes de exact alarms**: si el usuario rechaza el primero, el segundo no tiene sentido.
- **`openAppSettings()` cuando el dialog ya no aparece**: Android no muestra el dialog runtime si fue rechazado 2 veces. Hay que abrir Ajustes manualmente.
- **Battery optim al final**: es opt-in. Si lo pones antes, el usuario ya puso el toggle ON y rechaza por fatiga.

### Pseudocódigo del state

```dart
class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  bool _waitingForExactAlarms = false;
  bool _waitingForNotifPermission = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_waitingForExactAlarms) {
      _waitingForExactAlarms = false;
      _finalizeEnable();
    } else if (_waitingForNotifPermission) {
      _waitingForNotifPermission = false;
      _resumeAfterNotifSettings();
    }
  }

  Future<void> _enableWithFullFlow() async {
    if (!NotificationService.isInitialized) {
      final ok = await NotificationService.initialize();
      if (!ok) return _showError('init_failed');
    }
    await NotificationService.requestNotificationPermissionOnly();

    if (!await NotificationService.areNotificationsEnabled()) {
      _waitingForNotifPermission = true;
      await openAppSettings();   // permission_handler
      return;
    }
    if (!await NotificationService.canScheduleExactAlarms()) {
      _waitingForExactAlarms = true;
      await NotificationService.requestExactAlarmPermission();
      return;
    }
    await _finalizeEnable();
  }

  Future<void> _finalizeEnable() async {
    await _promptBatteryOptimization();   // opcional, no bloqueante
    await myProvider.enableNotifications();
    _showSuccess();
  }

  Future<void> _promptBatteryOptimization() async {
    if (!Platform.isAndroid) return;
    if (await Permission.ignoreBatteryOptimizations.isGranted) return;
    final proceed = await showDialog<bool>(/* modal explicativo */);
    if (proceed == true) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }
}
```

### Toggle OFF

Mucho más simple — confirmar con el usuario, cancelar todas las notif, persistir el flag:

```dart
Future<void> _disable() async {
  final confirmed = await _confirmDisable();
  if (!confirmed) return;
  await NotificationService.cancelAll();
  await prefs.setEnabled(false);
}
```

> **Estado al cargar la pantalla**: en API 33+, NO confiar en SharedPreferences. Si dice `enabled=true` pero `areNotificationsEnabled()` retorna `false`, sincronizar a `false`. El permiso del sistema puede revocarse desde Ajustes en cualquier momento.

---

## 7. Patrones de scheduling

Dos patrones probados según la naturaleza de los recordatorios:

### 7.1 Patrón A — uno por item, múltiples avisos (EscanDoc)

Cada documento tiene su fecha de vencimiento independiente. Se programan **3 notificaciones por documento**:

```dart
Future<void> scheduleExpiry(int docId, String title, DateTime expiry) async {
  await cancelExpiry(docId);

  final today = DateTime.now();
  final expiryDay = DateTime(expiry.year, expiry.month, expiry.day);

  Future<void> schedule(int id, DateTime date, String body) async {
    final at = DateTime(date.year, date.month, date.day, 9, 0);
    if (!at.isAfter(today)) return;
    await NotificationService.schedule(
      id: id, title: title, body: body, when: at,
      payload: 'reminder:$docId',
    );
  }

  await schedule(docId * 10,     expiryDay.subtract(Duration(days: 7)), 'Vence en 7 días');
  await schedule(docId * 10 + 1, expiryDay.subtract(Duration(days: 1)), 'Vence mañana');
  await schedule(docId * 10 + 2, expiryDay,                              'Vence hoy');
}

Future<void> cancelExpiry(int docId) async {
  await NotificationService.cancel(docId * 10);
  await NotificationService.cancel(docId * 10 + 1);
  await NotificationService.cancel(docId * 10 + 2);
}
```

**Ventajas:**
- ID predecible (`docId * 10 + offset`), no necesita tabla extra.
- Cancel/reschedule trivial al editar el item.
- Plugin persiste internamente, sobrevive reboot sin código custom.

**Cuándo usarlo:** cada item del usuario tiene su propio horario y avisos repetidos a distintas distancias.

### 7.2 Patrón B — agrupado por fecha (QueHacemos)

El usuario marca varios eventos como favoritos. Se programa **1 notificación por fecha** que agrupa todos los favoritos del día. Requiere tabla de tracking en SQLite:

```sql
CREATE TABLE notifications_programadas (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fecha DATE NOT NULL,
  notification_id INTEGER NOT NULL UNIQUE,
  event_codes TEXT NOT NULL,        -- JSON: ["EVT001", "EVT002"]
  hora_programada TIME NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_notif_fecha ON notifications_programadas(fecha);
```

**Operaciones:**

- `notification_id = "daily_$fecha".hashCode` → consistente, fácil de cancelar.
- Al toggle de favorito → debounce 300ms → query DB por fecha:
  - Si no existe → INSERT + schedule.
  - Si existe → agregar/quitar code del JSON array → UPDATE + reschedule (cancel old id, schedule new).
  - Si array queda vacío → cancel + DELETE.

**Mensaje dinámico** según cantidad:
- 1 evento → "✨ No te lo pierdas: [título] ⏰ [hora]"
- 2 eventos → "🥂 Doble planazo: ⏰ [h1] ✨ [t1] y ⏰ [h2] ✨ [t2]"
- 3+ → "🚀 Maratón cultural: desde las [hora más temprana]: [t1], [t2] y N más"

**Hora óptima** (calculada dinámicamente):
- Default: 11:00 AM.
- Si el evento más temprano es antes del mediodía: 1h antes, con piso a las 7:00 AM.
- Re-cálculo en cada update porque agregar/quitar favoritos puede cambiar la hora.

**Cuándo usarlo:** múltiples items pueden caer en la misma fecha y conviene un solo aviso consolidado.

#### 7.2.1 Reschedule: regenerar `notification_id` en cada update

Cuando se edita un item de un día (agregar/quitar favorito), el flujo correcto es **cancelar el ID viejo, generar uno nuevo, schedule, update DB**. Verificado en repo4 `favorites_provider.dart:221-239`:

```dart
// 1. Obtener notification_id viejo de la DB
final existing = await _repository.getScheduledNotificationByDate(fecha);
final oldNotificationId = existing[DatabaseHelper.notificationIdColumn];

// 2. Calcular nuevo notification_id (basado en hash de fecha)
final newNotificationId = NotificationService.generateNotificationId(fecha);

// 3. Cancel viejo, schedule nuevo
await NotificationService.cancelNotification(oldNotificationId);
await _scheduleLocalNotification(/* ... */, newNotificationId);

// 4. UPDATE DB con el nuevo ID
await _repository.updateScheduledNotification(/* ... */, newNotificationId);
```

**Por qué regenerar el ID en cada update**:
- Si la fecha del item cambia, el hash cambia → conviene un ID nuevo para no contaminar el histórico.
- Si la hora calculada cambia (porque agregaste un item más temprano), el plugin del sistema puede tener cacheado el viejo schedule. Cancelar + re-schedule fuerza el refresh.
- El UNIQUE constraint en `notification_id` previene duplicados aunque haya race condition.

**Cuidado con la atomicidad:** estos 4 pasos NO están en una transacción SQLite en repo4. Si dos toggles ocurren en simultáneo (ej. dos taps muy rápidos), puede haber colisión de IDs. Mitigación: el debounce de 300ms del provider previene la mayoría de los casos. Si necesitás garantía estricta, envolvé los pasos 3+4 en un mutex o transacción.

#### 7.2.2 Cleanup automático de la tabla en cada startup

repo4 tiene un sistema de "limpieza diaria" trackeado en una tabla `app_settings` con flag de fecha. Si la fecha guardada NO es hoy, corre cleanup de filas con `fecha < hoy`. Verificado en `favorites_provider.dart:36-46` + `event_repository.dart:488`:

```dart
// En el init del provider:
final needsCleanup = await _repository.needsTableCleanupToday();
if (needsCleanup) {
  await _cleanupOldScheduledNotifications();   // DELETE WHERE fecha < hoy
  await _repository.markTableCleanedToday();   // graba flag en app_settings
}
```

**Por qué tracking en `app_settings`**: evita correr el `DELETE` 50 veces al día. Solo una vez por arranque del primer día nuevo. Costo: 1 SELECT extra por inicialización.

**Schema mínimo de `app_settings`:**

```sql
CREATE TABLE app_settings (
  key TEXT PRIMARY KEY,
  value TEXT
);
-- key='notif_table_last_cleanup', value='2026-05-02'
```

Sin este cleanup, la tabla `notifications_programadas` crece indefinidamente con fechas pasadas. El plugin ya canceló esas notif solo (porque pasaron), pero las filas quedan. En 6 meses son cientos de filas inútiles que ralentizan queries.

### 7.3 Comparación

| Aspecto | Patrón A (EscanDoc) | Patrón B (QueHacemos) |
|---------|---------------------|------------------------|
| Tabla extra | No | Sí (`notifications_programadas`) |
| Notif por item | 3 (escalonadas) | Compartida con otros items |
| ID generation | `docId * 10 + offset` | `hashCode("daily_$fecha")` |
| Reschedule trigger | Edit/delete del item | Toggle de favorito + debounce |
| Mensaje | Estático ("Vence mañana") | Dinámico según cantidad |
| Complejidad | Baja | Media |

---

## 8. Botones de prueba

Validar cada capa del sistema con tests progresivos. Útiles durante desarrollo, **eliminar antes de la release**.

### 8.1 Test rápido — 3 notif a 20/40/60s

Dispara con la pantalla activa. Valida: permisos OK, canal creado, ícono OK, payload OK, `zonedSchedule` con `exactAllowWhileIdle` funciona a corto plazo.

```dart
final now = DateTime.now();
for (final t in [(99997, 20), (99998, 40), (99999, 60)]) {
  await NotificationService.schedule(
    id: t.$1, title: 'Prueba', body: 'Llega en ${t.$2}s',
    when: now.add(Duration(seconds: t.$2)),
  );
}
```

> Recordá: `_toTZ()` debe incluir segundos. Si trunca a minutos, los delays <60s caen al pasado.

### 8.2 Test realista — 1 notif a 10 min (componentes reales)

Construye el `DateTime` desde año/mes/día/hora/min/seg, mismo path que el scheduling real. Permite bloquear pantalla y entrar en Doze ligero.

```dart
final target = DateTime.now().add(const Duration(minutes: 10));
final scheduled = DateTime(
  target.year, target.month, target.day,
  target.hour, target.minute, target.second,
);
await NotificationService.schedule(
  id: 99996, title: 'Prueba real', body: 'Llega a las HH:mm',
  when: scheduled,
);
```

> **No es lo mismo** que la prueba de 60s. A 10 min podés bloquear la pantalla y validar entrega con el dispositivo idle.

### 8.3 Pruebas que NO podés automatizar

- **Doze profundo** (>1h pantalla apagada): programar para mañana 9 AM, dejar el celu apagado toda la noche.
- **Reboot**: programar a 10 min, reiniciar el celu, esperar.
- **Battery optimization de OEM**: validar con la app excluida y sin excluir.
- **Cambio de timezone**: programar, viajar (o cambiar zona manual), verificar que se ajusta.

---

## 9. Bugs silenciosos conocidos (checklist)

Estos errores **no lanzan excepciones visibles** — las notif simplemente no llegan o llegan a destiempo.

| # | Síntoma | Causa | Fix |
|---|---------|-------|-----|
| 1 | Notif a hora equivocada (offset UTC) | `tz.setLocalLocation()` no llamado | Llamar en `main()` con `flutter_timezone` antes de `runApp()` |
| 2 | Alarmas exactas no se disparan en Android 12+ | `requestExactAlarmsPermission()` no llamado | Pedir junto al toggle, después de POST_NOTIFICATIONS |
| 3 | Notif desaparecen post-reboot | `ScheduledNotificationBootReceiver` falta | Agregar los 3 receivers al manifest |
| 4 | Cuadrado gris en Android 5+ | Ícono con colores | PNG monocromo blanco + canal alpha |
| 5 | NullPointerException en Android | `requestPermissions()` antes de `initialize()` | Llamar siempre después de init |
| 6 | "no Activity" en Android | `initialize()` antes del primer frame | Mover dentro de `addPostFrameCallback` |
| 7 | Notif ignorada en silencio | `scheduledDate` en el pasado | Validar `> DateTime.now()` antes de schedule |
| 8 | Sistema falla en silencio (no permisos, no schedule) | `initialize()` retorna `null` en algunos devices | Usar `result != false` en vez de `result == true` (confirmado: Motorola G52 API 33) |
| 9 | Test de 20s/40s no llega | `_toTZDateTime` trunca a minutos | Incluir `t.second` en el TZDateTime |
| 10 | Release falla con `invalid_icon`, debug funciona | R8 + AAPT2 dropea drawable | `keep.xml` con `tools:keep="@drawable/ic_notification"` |
| 11 | Release: receivers eliminados por R8 | Falta keep rule | `-keep class com.dexterous.** { *; }` en proguard |
| 12 | Release: deserialización Gson falla | R8 ofusca atributos | `-keepattributes Signature, *Annotation*, InnerClasses, EnclosingMethod` |
| 13 | Toggle ON pero notif no llegan en API 33 | SharedPreferences `enabled=true` pero permiso del SO denegado | Verificar `areNotificationsEnabled()` al cargar pantalla; sincronizar si discrepa |
| 14 | Toggle OFF nunca vuelve a ON | Dialog runtime ya negado 2 veces | Usar `openAppSettings()` (permission_handler) + esperar resume |
| 15 | Permisos pedidos en cada arranque | `requestPermission()` en main.dart o en init de provider | Pedir SOLO desde el toggle de Settings, nunca en boot |
| 16 | Notif retrasadas/canceladas en Motorola/Xiaomi | Battery optimization activa | Pedir `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` opt-in |
| 17 | Android 14: alarmas exactas revocadas | User las desactivó desde Ajustes | Verificar `canScheduleExactAlarms()` antes de cada schedule, redirigir si false |

---

## 10. iOS — checklist específico

- `DarwinInitializationSettings` con `requestAlertPermission/Badge/Sound: true`.
- **Permisos**: `requestPermissions()` también funciona como query (no muestra dialog si ya fue decidido).
- **Foreground**: notif no se muestran. Si necesitás visualización in-app, manejar en `onDidReceiveNotificationResponse` o usar un overlay.
- **Cold start desde tap**: `getNotificationAppLaunchDetails()` igual que en Android.
- **Timezones**: `tz.local` funciona out-of-the-box si seguiste el setup de `main.dart`.
- **Sin receivers**: nada que tocar en `Info.plist` ni en el `AppDelegate.swift`.

---

## 11. Android 14+ — SCHEDULE_EXACT_ALARM revocable

En Android 14 (API 34), Google cambió la política:
- El usuario puede **revocar** `SCHEDULE_EXACT_ALARM` desde Ajustes en cualquier momento.
- Si está revocado, `zonedSchedule()` lanza `SecurityException` (capturada por el try-catch → silenciosa).
- **Workaround**: antes de cada schedule masivo (al activar toggle, al editar item), verificar:

```dart
if (!await NotificationService.canScheduleExactAlarms()) {
  await NotificationService.requestExactAlarmPermission();   // abre Ajustes
  return;
}
```

---

## 12. Techo de fiabilidad — qué NO hacer

Si después de aplicar todo lo anterior los avisos **igual fallan en Doze profundo en OEMs agresivos** (Motorola/Xiaomi/Huawei con pantalla apagada >1h), **NO escalar** a estas opciones salvo que la app sea efectivamente una alarma crítica:

| Opción | Por qué NO | Cuándo SÍ |
|--------|------------|-----------|
| **`AndroidScheduleMode.alarmClock`** | Muestra ícono de alarma persistente en status bar. Riesgo de rechazo en Play Store por uso fuera de scope. | App reloj/alarma real. |
| **Workmanager con periodic task** | Inestable en OEMs agresivos (en QueHacemos: semanas peleando, nunca funcionó confiablemente). Latencia (no entrega exacta). | Tareas tolerantes a ventana de horas. |
| **FCM (push notifications)** | Requiere backend, login, base de datos, cron. Mantenimiento + costo. | App con cuenta de usuario y servidor propio. |

**Decisión recomendada para apps de recordatorios no críticos:** aceptar que en OEMs muy agresivos puede fallar ocasionalmente. Documentarlo como limitación conocida. Pelear más allá empeora la UX (ícono persistente) o agrega complejidad infra que no se justifica.

---

## 13. Checklist de QA antes de release

### Funcional
- [ ] Toggle OFF → ON pide permisos en orden: notif → exact alarms → (battery optim opcional).
- [ ] Toggle OFF → ON cuando ya negaste el dialog 2 veces: abre Ajustes de la app.
- [ ] Toggle ON → OFF cancela todas las notif programadas.
- [ ] Crear item con fecha → schedule automático.
- [ ] Editar fecha del item → cancel + reschedule.
- [ ] Eliminar item → cancel.
- [ ] Tap en notificación con app cerrada → cold start abre el detalle correcto.
- [ ] Tap en notificación con app en background → warm start abre el detalle correcto.
- [ ] iOS: tap en notificación con app en foreground → manejado.

### Robustez
- [ ] Test de 60s con pantalla activa: 3 notif llegan.
- [ ] Test de 10 min con pantalla bloqueada: notif llega a la hora exacta.
- [ ] Reboot: programar a 10 min, reiniciar, llega.
- [ ] Doze profundo: programar para 9 AM mañana, pantalla apagada toda la noche, llega.
- [ ] Cambio de timezone manual: notif programada se ajusta.

### Build
- [ ] `flutter build apk --release` funciona en device real (no solo debug).
- [ ] `keep.xml` presente en `res/raw/`.
- [ ] `proguard-rules.pro` con `-keep com.dexterous` y los 4 `-keepattributes`.
- [ ] Botones de prueba **eliminados** del código de producción.

### Edge cases
- [ ] App en API 33+ con `enabled=true` en prefs pero permiso del SO denegado: estado se sincroniza al cargar Settings.
- [ ] App en Android 14: `canScheduleExactAlarms()` se chequea antes del scheduling.
- [ ] Item con fecha en el pasado: no se programa nada, no crashea.
- [ ] Misma fecha programada 2 veces (race condition): UNIQUE constraint o `cancel + schedule` previene duplicado.

---

## 13.5 Lecciones de producción real

> Esta sección documenta **bugs silenciosos detectados en una app vivida en Play Store + App Store** (repo4 `QueHacemosClean`). No son hipotéticos. Cada uno se confirmó leyendo el código publicado. El manual ya incluye los fixes — esta sección existe para que veas la diferencia entre "lo que se shippea" y "lo que conviene shippear".

### Caso 1 — `flutter_timezone` ausente, notif en UTC

**En el código publicado:**
- `pubspec.yaml` de repo4: NO incluye `flutter_timezone`.
- `main.dart:57`: solo `tz.initializeTimeZones()`. NO hay `setLocalLocation()`.

**Consecuencia:** `tz.local` queda como UTC. Para usuarios con device en zona "automática" suele andar (Android setea bien). Para usuarios en zona manual mal configurada o devices con IMEI raros (Codemagic emulators, custom ROMs), las notif se programan **3 horas tarde en Argentina**.

**Por qué nadie lo nota:** la mayoría de los devices reportan zona local correcta a través de los APIs nativos que usa `timezone_data`. Solo falla en el long tail.

**Fix (presente en este manual y en EscanDoc):** §4 obliga `FlutterTimezone.getLocalTimezone()` + `tz.setLocalLocation()`.

---

### Caso 2 — `success == true` mata `_initialized` en algunos OEMs

**En el código publicado** (`notification_service.dart:44`):

```dart
final success = await _notifications.initialize(/*...*/);
if (success == true) {              // ← weak null check
  _initialized = true;
}
```

**Consecuencia:** en algunos devices (confirmado: Motorola G52 API 33 en EscanDoc), `initialize()` retorna **`null`** en vez de `true`. La condición `== true` trata `null` como `false`. El servicio queda con `_initialized = false`, todos los métodos siguientes hacen `if (!_initialized) return;` y nunca falla visiblemente. **Las notif simplemente nunca llegan.**

**Por qué nadie lo nota:** Motorola/Xiaomi/Huawei son <30% del mercado en USA pero >70% en Latam. Si tu QA es solo Pixel/Samsung, no lo ves.

**Fix (presente en este manual y en EscanDoc):** usar `success != false` (línea 55 de `lib/core/services/notification_service.dart` en EscanDoc).

---

### Caso 3 — `canScheduleExactAlarms()` nunca se chequea

**En el código publicado:**
- `AndroidManifest.xml` declara `SCHEDULE_EXACT_ALARM`.
- Pero **NO hay una sola llamada** a `canScheduleExactAlarms()` ni a `requestExactAlarmsPermission()` en todo `lib/`.

**Consecuencia:** en Android 14+ el usuario puede revocar el permiso desde Ajustes en cualquier momento. El siguiente `zonedSchedule()` lanza `SecurityException`, que el try/catch del servicio se traga en silencio. **Las notif nuevas nunca se programan, las viejas tal vez sí, sin warning al usuario.**

**Por qué nadie lo nota:** el escenario "user revoca exact alarms manualmente" es raro. Pero el SO también puede degradarlo automáticamente si la app está mucho tiempo sin uso. Y en Android 15+ el comportamiento se vuelve más agresivo.

**Fix (presente en este manual y en EscanDoc):** `canScheduleExactAlarms()` se chequea **3 veces** en EscanDoc (`settings_page.dart:110, 135, 150`) — al activar el toggle, al reanudar tras volver de Ajustes del sistema, antes de finalizar.

---

### Lectura recomendada

Estos 3 bugs son **invisibles**: no rompen el build, no aparecen en Crashlytics, no generan reseñas malas (el usuario simplemente cree que se olvidó del recordatorio). Se descubren cuando un beta tester específico reporta "no me llega" y rompés cabeza por una semana.

Si tu app va a vivir en Latam (Motorola/Xiaomi mayoritarios), **bajá los 3 fixes desde el día 1**. Tienen costo cero en código y eliminan toda esta clase de fallas.

---

## 14. Referencias de código

### EscanDoc (Patrón A — uno por documento)
- `lib/core/services/notification_service.dart` — servicio core
- `lib/core/services/notification_prompt_service.dart` — flag `notif_enabled` + contador de intentos del modal
- `lib/core/widgets/notification_permission_dialog.dart` — modal explicativo
- `lib/features/settings/presentation/pages/settings_page.dart` — toggle + flujo de 5 pasos
- `lib/features/documents/presentation/providers/documents_provider.dart` — `enableNotifications()` / `disableNotifications()` / hook `_syncNotification()` en update
- `android/app/src/main/AndroidManifest.xml` — permisos + 3 receivers
- `android/app/src/main/res/raw/keep.xml` — fix release
- `android/app/proguard-rules.pro` — keep rules

### QueHacemos (Patrón B — agrupado por fecha)
- `lib/src/services/notification_service.dart` — core + `calculateOptimalTime()` + `generateDynamicMessage()`
- `lib/src/providers/favorites_provider.dart` — debounce + `_handleScheduledNotifications()`
- `lib/src/data/repositories/event_repository.dart` — CRUD de `notifications_programadas`
- `lib/src/data/database/database_helper.dart` — schema + migración
- `lib/src/services/notification_config_service.dart` — setup multi-paso

---

## 15. Resumen ejecutivo (TL;DR)

1. **Stack**: `flutter_local_notifications` + `timezone` + `flutter_timezone` + `permission_handler`.
2. **Setup Android**: 5 permisos (incl. `IGNORE_BATTERY_OPTIMIZATIONS`), 3 receivers, ícono monocromo en 5 densidades, `keep.xml` + 4 `-keepattributes` para release.
3. **Init**: `tz.initializeTimeZones()` + `setLocalLocation()` en `main()` antes de `runApp()`. `initialize()` en `addPostFrameCallback`. **NO** pedir permisos en init.
4. **Toggle**: 5 pasos en orden (init → POST_NOTIFICATIONS → settings si negado → exact alarms → battery optim opcional → finalize). `WidgetsBindingObserver` para retomar tras volver de Ajustes.
5. **Schedule**: `zonedSchedule` con `exactAllowWhileIdle`. `_toTZDateTime` con segundos. Validar `when > now`.
6. **Pattern A** (EscanDoc): N notif por item con IDs derivados. **Pattern B** (QueHacemos): 1 notif agrupada por fecha con tabla de tracking + JSON array.
7. **Bugs silenciosos**: 17 documentados en sección 9. El más sutil: `initialize()` retorna `null` en algunos OEMs → usar `!= false`.
8. **Techo**: si Doze profundo igual mata avisos en OEMs agresivos, aceptar la limitación. NO ir a alarmClock/Workmanager/FCM salvo app crítica.



