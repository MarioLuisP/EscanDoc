# Sistema de Notificaciones Locales

## Descripción General

Sistema completo de notificaciones locales programadas basado en **favoritos**, con scheduling inteligente, permisos multi-plataforma (Android 13+, iOS), gestión de clock alarms exactas, y tabla SQLite dedicada. Las notificaciones se programan a las **11 AM** (por defecto) o **1 hora antes** del evento más temprano del día.

**Características principales**:
- ✅ Notificaciones programadas con `zonedSchedule` (exactas, no approximate)
- ✅ Permisos SCHEDULE_EXACT_ALARM en Android 12+
- ✅ Tabla SQLite `notifications_programadas` con JSON arrays de event codes
- ✅ Scheduling dinámico: 11 AM default, 1h antes si evento temprano, mínimo 7 AM
- ✅ Mensajes personalizados: 1 evento, 2 eventos ("doble planazo"), 3+ ("maratón cultural")
- ✅ Persistencia cross-reboot con BootReceiver
- ✅ Badges de app icon (iOS + Android)
- ✅ Deep linking al tap en notificación

---

## Arquitectura del Sistema

```
┌────────────────────────────────────────────────────────────┐
│                  NOTIFICATION SERVICE                      │
│  (flutter_local_notifications + timezone)                 │
│  - initialize() → permisos + channels                     │
│  - scheduleNotification() → zonedSchedule exacta          │
│  - calculateOptimalTime() → 11 AM o 1h antes              │
│  - generateDynamicMessage() → mensajes personalizados     │
└───────────────────┬────────────────────────────────────────┘
                    │
                    ▼
┌────────────────────────────────────────────────────────────┐
│               FAVORITES PROVIDER                           │
│  (Trigger de scheduling al toggle favorito)               │
│  - toggleFavorite() → debounce 300ms                      │
│  - _handleScheduledNotifications() → CRUD de tabla        │
│  - _createScheduledNotificationWithCodes()                │
│  - _updateScheduledNotificationWithCodes()                │
│  - _cancelScheduledNotificationForDate()                  │
└───────────────────┬────────────────────────────────────────┘
                    │
                    ▼
┌────────────────────────────────────────────────────────────┐
│                EVENT REPOSITORY                            │
│  (CRUD de tabla notifications_programadas)                │
│  - insertScheduledNotification()                          │
│  - updateScheduledNotification()                          │
│  - getScheduledNotificationByDate()                       │
│  - deleteScheduledNotificationByDate()                    │
└───────────────────┬────────────────────────────────────────┘
                    │
                    ▼
┌────────────────────────────────────────────────────────────┐
│          TABLA: notifications_programadas                  │
│  Schema:                                                   │
│  - id (PK autoincrement)                                   │
│  - fecha (DATE, indexed)                                   │
│  - notification_id (INTEGER unique) → hash de fecha        │
│  - event_codes (TEXT) → JSON: ["EVT001", "EVT002"]         │
│  - hora_programada (TIME) → "11:00", "09:30"               │
│  - created_at (TIMESTAMP)                                  │
│                                                            │
│  Índices:                                                  │
│  - idx_notif_prog_fecha (fecha)                            │
│  - idx_notif_prog_fecha_id (fecha, notification_id)        │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│           ANDROID MANIFEST RECEIVERS                       │
│  - ScheduledNotificationReceiver (ejecuta notif)          │
│  - ScheduledNotificationBootReceiver (post-reboot)        │
│  - FlutterLocalNotificationsReceiver (tap handling)       │
└────────────────────────────────────────────────────────────┘
```

---

## Componentes Principales

### 1. NotificationService
**Archivo**: `lib/src/services/notification_service.dart`

Servicio core que encapsula toda la lógica de `flutter_local_notifications`.

#### Inicialización

**initialize()** (líneas 23-58)
- Singleton pattern: `_initialized` flag
- Android settings: `@drawable/ic_notification` como icono
- iOS (Darwin): Request de permisos de alert, badge, sound
- `onDidReceiveNotificationResponse`: Callback para tap (línea 41)
  - Extrae `event_code` del payload con regex
  - Guarda en UserPreferences.setPendingEventCode() para apertura del modal
- Cleanup de badge si es nuevo día (línea 45)
- Retorna bool success

**Channels configurados**:
1. **"general"**: Notificaciones generales (Importance.high)
2. **"fcm_messages"**: FCM foreground (líneas 134-141)
3. **"reminders"**: Recordatorios de favoritos (líneas 186-193)

#### Scheduling de Notificaciones

**scheduleNotification()** (líneas 167-217)
- **Parámetros**:
  - `id`: int (generado con `generateNotificationId(fecha)`)
  - `title`: String
  - `message`: String (dinámico con `generateDynamicMessage()`)
  - `scheduledDate`: DateTime (calculado con `calculateOptimalTime()`)
  - `payload`: String? (formato: "daily_reminder:YYYY-MM-DD")

- **Channel**: "reminders" (orange icon, high importance)
- **Método clave**: `zonedSchedule()` (líneas 204-212)
  - Convierte DateTime a TZDateTime con `tz.local`
  - `androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle`
    - **exactAllowWhileIdle**: Permite alarmas exactas incluso en Doze mode
    - Requiere permiso `SCHEDULE_EXACT_ALARM` en manifest
  - iOS: scheduling exacto nativo

**Por qué exact alarm**:
- `exact` → notificación a la hora precisa (no +/- 15 min)
- `allowWhileIdle` → funciona incluso si device en low-power mode
- Android 12+ restringió exact alarms, requiere declarar permiso

#### Cálculo de Horario Óptimo

**calculateOptimalTime()** (líneas 232-277)
- **Input**: `fecha` (String YYYY-MM-DD), `events` (List de Maps con full event data)
- **Output**: DateTime con hora óptima de notificación

**Algoritmo**:
```dart
1. Parsear fecha target
2. Si no hay eventos → default 11:00 AM

3. Buscar evento más temprano del día:
   - Iterar events
   - Parsear event['date'] (DateTime completo con hora)
   - Trackear earliestEvent

4. Si no hay earliestEvent válido → 11:00 AM

5. Si earliestEvent.hour >= 12:
   → Evento después del mediodía
   → Notificar 11:00 AM (dar tiempo para planear)

6. Si earliestEvent.hour < 12:
   → Evento en la mañana
   → Calcular oneHourBefore = earliestEvent - 1h

   Aplicar límites:
   - minTime = 07:00 AM (no despertar muy temprano)
   - maxTime = 11:00 AM (cap superior)

   Si oneHourBefore < 07:00 → return 07:00
   Si oneHourBefore > 11:00 → return 11:00
   Sino → return oneHourBefore
```

**Ejemplos concretos**:
- Evento a las 14:00 → Notificación a las 11:00
- Evento a las 09:00 → Notificación a las 08:00 (1h antes)
- Evento a las 07:30 → Notificación a las 07:00 (cap mínimo)
- Evento a las 20:00 → Notificación a las 11:00
- Múltiples eventos (10:00, 15:00, 21:00) → Busca el más temprano (10:00) → 09:00

**Ventaja**: Adaptación inteligente según el horario de eventos del usuario.

#### Generación de Mensajes Dinámicos

**generateDynamicMessage()** (líneas 297-329)
- **Input**: List de eventos ordenados por hora
- **Output**: String formateado según cantidad

**3 formatos**:

1. **1 evento**:
   ```
   ✨ No te lo pierdas
   [Título del evento] ⏰ [Hora]hs
   ```
   Ejemplo: "✨ No te lo pierdas\nStandup de Matías Valdez ⏰ 21hs"

2. **2 eventos**:
   ```
   🥂 Doble planazo
   ⏰ [Hora1]hs ✨ [Título1] y ⏰ [Hora2]hs ✨ [Título2]
   ```
   Ejemplo: "🥂 Doble planazo\n⏰ 19hs ✨ Jazz en el Cabildo y ⏰ 22hs ✨ Teatro La Cochera"

3. **3+ eventos**:
   ```
   🚀 Maratón cultural
   ✨ Desde las ⏰ [HoraPrimero]: ✨ [Título1], [Título2] y [N] más
   ```
   Ejemplo: "🚀 Maratón cultural\n✨ Desde las ⏰ 18hs: ✨ Feria Artesanal, Cine en el Paseo y 3 más"

**Formato de hora** (`_formatEventTime()`, líneas 332-349):
- Si minute == 0: "21hs"
- Si minute != 0: "21:30hs"

#### Utilidades

**generateNotificationId()** (líneas 386-388)
- Input: "2025-01-20"
- Output: hashCode de "daily_2025-01-20" (int único)
- Consistente: misma fecha → mismo ID

**shouldScheduleNotification()** (líneas 391-404)
- Retorna false si:
  - Fecha es pasada
  - Es hoy y ya pasaron las 11 AM
- Evita programar notificaciones inútiles

**formatTimeForDatabase()** (líneas 280-282)
- DateTime → "HH:MM" (formato de 24h con padding)
- Ejemplo: DateTime(2025, 1, 20, 9, 5) → "09:05"

**parseTimeFromDatabase()** (líneas 285-292)
- "HH:MM" → DateTime de hoy (o fecha especificada)
- Usado para reconstruir scheduledDate desde DB

#### Badge Management

**setBadge()** (líneas 354-361)
- Activa badge numérico en app icon (muestra "1")
- Llama a `AppBadgePlus.updateBadge(1)`
- Cleanup previo con `_cleanupBadgeIfNewDay()`

**clearBadge()** (líneas 364-370)
- Limpia badge (muestra nada)
- `AppBadgePlus.updateBadge(0)`
- Llamado al abrir app (main.dart:262)

---

### 2. FavoritesProvider
**Archivo**: `lib/src/providers/favorites_provider.dart`

ChangeNotifier que coordina favoritos y notificaciones programadas.

#### Trigger de Scheduling

**toggleFavorite()** → (ya documentado en db_cache.md)
- Al final del debounce (300ms), llama a `_handleScheduledNotifications()` (líneas 158-193)

**_handleScheduledNotifications()** (líneas 158-193)
- **Input**: `eventCode`, `wasAdded` (bool), `fecha` (String)
- **Lógica**:
  1. Verificar si fecha requiere scheduling con `shouldScheduleNotification()`
  2. Query de DB: `getScheduledNotificationByDate(fecha)`
  3. **Si existe notificación programada**:
     - Parsear `event_codes` actuales (JSON array)
     - Si `wasAdded`: agregar code a array
     - Si `!wasAdded`: remover code de array
     - Si array queda vacío: cancelar notificación y delete de DB
     - Si array tiene elementos: update con nuevos codes
  4. **Si NO existe notificación**:
     - Si `wasAdded`: crear nueva notificación con `[eventCode]`

**Ventaja**: Una notificación por fecha, agrupa múltiples favoritos.

#### CRUD de Notificaciones Programadas

**_createScheduledNotificationWithCodes()** (líneas 195-219)
```dart
1. Fetch full events con getEventsByCodes(eventCodes)
2. Calcular horario óptimo: calculateOptimalTime(fecha, events)
3. Formatear hora para DB: formatTimeForDatabase(optimalTime)
4. Generar ID único: generateNotificationId(fecha)
5. Programar notificación local con _scheduleLocalNotification()
6. Insertar en DB con insertScheduledNotification()
```

**_updateScheduledNotificationWithCodes()** (líneas 221-244)
```dart
1. Fetch events actualizados
2. Recalcular horario óptimo (puede cambiar si eventos diferentes)
3. Generar NUEVO notification ID (hash diferente si fecha/eventos cambiaron)
4. Cancelar notificación vieja con cancelNotification(oldNotificationId)
5. Programar nueva notificación
6. Update en DB con updateScheduledNotification()
```

**_scheduleLocalNotification()** (líneas 246-261)
- Genera mensaje dinámico con `generateDynamicMessage(events)`
- Title hardcoded: "❤️ Favoritos de hoy ⭐"
- Payload: "daily_reminder:YYYY-MM-DD"
- Llama a `NotificationService.scheduleNotification()`

**_cancelScheduledNotificationForDate()** (líneas 263-273)
- Query de DB para obtener `notification_id`
- Cancelar con `NotificationService.cancelNotification(id)`
- Delete de DB con `deleteScheduledNotificationByDate(fecha)`

---

### 3. EventRepository
**Archivo**: `lib/src/data/repositories/event_repository.dart`

Acceso a tabla `notifications_programadas`.

#### Métodos de Tabla

**getScheduledNotificationByDate()** (líneas 381-392)
```dart
final results = await db.query(
  'notifications_programadas',
  where: 'fecha = ?',
  whereArgs: [fecha],
);
return results.isNotEmpty ? results.first : null;
```
Retorna Map con:
- `id`, `fecha`, `notification_id`, `event_codes` (JSON string), `hora_programada`, `created_at`

**insertScheduledNotification()** (líneas 393-416)
```dart
await db.insert(
  'notifications_programadas',
  {
    'fecha': fecha,
    'notification_id': notificationId,
    'event_codes': jsonEncode(eventCodes), // ["EVT001", "EVT002"]
    'hora_programada': horaProgramada,     // "11:00"
  },
  conflictAlgorithm: ConflictAlgorithm.replace,
);
```

**updateScheduledNotification()** (líneas 417-440)
```dart
await db.update(
  'notifications_programadas',
  {
    'notification_id': notificationId,
    'event_codes': jsonEncode(eventCodes),
    'hora_programada': horaProgramada,
  },
  where: 'fecha = ?',
  whereArgs: [fecha],
);
```

**deleteScheduledNotificationByDate()** (líneas 441-448)
```dart
await db.delete(
  'notifications_programadas',
  where: 'fecha = ?',
  whereArgs: [fecha],
);
```

**parseEventCodes()** (helper, probablemente en repository)
- JSON string → List<String>
- Ejemplo: '["EVT001", "EVT002"]' → ["EVT001", "EVT002"]

---

### 4. DatabaseHelper - Tabla Schema
**Archivo**: `lib/src/data/database/database_helper.dart`

#### Tabla: notifications_programadas

**Creación** (líneas 103-111):
```sql
CREATE TABLE notifications_programadas (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  fecha DATE NOT NULL,
  notification_id INTEGER NOT NULL UNIQUE,
  event_codes TEXT NOT NULL,  -- JSON array: ["EVT001", "EVT002"]
  hora_programada TIME NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
```

**Índices** (líneas 146-147):
```sql
CREATE INDEX idx_notif_prog_fecha
  ON notifications_programadas(fecha);

CREATE INDEX idx_notif_prog_fecha_id
  ON notifications_programadas(fecha, notification_id);
```

**Columnas**:
- `id`: PK autoincrement (interno, no usado fuera de DB)
- `fecha`: DATE formato "YYYY-MM-DD" (indexed)
- `notification_id`: INTEGER único (hashCode de "daily_YYYY-MM-DD")
  - Usado para cancelar notificación exacta
  - UNIQUE constraint previene duplicados
- `event_codes`: TEXT con JSON array de códigos
  - Ejemplo: '["MUS2025001", "TEA2025045", "CIN2025023"]'
  - Almacena todos los favoritos de esa fecha en una sola row
- `hora_programada`: TIME formato "HH:MM"
  - Ejemplo: "11:00", "09:30", "07:00"
  - Calculado dinámicamente con `calculateOptimalTime()`
- `created_at`: TIMESTAMP automático

**Migración v1→v2** (líneas 151-177):
- Si oldVersion < 2: crea tabla `notifications_programadas`
- Apps existentes migran automáticamente al actualizar

**Nota**: Hay otra tabla `notifications` (líneas 88-99) para notificaciones in-app (bell icon), NO para notificaciones programadas locales.

---

### 5. NotificationConfigurationService
**Archivo**: `lib/src/services/notification_config_service.dart`

Servicio de configuración inicial one-time con flujo multi-paso.

#### Flujo de Configuración

**configureNotifications()** (líneas 25-70)
```
1. Check permisos existentes (FCM)
2. Si authorized → proceder directo a setup
3. Si NO:
   - Android 13+: requestAndroidPermissions() (flutter_local_notifications)
   - Android <13: requestFCMPermissions() (Firebase)
   - iOS: requestFCMPermissions() (Firebase)
4. _proceedWithSetup():
   a. _initializeNotificationService() → NotificationService.initialize()
   b. _configureNotificationManager() → NotificationManager.initialize()
   c. _saveNotificationState() → UserPreferences.setNotificationsReady(true)
   d. _initializeFCM() → subscribeToTopic('eventos_cordoba')
5. Return NotificationConfigState (success/error)
```

**Estados** (enum NotificationConfigState, líneas 8-20):
- `idle`, `detectingPlatform`, `requestingPermissions`
- `initializingService`, `configuringWorkManager`, `savingPreferences`
- `success`
- `errorPermissionDenied`, `errorInitializationFailed`, `errorWorkManagerFailed`, `errorUnknown`

#### Permisos Android 13+

**_requestAndroidPermissions()** (líneas 116-136)
```dart
final android = NotificationService.resolveAndroid();
final permissionGranted = await android.requestNotificationsPermission();
```
- Android 13 (API 33) introdujo permiso runtime `POST_NOTIFICATIONS`
- `requestNotificationsPermission()` muestra system dialog
- Si granted → continuar setup
- Si denied → errorPermissionDenied

#### Persistencia de Estado

**_saveNotificationState()** (líneas 163-178)
- Guarda `notifications_ready: true` en SharedPreferences
- Verificación double-check (línea 168)
- Flag usado en `main.dart:135` para inicializar NotificationService solo si configurado

**isAlreadyConfigured()** (líneas 222-229)
- Query de UserPreferences.getNotificationsReady()
- Usado en UI de Settings para mostrar estado actual

**disableNotifications()** (líneas 231-234)
- Set `notifications_ready: false`
- NO cancela notificaciones programadas existentes (requiere llamar a `cancelAllNotifications()`)

---

### 6. Android Manifest - Permisos y Receivers
**Archivo**: `android/app/src/main/AndroidManifest.xml`

#### Permisos Declarados (líneas 4-10)

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.VIBRATE"/>
```

**Clave para notificaciones locales**:
- **POST_NOTIFICATIONS**: Android 13+ runtime permission para mostrar notificaciones
- **SCHEDULE_EXACT_ALARM**: Android 12+ para `exactAllowWhileIdle` scheduling
  - Sin este permiso: alarmas serían approximate (±15 min)
  - User DEBE otorgar desde Settings si Android 14+ (no runtime dialog)
- **RECEIVE_BOOT_COMPLETED**: Permite que BootReceiver restaure notificaciones post-reboot
- **VIBRATE**: Vibración al recibir notificación (opcional)

#### Receivers (líneas 37-51)

**ScheduledNotificationReceiver** (líneas 37-38)
```xml
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
```
- Receiver que ejecuta notificación programada a la hora exacta
- `exported="false"`: Solo app puede triggerearlo (seguridad)

**ScheduledNotificationBootReceiver** (líneas 40-48)
```xml
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
        <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
    </intent-filter>
</receiver>
```
- **BOOT_COMPLETED**: Re-programa notificaciones después de reinicio del device
- **MY_PACKAGE_REPLACED**: Re-programa después de actualizar app
- **QUICKBOOT_POWERON**: Soporte para quick boot (algunos vendors)

**Por qué es necesario**:
- Android cancela todas las alarmas exactas al reiniciar
- BootReceiver lee notificaciones de DB y las re-programa
- **CRÍTICO**: Sin esto, notificaciones desaparecen post-reboot

**FlutterLocalNotificationsReceiver** (líneas 50-51)
```xml
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsReceiver"/>
```
- Receiver para handling de tap en notificación
- Triggerea callback `onDidReceiveNotificationResponse` (notification_service.dart:60)

---

## Flujos Completos

### A. Primera Configuración (one-time setup)

```
┌───────────────────┐
│ User tap toggle   │
│ "Notificaciones"  │
│ en Settings       │
└────────┬──────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│ NotificationCard (UI)                       │
│ - Llama configureNotifications()            │
└────────┬────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│ NotificationConfigurationService            │
│ Step 1: Check permisos FCM                  │
│ - getNotificationSettings()                 │
│ - Si authorized → skip request              │
└────────┬────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│ Step 2: Request permisos (si necesario)     │
│                                             │
│ Android 13+:                                │
│ - requestNotificationsPermission()          │
│   → System dialog "Allow notifications?"    │
│                                             │
│ Android <13 / iOS:                          │
│ - FirebaseMessaging.requestPermission()     │
│   → System dialog                           │
└────────┬────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│ Step 3: Initialize NotificationService      │
│ - FlutterLocalNotificationsPlugin.init()   │
│ - Configura channels (general, fcm, remind) │
│ - Register callback onDidReceiveResponse    │
└────────┬────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│ Step 4: Initialize NotificationManager      │
│ - Setup FCM handlers (onMessage, etc.)      │
│ - subscribeToTopic('eventos_cordoba')       │
└────────┬────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│ Step 5: Save state                          │
│ - setNotificationsReady(true)               │
│ - Persiste en SharedPreferences             │
└────────┬────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│ SUCCESS                                     │
│ - UI muestra switch ON                      │
│ - Notificaciones habilitadas                │
└─────────────────────────────────────────────┘
```

**Timing típico**: ~2-5 segundos (incluye interacción del usuario con dialogs)

---

### B. Toggle de Favorito → Scheduling de Notificación

```
┌──────────────┐
│ User tap ❤️  │
│ en tarjeta   │
└──────┬───────┘
       │
       ▼
┌──────────────────────────────────────────┐
│ FavoritesProvider.toggleFavorite()       │
│ - _favoriteIds.add(eventId)              │
│ - DB update (favorite = 1)               │
│ - Debounce timer inicia (300ms)          │
└──────┬───────────────────────────────────┘
       │
       ▼ (después de 300ms sin más cambios)
┌──────────────────────────────────────────┐
│ _handleScheduledNotifications()          │
│ - Extract fecha del eventId              │
│ - shouldScheduleNotification(fecha)?     │
│   → Si es pasada o >11AM hoy: skip       │
└──────┬───────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────┐
│ Query DB: getScheduledNotificationByDate│
│ - SELECT * FROM notifications_programadas│
│   WHERE fecha = '2025-01-20'             │
└──────┬───────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────┐
│ CASO A: NO existe notificación           │
│ → Crear nueva                            │
│                                          │
│ 1. _createScheduledNotificationWithCodes │
│    - eventCodes = ["MUS2025001"]         │
│    - Fetch full events de DB             │
│    - calculateOptimalTime(fecha, events) │
│      → Ejemplo: evento a 21hs → 11:00 AM │
│                                          │
│ 2. generateDynamicMessage(events)        │
│    → "✨ No te lo pierdas                │
│       Jazz en el Cabildo ⏰ 21hs"        │
│                                          │
│ 3. scheduleNotification()                │
│    - id = "daily_2025-01-20".hashCode    │
│    - title = "❤️ Favoritos de hoy ⭐"    │
│    - message = [mensaje dinámico]        │
│    - scheduledDate = 2025-01-20 11:00:00 │
│    - zonedSchedule() → SO programa alarm │
│                                          │
│ 4. insertScheduledNotification()         │
│    - INSERT INTO notifications_programadas│
│      (fecha, notification_id, event_codes,│
│       hora_programada)                   │
│    - Values: ('2025-01-20', 123456,      │
│               '["MUS2025001"]', '11:00') │
└──────┬───────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────┐
│ RESULTADO                                │
│ - Notificación programada para mañana 11 AM│
│ - DB tiene registro de la notificación  │
│ - BootReceiver puede restaurarla        │
└──────────────────────────────────────────┘
```

---

### C. Agregar Segundo Favorito a Misma Fecha (Update)

```
┌──────────────────┐
│ User marca 2º ❤️ │
│ mismo día        │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│ toggleFavorite() → debounce 300ms        │
└────────┬─────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│ _handleScheduledNotifications()          │
│ - Query: getScheduledNotificationByDate  │
│ - Result: notification exists            │
│   current_codes = ["MUS2025001"]         │
└────────┬─────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│ CASO B: Existe notificación              │
│ → Update con nuevos codes                │
│                                          │
│ 1. Agregar nuevo code al array           │
│    - eventCodes = ["MUS2025001", "TEA..."]│
│                                          │
│ 2. _updateScheduledNotificationWithCodes │
│    - Fetch events actualizados           │
│    - RE-CALCULAR optimalTime             │
│      → Ejemplo: evento nuevo a 19hs      │
│      → Más temprano que 21hs             │
│      → Nueva hora: 18:00 (1h antes)      │
│                                          │
│ 3. Cancelar notificación vieja           │
│    - cancelNotification(oldId)           │
│                                          │
│ 4. Programar nueva con nuevo horario     │
│    - scheduleNotification(newId, 18:00)  │
│    - Mensaje actualizado:                │
│      "🥂 Doble planazo                   │
│       ⏰ 19hs ✨ Teatro + ⏰ 21hs ✨ Jazz" │
│                                          │
│ 5. UPDATE en DB                          │
│    - notification_id = newId             │
│    - event_codes = '["MUS...", "TEA..."]'│
│    - hora_programada = '18:00'           │
└────────┬─────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│ RESULTADO                                │
│ - Notificación RE-PROGRAMADA para 18:00 │
│ - Mensaje ahora menciona 2 eventos      │
│ - Horario adaptado al evento más temprano│
└──────────────────────────────────────────┘
```

**Ventaja**: Horario se adapta dinámicamente según favoritos agregados/removidos.

---

### D. Remover Favorito (Cancel si último)

```
┌──────────────────┐
│ User untap ❤️    │
│ (único fav del   │
│  día)            │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│ toggleFavorite() → debounce              │
└────────┬─────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│ _handleScheduledNotifications()          │
│ - wasAdded = false                       │
│ - Query notification existente           │
│ - current_codes = ["MUS2025001"]         │
│ - Remover code del array                 │
│ - Resultado: codes = [] (vacío!)         │
└────────┬─────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│ CASO C: Array vacío                      │
│ → Cancelar notificación completamente    │
│                                          │
│ 1. _cancelScheduledNotificationForDate() │
│    - Query notificationId de DB          │
│    - cancelNotification(id)              │
│      → SO cancela alarm programada       │
│                                          │
│ 2. deleteScheduledNotificationByDate()   │
│    - DELETE FROM notifications_programadas│
│      WHERE fecha = '2025-01-20'          │
└────────┬─────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│ RESULTADO                                │
│ - NO más notificación para esa fecha     │
│ - Registro eliminado de DB               │
│ - User NO recibirá notificación          │
└──────────────────────────────────────────┘
```

---

### E. Device Reboot → Restauración de Notificaciones

```
┌──────────────────┐
│ Device reinicia  │
│ (apagado/encendido)│
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│ Android BOOT_COMPLETED broadcast         │
└────────┬─────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│ ScheduledNotificationBootReceiver        │
│ (AndroidManifest.xml:40-48)              │
│ - Receiver automático de plugin          │
└────────┬─────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│ flutter_local_notifications (interno)    │
│ - Lee notificaciones de almacenamiento   │
│   interno del plugin                     │
│ - RE-PROGRAMA cada notificación          │
│   con AlarmManager                       │
└────────┬─────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│ RESULTADO                                │
│ - Todas las notificaciones restauradas   │
│ - Horarios preservados                   │
│ - User NO necesita reabrir app           │
└──────────────────────────────────────────┘
```

**Notas importantes**:
- Plugin `flutter_local_notifications` maneja persistencia internamente
- NO necesitamos código custom para restaurar post-reboot
- Tabla `notifications_programadas` es para nuestro tracking, NO para boot receiver
- Boot receiver usa almacenamiento interno del plugin (no accesible desde Dart)

---

### F. Tap en Notificación → Abrir Modal de Evento

```
┌──────────────────┐
│ Notificación     │
│ aparece a las    │
│ 11:00 AM         │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│ User tap en notificación                 │
└────────┬─────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│ _onNotificationTapped()                  │
│ (notification_service.dart:60-84)        │
│                                          │
│ 1. Recibe NotificationResponse           │
│    - payload = "daily_reminder:2025-01-20"│
│                                          │
│ 2. Extrae event_code con regex           │
│    - Payload puede contener event_code   │
│    - Regex: r'event_code:\s*([^,}]+)'    │
│                                          │
│ 3. Guarda en UserPreferences             │
│    - setPendingEventCode(eventCode)      │
└────────┬─────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│ App abre (o ya estaba abierta)           │
│ - main.dart detecta pendingEventCode     │
│   (líneas 265-271)                       │
│                                          │
│ - _openEventFromNotification(code)       │
│   (líneas 150-197)                       │
│   1. Buscar evento en cache              │
│   2. Fetch full data de DB               │
│   3. EventDetailModal.show()             │
│                                          │
│ - Limpia pendingEventCode                │
└────────┬─────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│ RESULTADO                                │
│ - Modal de detalle abierto               │
│ - User ve descripción completa           │
│ - Puede ver ubicación, precio, hora      │
└──────────────────────────────────────────┘
```

**Timing**: ~100-300ms desde tap hasta modal visible.

---

## Estructura de Datos

### Tabla: notifications_programadas

**Ejemplo de datos reales**:

```sql
-- User tiene 3 favoritos para 2025-01-20:
-- Evento 1: Teatro a las 19:00
-- Evento 2: Jazz a las 21:00
-- Evento 3: Standup a las 22:30

INSERT INTO notifications_programadas VALUES (
  1,                              -- id (autoincrement)
  '2025-01-20',                   -- fecha
  987654321,                      -- notification_id (hashCode)
  '["TEA2025045", "MUS2025001", "STA2025012"]',  -- event_codes (JSON)
  '18:00',                        -- hora_programada (1h antes de 19:00)
  '2025-01-19T15:30:00.000Z'      -- created_at
);
```

**Notificación programada para**:
- Fecha: 2025-01-20 18:00:00
- Mensaje: "🚀 Maratón cultural\n✨ Desde las ⏰ 19hs: ✨ Teatro La Cochera, Jazz en el Cabildo y 1 más"
- ID para cancelar: 987654321

### JSON en event_codes

**Formato**:
```json
["EVT001", "EVT002", "EVT003"]
```

**Ventajas**:
- Compacto (vs tabla relacional)
- Fácil de parsear con `jsonDecode()`
- UNIQUE constraint en `notification_id` previene duplicados por fecha
- Query rápida por fecha con índice

### SharedPreferences

**Clave**: `notifications_ready`
**Tipo**: bool
**Ubicación**: `lib/src/models/user_preferences.dart:76-82`

```dart
static Future<bool> getNotificationsReady() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('notifications_ready') ?? false;
}

static Future<void> setNotificationsReady(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('notifications_ready', value);
}
```

**Uso**: Flag que indica si NotificationService fue inicializado exitosamente.

---

## Canales de Notificación

### Canal: "reminders" (Favoritos)

**Android**:
```dart
AndroidNotificationDetails(
  'reminders',
  'Recordatorios de Eventos',
  channelDescription: 'Recordatorios de eventos favoritos',
  importance: Importance.high,
  priority: Priority.high,
  icon: '@drawable/ic_notification',
  color: Color(0xFFFF9800), // Orange
)
```

**Características**:
- Sound: Default notification sound
- Vibration: Default pattern
- LED: No configurado
- Heads-up: Sí (Importance.high)
- Lock screen: Visible
- Do Not Disturb: Respeta configuración del usuario

### Canal: "fcm_messages" (FCM foreground)

**Usado cuando**:
- App está en foreground
- FCM recibe notificación
- Se re-muestra como notificación local para visibilidad

### Canal: "general" (Otros)

**Usado para**:
- Notificaciones de sistema (sync completado, etc.)
- Feedback de favoritos agregados/removidos

---

## Optimizaciones

### 1. Debouncing de scheduling (300ms)
- FavoritesProvider usa debounce timer
- User puede marcar/desmarcar múltiples favoritos rápidamente
- Solo 1 query/update de DB al final
- **Ahorro**: ~90% menos DB writes en usage intensivo

### 2. Scheduling condicional
- `shouldScheduleNotification()` evita programar pasadas o muy cercanas
- **Ahorro**: 0 notificaciones inútiles, menos alarmas en SO

### 3. ID único por fecha (hashCode)
- `"daily_YYYY-MM-DD".hashCode` siempre da mismo int
- Fácil de cancelar sin consultar DB
- UNIQUE constraint previene duplicados automáticamente

### 4. JSON array en una sola row
- 1 row por fecha (vs tabla relacional M:N)
- Query O(1) con índice de fecha
- **Ahorro**: ~10x menos rows en DB

### 5. Re-cálculo de hora en cada update
- Horario se adapta al evento MÁS TEMPRANO actual
- Si user agrega/remueve favoritos, hora puede cambiar
- Garantiza notificación útil (no muy temprano, no muy tarde)

### 6. Mensajes dinámicos pre-generados
- Mensaje calculado al programar (no en tiempo de notificación)
- Incluye títulos y horarios específicos
- User ve información relevante sin abrir app

### 7. Persistencia automática post-reboot
- BootReceiver del plugin restaura notificaciones
- NO requiere código custom de nuestra parte
- **Ahorro**: Menos complejidad, más confiable

---

## Casos Edge y Manejo de Errores

### 1. User marca favorito a las 10:59 AM para hoy
- `shouldScheduleNotification("2025-01-20")` retorna false (>11 AM check futuro)
- NO se programa notificación
- User simplemente ve favorito en pestaña Favoritos

### 2. Evento sin hora (solo fecha)
- `calculateOptimalTime()` no puede parsear hora
- Fallback a 11:00 AM
- Mensaje muestra evento sin hora específica

### 3. Múltiples favoritos con horas mezcladas
- Ejemplo: 9:00, 15:00, 22:00
- Algoritmo busca más temprano (9:00)
- Notificación a las 8:00 (1h antes)
- Mensaje: "🚀 Maratón cultural\n✨ Desde las ⏰ 9hs: [título], [título] y 1 más"

### 4. User remueve penúltimo favorito (quedan 2 → 1)
- Update en DB con nuevo array: ["EVT001"]
- Re-schedule con nuevo horario (puede cambiar)
- Mensaje cambia de "🥂 Doble planazo" a "✨ No te lo pierdas"

### 5. Permission denied en Android 13+
- `configureNotifications()` retorna `errorPermissionDenied`
- UI muestra error al user
- User puede re-intentar (vuelve a pedir permiso)

### 6. SCHEDULE_EXACT_ALARM revocado (Android 14+)
- User puede revocar desde Settings del sistema
- `scheduleNotification()` lanza exception silenciosa
- Notificación NO se programa
- App sigue funcionando, solo falla scheduling
- **Solución**: Mostrar dialog pidiendo que habilite permiso

### 7. App actualizada (MY_PACKAGE_REPLACED)
- BootReceiver se ejecuta
- Notificaciones restauradas con nueva versión de app
- DB migra automáticamente si hay cambios de schema (v1→v2)

### 8. Device en Doze mode (batería baja)
- `exactAllowWhileIdle` permite alarma exacta incluso en Doze
- Notificación se muestra a la hora correcta
- Android puede retrasar ejecución de código no-critical, pero alarma se dispara

### 9. Timezone change (viaje a otra zona horaria)
- `tz.TZDateTime.from(scheduledDate, tz.local)` usa zona local
- Si device cambia timezone, notificación se ajusta automáticamente
- Ejemplo: Programado 11 AM Argentina → User viaja a Brasil → Se muestra 12 PM Brasil

### 10. Notificación duplicada (race condition)
- UNIQUE constraint en `notification_id` previene duplicados en DB
- Si 2 threads intentan insertar misma fecha, segundo falla
- `conflictAlgorithm: ConflictAlgorithm.replace` sobrescribe si existe

---

## Testing y Debugging

### Métodos de debugging disponibles

**FavoritesProvider.getDebugState()** (líneas 325-354)
```dart
final debugState = await favoritesProvider.getDebugState();
print(debugState);
```

**Output**:
```json
{
  "total_favorites": 12,
  "scheduled_notifications": 4,
  "scheduled_details": [
    {
      "fecha": "2025-01-20",
      "hora_programada": "11:00",
      "codes_count": 3,
      "codes": ["MUS001", "TEA045", "STA012"]
    },
    {
      "fecha": "2025-01-21",
      "hora_programada": "09:30",
      "codes_count": 1,
      "codes": ["CIN023"]
    }
  ],
  "favorites_by_date": {
    "2025-01-20": 3,
    "2025-01-21": 1,
    "2025-01-22": 5,
    "2025-01-25": 3
  }
}
```

**debug_helper.dart** (líneas 511-517)
- Test de notificaciones para hoy y mañana
- Muestra horario programado y favoritos

### Escenarios de prueba

1. **Scheduling básico**
   - Marcar favorito para mañana
   - Verificar en DB: `SELECT * FROM notifications_programadas`
   - Verificar horario calculado (11 AM o 1h antes)
   - Esperar notificación al día siguiente

2. **Mensaje dinámico con 1, 2, 3+ eventos**
   - Marcar 1 favorito → Ver mensaje "✨ No te lo pierdas"
   - Agregar 2º → Ver "🥂 Doble planazo"
   - Agregar 3º → Ver "🚀 Maratón cultural"

3. **Adaptación de horario**
   - Marcar favorito a las 21:00 → Notif a 11:00
   - Agregar favorito a las 09:00 → Notif cambia a 08:00
   - Remover 09:00 → Notif vuelve a 11:00

4. **Cancelación al remover último**
   - Marcar único favorito del día
   - Verificar notificación programada
   - Desmarcar → Verificar cancelación en DB

5. **Post-reboot**
   - Marcar favoritos para mañana
   - Reiniciar device
   - Verificar que notificaciones aún programadas

6. **Tap en notificación**
   - Esperar notificación
   - Tap
   - Verificar que modal se abre con evento correcto

7. **Permisos denegados**
   - Desinstalar app
   - Reinstalar
   - Denegar permisos en dialog
   - Verificar que UI muestra error
   - Re-intentar y aceptar

---

## Dependencias Externas

**Packages**:
- `flutter_local_notifications`: ^17.x.x - Core para notificaciones locales y scheduling
- `timezone`: ^0.9.x - Manejo de zonas horarias para scheduling exacto
- `app_badge_plus`: ^1.x.x - Badges numéricos en app icon
- `firebase_messaging`: ^14.x.x - FCM (complementario, no requerido para locales)
- `device_info_plus`: ^10.x.x - Detectar versión de Android para permisos

**Assets requeridos**:
- `android/app/src/main/res/drawable/ic_notification.png` - Ícono de notificación (Android)
- Debe ser monocromo (blanco con alpha)
- Tamaños: hdpi, mdpi, xhdpi, xxhdpi, xxxhdpi

**Configuración de timezone**:
- `main.dart:44` - `tz.initializeTimeZones()` llamado al startup
- Usa timezone del device automáticamente

---

## Métricas y Performance

### Timing

- **Scheduling de notificación**: ~50-150ms
  - Incluye: DB query, cálculo de hora, scheduling de SO, DB insert
- **Toggle favorito → scheduling**: 300ms (debounce) + 50-150ms = ~350-450ms
- **Tap notificación → modal abierto**: ~100-300ms
- **Configuración inicial**: ~2-5 segundos (incluye user interaction con permisos)

### Database

- **Rows típicas en `notifications_programadas`**: 3-10
  - User promedio tiene favoritos para ~1 semana adelante
- **Tamaño por row**: ~150 bytes
  - JSON con 3 event codes: ~50 bytes
  - Metadata: ~100 bytes
- **Total tabla**: <2 KB típicamente

### Memory

- **NotificationService (singleton)**: ~5 KB
- **Pending notifications en memoria**: 0 (todo en SO scheduler)
- **Overhead por notificación programada**: ~200 bytes en SO

### Battery impact

- **Exact alarms**: Minimal (1 alarm per día típicamente)
- **BootReceiver**: Ejecuta solo al reinicio (~500ms de CPU)
- **Doze mode**: Compatible con `exactAllowWhileIdle`

---

## Comparación: Notificaciones Locales vs FCM

| Feature | Notificaciones Locales | FCM |
|---------|----------------------|-----|
| **Trigger** | Programadas por app | Enviadas desde servidor |
| **Requiere internet** | No | Sí |
| **Persistencia offline** | Sí (almacenadas localmente) | No (servidor debe reenviar) |
| **Exactitud de hora** | Exacta (±5 segundos) | Approximate (±15 min) |
| **Customización** | Total control de mensaje | Limitado por servidor |
| **Cancelación** | Fácil (por ID local) | Difícil (servidor debe decidir) |
| **Post-reboot** | Automático con BootReceiver | Requiere re-suscripción |
| **Deep linking** | Payload local, fácil | Data payload de servidor |
| **Uso en app** | Favoritos, recordatorios | Eventos importantes globales |

**Por qué usar locales para favoritos**:
- ✅ Funciona sin internet
- ✅ Horario adaptado a eventos del usuario
- ✅ Cancelación instantánea al desmarcar
- ✅ Persistencia garantizada cross-reboot

---

## Referencias de Código

### Archivos principales
- `lib/src/services/notification_service.dart` - Core de notificaciones locales (405 líneas)
- `lib/src/providers/favorites_provider.dart` - Trigger de scheduling (365 líneas)
- `lib/src/data/repositories/event_repository.dart` - CRUD de tabla (líneas 381-448)
- `lib/src/data/database/database_helper.dart` - Schema de tabla (líneas 103-111, 146-147)
- `lib/src/services/notification_config_service.dart` - Setup inicial (237 líneas)
- `android/app/src/main/AndroidManifest.xml` - Permisos y receivers (líneas 4-51)

### Métodos críticos
- `NotificationService.scheduleNotification()` (notification_service.dart:167-217)
- `NotificationService.calculateOptimalTime()` (notification_service.dart:232-277)
- `NotificationService.generateDynamicMessage()` (notification_service.dart:297-329)
- `FavoritesProvider._handleScheduledNotifications()` (favorites_provider.dart:158-193)
- `FavoritesProvider._createScheduledNotificationWithCodes()` (favorites_provider.dart:195-219)
- `FavoritesProvider._updateScheduledNotificationWithCodes()` (favorites_provider.dart:221-244)
- `EventRepository.insertScheduledNotification()` (event_repository.dart:393-416)

### Configuración
- Permisos Android: AndroidManifest.xml:8-10
- Receivers Android: AndroidManifest.xml:37-51
- Tabla SQL: database_helper.dart:103-111
- Migración v1→v2: database_helper.dart:151-177
