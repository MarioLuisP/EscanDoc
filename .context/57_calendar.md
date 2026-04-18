# 57 — Sistema de vencimientos y calendario

## Archivos implicados

### Base de datos
- `lib/core/database/database_helper.dart` — migración v2→v3: agrega `expiry_date TEXT`, elimina tablas `due_dates` y `document_due_dates`

### Modelo y repositorio
- `lib/features/documents/data/models/document_model.dart` — campo `expiryDate DateTime?`, `copyWith` con `clearExpiryDate`
- `lib/features/documents/data/repositories/document_repository.dart` — métodos `updateExpiryDate`, `getDocumentsWithExpiry`, `getDocumentsExpiringInRange`

### Domain
- `lib/features/documents/domain/usecases/update_expiry_date.dart` — UseCase nuevo, valida que la fecha no sea pasada

### Provider
- `lib/features/documents/presentation/providers/documents_provider.dart` — `updateExpiryDate`, `getExpiryCounts`, `getDocumentsExpiringOn`

### Extracción automática desde OCR
- `lib/core/services/expiry_date_extractor.dart` — extractor con score de confianza, keywords, boost por repetición, manejo de fechas pasadas y múltiples vencimientos (facturas)
- `lib/features/scan/domain/usecases/process_ocr.dart` — integra el extractor después del OCR, no sobreescribe fechas asignadas manualmente

### Calendario
- `lib/features/calendar/presentation/pages/calendar_page.dart` — pantalla nueva con `table_calendar`, modo browse y modo picking (asignar fecha), botón "Cambiar fecha" en card del documento, bloqueo de días pasados con `enabledDayPredicate`

### Detalle del documento
- `lib/features/documents/presentation/pages/document_detail_page.dart` — card de vencimiento colapsable, botón "Borrar" con confirmación, navegación al calendario para asignar/ver fecha, secciones nota y OCR colapsables

### Navegación
- `lib/main.dart` — ruta `/calendar` registrada

### Localización
- `assets/l10n/es.json` y `assets/l10n/en.json` — claves: `menu_calendar`, `expiry_section_title`, `expiry_none`, `expiry_set`, `expiry_change`, `expiry_remove`, `expiry_today`, `expiry_tomorrow`, `expiry_in_days`, `expiry_overdue`

### Fix colateral
- `lib/core/services/document_classifier.dart` — `extractDueDate` usaba `isAfter(DateTime.now())` que excluía hoy → corregido a comparar solo fecha sin hora

### Tests
- `test/features/documents/domain/usecases/update_expiry_date_test.dart` — 6 tests, GREEN
- `test/core/services/expiry_date_extractor_test.dart` — 13 tests, GREEN

---

## Cómo implementar notificaciones de vencimientos

El paquete `flutter_local_notifications` ya está en el pubspec, así que la infraestructura está lista.

### Idea general

El sistema necesita dos cosas: programar notificaciones cuando se asigna o modifica una fecha de vencimiento, y cancelarlas cuando se borra.

### Cuándo notificar

Lo más útil para el usuario mayor sería notificar en dos momentos:
- **7 días antes** del vencimiento — aviso temprano para que tenga tiempo de actuar
- **El día del vencimiento** — recordatorio final

Opcionalmente un tercer aviso a los 30 días si el documento es de largo plazo (seguros, pasaportes).

### Dónde disparar la lógica

El punto natural es `updateExpiryDate` en el provider o en el UseCase. Cada vez que se asigna o cambia una fecha se reprograman las notificaciones del documento. Cada vez que se borra, se cancelan.

Para identificar cada notificación se puede usar el `documentId` como base del `notificationId` — por ejemplo `docId * 10 + 0` para el aviso de 7 días y `docId * 10 + 1` para el del día.

### Permisos

En Android 13+ hay que pedir permiso explícito para notificaciones exactas. En iOS hay que pedir permiso en el onboarding o al primer uso. Esto se maneja con `flutter_local_notifications` + `permission_handler`.

### Configuración de canal (Android)

Se necesita crear un canal de notificaciones con importancia alta para que aparezcan como heads-up. Esto se hace una sola vez al iniciar la app en `main.dart`.

### Consideraciones UX

- Las notificaciones deben mostrar el título del documento y la fecha de vencimiento
- Al tocarlas deben navegar directo al detalle del documento usando el `documentId` como payload
- Se podría agregar en Settings una opción para activar/desactivar notificaciones y elegir cuántos días antes avisar
