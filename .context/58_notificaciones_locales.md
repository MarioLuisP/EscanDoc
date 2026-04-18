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
- `lib/main.dart` — `tz.initializeTimeZones()`, `GlobalKey<NavigatorState>` asignado al `MaterialApp` y al `NotificationService`, `initialize()` y `requestPermission()` en PostFrameCallback (requieren Activity activa), manejo de cold-start desde tap en notificación
- `lib/features/documents/presentation/providers/documents_provider.dart` — hook `_syncNotification()` en `updateExpiryDate()`, métodos `enableNotifications()` y `disableNotifications()` (con `cancelAll` + reschedule de todos los documentos)
- `lib/features/onboarding/presentation/pages/onboarding_page.dart` — muestra el modal al terminar el onboarding (intento 1 de 3)
- `lib/features/documents/presentation/pages/document_detail_page.dart` — muestra el modal al asignar un vencimiento si quedan intentos disponibles (intentos 2 y 3)
- `lib/features/settings/presentation/pages/settings_page.dart` — convertida a StatefulWidget; agrega switch de activar/desactivar con diálogo de confirmación al desactivar; botón de prueba provisorio que agenda una notificación en 2 minutos
- `assets/l10n/es.json` y `en.json` — claves para el modal de permisos, el toggle de Settings y el botón de prueba
- `android/app/src/main/res/drawable*/ic_notification.png` — ícono de notificación copiado temporalmente desde QueHacemos (pendiente reemplazar)

### Tests

- `test/core/services/document_classifier_test.dart` — corregida fecha `2026-04-10` (ya pasada) por `2099-04-10`

---

## Decisiones de diseño

**Timezone sin plugin extra:** `flutter_timezone` fue descartado por incompatibilidad con el embedding API de Flutter 3.x. Se usa `DateTime.toUtc()` directamente — Dart conoce el offset del OS, la conversión es exacta sin dependencias extra.

**`initialize()` en PostFrameCallback, no en `main()`:** el diálogo de permisos del sistema requiere una Activity activa. Llamarlo antes de `runApp()` hace que el request falle silenciosamente en Android.

**Sin tabla SQLite adicional:** a diferencia de QueHacemos (que agrupa favoritos por fecha), cada documento tiene su propio par de notificaciones identificadas por `docId * 10` y `docId * 10 + 1`. El plugin persiste internamente lo necesario para restaurar post-reboot.

**`notif_enabled` por defecto `true`:** usuarios que nunca tocaron el toggle tienen notificaciones activas por defecto, que es el comportamiento esperado en Android < 13 donde el permiso es automático.

**Modal de permisos en 3 momentos:** al terminar onboarding, al asignar el primer vencimiento y al asignar el segundo. Después de 3 intentos (o si el usuario activa), nunca más se muestra.

---

## Pendiente

- **Íconos de notificación propios:** actualmente se usan los de QueHacemos. Hay que reemplazar `ic_notification.png` en todos los directorios drawable con un ícono monocromático (blanco con alpha) representativo de EscanDoc.
- **Modal de permisos en Settings:** al activar desde el switch, si el OS aún no tiene el permiso concedido, conviene mostrar el modal explicativo antes del diálogo del sistema (actualmente llama directo a `requestPermission()`).
- **Textos de notificación localizados:** los títulos y cuerpos de las notificaciones ("Vencimiento próximo", "Vence hoy", etc.) están hardcodeados en español dentro del `NotificationService`, que no tiene acceso a `BuildContext`. Una solución sería inyectarlos como parámetro desde el provider, que sí puede resolver la localización.
- **Botón de prueba provisorio:** la card "Notificaciones" en Settings tiene un botón de prueba que agenda una notificación en 2 minutos. Debe eliminarse antes de la release.
- **iOS:** la inicialización y los permisos están contemplados en el código (`DarwinInitializationSettings`), pero no fue probado en dispositivo real ni en simulador. Verificar comportamiento del diálogo de permisos iOS y el deep link desde notificación con app cerrada.
