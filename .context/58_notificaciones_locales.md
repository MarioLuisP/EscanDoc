# 58 — Notificaciones Locales de Vencimientos

## Descripción general

Sistema de notificaciones locales programadas que avisa al usuario cuando un documento está próximo a vencer. S
e basa en la implementación probada de QueHacemos, adaptada a la lógica de vencimientos de EscanDoc.

Cada documento con fecha de vencimiento recibe hasta 2 notificaciones programadas:
- **7 días antes** del vencimiento, a las 9:00 AM
- **El día del vencimiento**, a las 9:00 AM

Al tocar la notificación, la app navega directamente al detalle del documento.

---

## Archivos implicados

### Nuevos

- `lib/core/services/notification_service.dart` — servicio core: inicialización, scheduling con `zonedSchedule` (exactAllowWhileIdle), cancelación, deep link por navigator key, notificación de prueba
- `lib/core/services/notification_prompt_service.dart` — gestiona el contador de intentos del modal (máx 3) y el flag `notif_enabled` en SharedPreferences
- `lib/core/widgets/notification_permission_dialog.dart` — modal explicativo reutilizable que pide permiso al usuario antes de invocar el diálogo del sistema

### Modificados

- `pubspec.yaml` — agregado `timezone: ^0.11.0`
- `android/app/src/main/AndroidManifest.xml` — permisos `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE` + 3 receivers del plugin (`ScheduledNotificationReceiver`, `ScheduledNotificationBootReceiver`, `FlutterLocalNotificationsReceiver`)
- `lib/main.dart` — `tz.initializeTimeZones()` + `FlutterTimezone.getLocalTimezone()` + `tz.setLocalLocation()` antes de `runApp()`. `GlobalKey<NavigatorState>` asignado al `MaterialApp` y al `NotificationService`. En PostFrameCallback: solo `initialize()` (NO `requestPermission()`) + manejo de cold-start desde tap en notificación.
- `lib/features/documents/presentation/providers/documents_provider.dart` — hook `_syncNotification()` en `updateExpiryDate()`, métodos `enableNotifications()` (setEnabled(true) + reschedule de todos los documentos) y `disableNotifications()` (setEnabled(false) + cancelAll). `enableNotifications()` NO llama `requestPermission()` — los permisos son responsabilidad exclusiva de la capa UI.
- `lib/features/onboarding/presentation/pages/onboarding_page.dart` — muestra el modal al terminar el onboarding (intento 1 de 3)
- `lib/features/documents/presentation/pages/document_detail_page.dart` — muestra el modal al asignar un vencimiento si quedan intentos disponibles (intentos 2 y 3)
- `lib/features/settings/presentation/pages/settings_page.dart` — convertida a StatefulWidget; agrega switch de activar/desactivar con diálogo de confirmación al desactivar; botón de prueba provisorio que agenda una notificación en 2 minutos
- `assets/l10n/es.json` y `en.json` — claves para el modal de permisos, el toggle de Settings y el botón de prueba
- `android/app/src/main/res/drawable*/ic_notification.png` — ícono de notificación copiado temporalmente desde QueHacemos (pendiente reemplazar)

### Tests

- `test/core/services/document_classifier_test.dart` — corregida fecha `2026-04-10` (ya pasada) por `2099-04-10`

---

## Decisiones de diseño

**Timezone:** se usa `flutter_timezone` + `tz.setLocalLocation()` en `main()` antes de `runApp()`. `_toTZDateTime()` usa `tz.local` directamente.

**`initialize()` en PostFrameCallback, no en `main()`:** el diálogo de permisos del sistema requiere una Activity activa. Llamarlo antes de `runApp()` hace que el request falle silenciosamente en Android.

**Sin tabla SQLite adicional:** a diferencia de QueHacemos (que agrupa favoritos por fecha), cada documento tiene su propio par de notificaciones identificadas por `docId * 10` y `docId * 10 + 1`. El plugin persiste internamente lo necesario para restaurar post-reboot.

**`notif_enabled` por defecto `true`:** el default aplica a Android < 13 donde el permiso es automático. En API 33+, `_loadNotifState()` en `SettingsPage` verifica siempre el estado real del sistema y sincroniza SharedPreferences si hay discrepancia. No confiar en el default de SharedPreferences sin verificar.

**Modal de permisos en 3 momentos:** al terminar onboarding, al asignar el primer vencimiento y al asignar el segundo. Después de 3 intentos (o si el usuario activa), nunca más se muestra.

---

## Bug corregido (Abril 2026)

**`initialize()` devuelve `bool?`, no `bool`** — en algunos dispositivos Android (confirmado: Motorola G52 API 33) retorna `null` en lugar de `true`. El código original usaba `if (success == true)`, que trata `null` como fallo y deja `_initialized = false`. Consecuencia: `requestPermission()` y todo el scheduling salían silenciosamente sin hacer nada.

**Fix:** cambiar `success == true` por `success != false` en `notification_service.dart`.

---

## Cambios Abril 2026

### Flujo de activación completo (Settings toggle ON)
`_SettingsPageState` implementa `WidgetsBindingObserver`. Al activar el switch:
1. `NotificationService.initialize()` si no estaba inicializado
2. `requestNotificationPermissionOnly()` → solo POST_NOTIFICATIONS (Android) / `requestPermissions` (iOS)
3. `areNotificationsEnabled()` → si false: abre Ajustes de la app via `openAppSettings()` (permission_handler), setea `_waitingForNotifPermission = true` y espera retorno via `didChangeAppLifecycleState` → `_resumeAfterNotifSettings()`
4. `canScheduleExactAlarms()` → si false, abre Ajustes de alarmas exactas y espera retorno via `didChangeAppLifecycleState` → `_finalizeEnable()`
5. `_finalizeEnable()` → `enableNotifications()` + modal de éxito (auto-cierre 3 seg) o error

`_loadNotifState()`: si SharedPreferences dice true pero `areNotificationsEnabled()` = false, sincroniza a false (fix API 33 — el default true no garantiza permiso del sistema).

Modal de éxito: Dialog igual al de desactivar, con ícono ✓ verde, se cierra solo en 3 segundos.
Modal de error: mismo estilo, ícono ⚠️ naranja, botón "Entendido".

### 3 notificaciones por documento
- `documentId * 10` → 7 días antes, 9 AM — `"📅 Vence en 7 días"`
- `documentId * 10 + 1` → 1 día antes, 9 AM — `"⚠️ Vence mañana"`
- `documentId * 10 + 2` → día del vencimiento, 9 AM — `"⏰ Vence hoy"`

`cancelExpiryNotifications()` cancela los 3 IDs.

### Título de notificación: nombre corto
`_extractShortName(title)` — saltea artículos/preposiciones, toma las primeras 2 palabras significativas.
- Números al inicio → los salta y toma la primera palabra real
- Sin palabras (todo números) → primeros 10 dígitos
- Acrónimos ≤4 letras en mayúsculas (DNI, VISA) → se conservan
- Ejemplo: `"Factura de Aguas Cordobesas"` → `"Factura Aguas"`

### Fix _toTZDateTime — incluye segundos
Antes truncaba a minutos → notificaciones de prueba en <60s quedaban en el pasado y se descartaban.

### Botón de prueba actualizado
Dispara 3 notificaciones reales en 20/40/60 segundos con el título del primer documento de la lista.
Fallback si no hay documentos: `"Factura de Aguas Cordobesas"`.

### iOS — cobertura de permisos
`areNotificationsEnabled()` y `requestNotificationPermissionOnly()` implementan rama iOS via `IOSFlutterLocalNotificationsPlugin`. `canScheduleExactAlarms()` retorna `true` en iOS (no aplica).
**Pendiente:** probar en dispositivo real / simulador iOS.

## Bugs corregidos (Abril 2026 — sesión 2)

**Toggle arrancaba ON pero notificaciones no llegaban en API 33**
`_loadNotifState()` leía solo SharedPreferences (default `true`) sin verificar el permiso real del sistema. En API 33+, el permiso `POST_NOTIFICATIONS` no se otorga automáticamente. Fix: verificar `areNotificationsEnabled()` al cargar el estado; si discrepa, sincronizar SharedPreferences.

**Toggle OFF → nunca volvía a ON**
Cuando `POST_NOTIFICATIONS` fue denegado permanentemente (Android no muestra el dialog después de 2 rechazos), el flujo solo mostraba un modal de error sin salida. Fix: usar el mismo patrón que ya existía para alarmas exactas — abrir Ajustes de la app via `openAppSettings()` y esperar retorno.

**`requestPermission()` llamado en cada arranque (main.dart) y al habilitar (documents_provider.dart)**
Esto abría el dialog de notificaciones sin contexto y la pantalla de ajustes de alarmas exactas en cada inicio. Quemaba los intentos de Android antes de que el usuario tomara una decisión consciente. Fix: remover ambas llamadas. Los permisos se piden únicamente cuando el usuario activa el toggle explícitamente.

**ProGuard (release) sin reglas para flutter_local_notifications**
`isMinifyEnabled = true` con R8 podía eliminar los receivers del plugin en builds de release. Fix: agregar `-keep class com.dexterous.** { *; }` en `proguard-rules.pro`.

## Bugs corregidos (Mayo 2026)

**`ic_notification` no se encontraba en release (PlatformException invalid_icon)**
En API 33 (Motorola G52) builds release fallaban con `The resource ic_notification could not be found`. En debug funcionaba. Causa: con `isMinifyEnabled = true`, R8 + AAPT2 podían dropear el drawable (referenciado solo por string desde Dart) y romper la deserialización Gson interna del plugin.
Fix:
1. `android/app/src/main/res/raw/keep.xml` con `tools:keep="@drawable/ic_notification"`.
2. `proguard-rules.pro`: agregar `-keepattributes Signature, *Annotation*, InnerClasses, EnclosingMethod`.

## Cambios Mayo 2026

### Botón de prueba a 10 minutos (real)
Segunda card en Settings al lado del botón de 60s. Llama a `NotificationService.scheduleTestNotificationIn10Min()`, que construye el `DateTime` desde componentes (year/month/day/hour/min/sec) — **mismo code path** que `scheduleExpiryNotifications`. Diferencia útil con la prueba de 60s: a 10 min se puede bloquear pantalla y entrar en Doze ligero.
- ID reservado: `99996` (los otros 3 tests usan 99997/99998/99999).
- Snackbar muestra la hora exacta a la que va a llegar (formato HH:mm).
- Claves: `settings_test_notif_10min_button`, `settings_test_notif_10min_success`.

### Battery optimization opt-in en flujo del toggle
Paso 5 nuevo en `_enableWithFullFlow` (después de exact alarms, antes de `_finalizeEnable()`):
- Solo Android. Si `Permission.ignoreBatteryOptimizations.isGranted` → skip.
- Si no: modal naranja con ícono de batería + "Más tarde" / "Permitir". "Permitir" dispara el dialog del sistema vía `Permission.ignoreBatteryOptimizations.request()`.
- **No bloquea**: si el usuario rechaza o pospone, las notificaciones igual se activan.
- Permiso agregado al manifest: `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
- Claves: `notif_battery_optim_title/body/later/configure`.

## Techo aceptado de fiabilidad

Si en Doze profundo (>1h pantalla apagada en Motorola/Xiaomi) los avisos no llegan, **no se escala más**. Alternativas descartadas:
- **FCM**: requiere backend + login, fuera de scope.
- **Workmanager**: histórico de fracasos en otra app del usuario (semanas peleando, nunca funcionó).
- **`AndroidScheduleMode.alarmClock`**: muestra ícono persistente en status bar (ruidoso para 30 documentos) y riesgo de rechazo en Play Store por uso fuera de scope.

EscanDoc no es app de alarmas críticas. Si un OEM agresivo retrasa un aviso, asumimos el costo. Documentar como limitación conocida si aparece en QA.

## Pendiente

- **Botones de prueba provisorios (60s y 10min):** eliminar antes de la release.
- **iOS:** probar toggle activar/desactivar en dispositivo real. Verificar deep link desde notificación con app cerrada.
- **Doze profundo en Motorola G52:** validar entrega con pantalla apagada toda la noche (con battery optim concedido).
- **Reboot:** validar que los avisos se reprograman correctamente tras reiniciar el celu.
