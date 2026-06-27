# 65 — Retomar el proyecto: arranque, dependencias y UI (Junio 2026)

**Fecha:** 2026-06-27
**Contexto:** Sesión para retomar el proyecto tras un tiempo sin tocarlo. Tres frentes:
(1) la app no arrancaba en el emulador, (2) actualización de dependencias, (3) dos
mejoras de UI en la lista de documentos.

Entorno: Flutter 3.41.0 / Dart 3.11.0 (sin FVM). Emulator API 30 (Android 11).

---

## 1. Arranque: pantalla blanca en el emulador (timezone)

**Síntoma:** la app quedaba en pantalla blanca; proceso vivo pero sin renderizar.

**Causa raíz:** crash en `main()` **antes** de `runApp()` (por eso no dibujaba nada;
no era problema del emulador):
```
E/flutter: Unhandled Exception: Location with the name "GMT" doesn't exist
  #2  main (package:escandoc/main.dart)
```
1. `FlutterTimezone.getLocalTimezone()` devuelve `"GMT"` en el emulador.
2. `tz.getLocation("GMT")` lanza: la DB de `timezone` (data 2025c) no incluye el alias
   corto `"GMT"`, sólo los canónicos tipo `Etc/GMT`.
3. Revienta antes de `runApp`.

En teléfono real no pasa (el SO reporta un id válido, ej. `America/Argentina/Buenos_Aires`).
**Detalle:** el fallback `tz.getLocation('UTC')` **también falla** (mismo motivo). Hay que
usar la constante integrada `tz.UTC` (un `Location` que no consulta la DB).

**Fix (`lib/main.dart`):**
```dart
tz_data.initializeTimeZones();
try {
  final timezoneInfo = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
} catch (_) {
  tz.setLocalLocation(tz.UTC); // NO getLocation('UTC') — también lanzaría.
}
```
Commiteado por el usuario como `7d34268 "fix utc"`.
Nota: en el emulador las notificaciones quedan en UTC. Para probar horarios reales,
cambiar la zona del emulador en Settings.

---

## 2. Dependencias

### Cómo se hizo
- **Grupo 1 (seguro):** `flutter pub upgrade` (sin `--major-versions`) → 48 deps
  actualizadas dentro de constraints. Luego, file_picker 11 (Grupo 2).
- **Lección central:** tras `flutter pub upgrade` los tests pasan, pero NO compilan
  código nativo. **Hay que correr `flutter run` en Android** para validar Kotlin/Swift.
  Dos plugins rompieron el build de Android al subir y se tuvieron que pinear.

### Estado completo de dependencias DIRECTAS desactualizadas (al 2026-06-27)

| Paquete | Actual | Última | Estado / Razón |
|---|---|---|---|
| **receive_sharing_intent** | 1.8.1 | 1.9.0 | 🔒 **PIN** `1.8.1`. 1.9.0 rompe build Android (`kotlin()` en build.gradle:53, pide SDK 37). |
| **speech_to_text** | 7.3.0 | 7.4.0 | 🔒 **PIN** `7.3.0`. 7.4.0 no compila (declaración duplicada `pluginChannelName` en su Kotlin). |
| **share_plus** | 12.0.2 | 13.2.0 | ⛔ Bloqueado: 13.x pide `win32 ^6`, file_picker 11.0.2 pide `win32 ^5`. API Dart idéntica → sin beneficio. Reintentar cuando file_picker soporte win32 6. |
| **flutter_local_notifications** | 21.0.0 | 22.0.1 | ⏸️ Diferido a propósito (área sensible de notificaciones — sesión dedicada). |
| **intl** | 0.20.2 | 0.20.3 | 🔗 Pineado por el SDK de Flutter. No se puede subir solo. |
| **image** | 4.8.0 | 4.9.1 | 🔗 Resolvable tope 4.8.0 (lo limita otra dep). Diferencia menor, bajo valor. |
| **pdf** | 3.12.0 | 3.13.0 | 🔗 Limitado por `printing`. Sube cuando suba printing. |
| **printing** | 5.14.3 | 5.15.0 | 🔗 Resolvable tope 5.14.3. Bajo valor. |
| **sqflite** | 2.4.2+1 | 2.4.3 | 🔗 Resolvable tope 2.4.2+1. Patch, bajo valor. |
| **sqflite_common_ffi** (dev) | 2.4.0+3 | 2.4.2 | 🔗 Resolvable tope. Solo tests. |

Leyenda: 🔒 pin propio · ⛔ bloqueo de resolución · ⏸️ diferido por decisión · 🔗 limitado por constraint ajeno/SDK.

### file_picker 10 → 11 (HECHO ✓ y verificado)
- Único breaking que nos afecta: `FilePicker.platform.pickFiles()` → `FilePicker.pickFiles()`
  (métodos estáticos). 3 call sites migrados: `settings_page.dart`, `home_page.dart`,
  `dev/fixture_capture_page.dart`. 11.0.1 arregló compat con AGP < 9 (respeta la lección de no subir AGP 9).
- **Bloqueo resuelto:** `pdf_to_image_converter 0.0.5` (abandonado) pineaba `file_picker ^10`.
  Era un wrapper finito sobre `pdf_image_renderer` (que NO depende de file_picker).
  → Se reemplazó por **`pdf_image_renderer: ^2.0.0` directo**. Reescrito `_convertPdfToJpg`
  en `image_format_converter_impl.dart` (API: `PdfImageRenderer(path:)`, `.open()`,
  `.openPage()`, `.getPageSize()`, `.renderPage(...)`, `.closePage()`, `.close()`; render 2x).
  pdf_image_renderer 2.0.0 pide Flutter >=3.41 / Dart >=3.11 (OK).
- **VERIFICADO EN DEVICE:** import de PDF (incluso 10 páginas) OK.

### Test "bomba de tiempo" corregido
`test/core/services/document_classifier_test.dart` ("reconocer diferentes keywords")
hardcodeaba fechas de junio 2026 ya caducadas; `extractDueDate` descarta vencimientos
pasados (correcto). Fix: usar fechas 2099 como el resto del archivo.

### Resumen
- ✅ Subido: Grupo 1 (48 deps) + file_picker 11 + pdf_image_renderer 2.
- 🔒 Pin propio (no subir): receive_sharing_intent 1.8.1, speech_to_text 7.3.0.
- ⛔/⏸️ Pendientes con razón: share_plus 13 (win32), flutter_local_notifications 22 (notif).
- 🔗 Resto: limitado por SDK/constraints ajenos, bajo valor — se moverán solos.
- Tests: 343 verdes.

---

## 3. UI — Lista de documentos

### Botón "Seleccionar" (modo selección explícito)
Antes sólo se entraba a multiselección con long-press (poco descubrible). Se agregó un
botón celeste **"Seleccionar"** a la derecha del chip de ordenar en `_buildSortBar`
(`documents_list_page.dart`). Entra en modo selección sin preseleccionar; cuando no hay
nada elegido, la barra inferior muestra un hint (`selection_hint`). El botón "Borrar"
aparece con ≥1 seleccionado; "Crear PDF" con ≥2. Long-press sigue como atajo.
Claves nuevas: `select_button`, `selection_hint`.

### Borrado con detección de grupo (PDF multipágina)
**Problema de datos:** las páginas de un PDF importado NO tienen grupo en la BD. Se
guardan como documentos sueltos, tipo `"documento"`, filePath `.jpg` (cada página se
renderiza a JPG). La única relación es: **título `base_N`** (ej. `tutorial_1`,
`tutorial_2`…) + **createdAt casi idéntico** (misma ráfaga de import).

**Solución (heurística, opción A):** `_expandToGroups()` agrupa por **prefijo `base_`
(regex `^(.+)_(\d+)$`) Y `createdAt` dentro de ±2 min** (`_groupWindow`). Combinar las
dos señales evita falsos positivos (un `cosa_3` de otro día no se agrupa con `cosa_1` de hoy).
Al borrar, si la selección toca un grupo con páginas NO seleccionadas, aparece diálogo
`_showGroupDeleteDialog` con: **Borrar solo seleccionadas (N)** / **Borrar grupo completo (M)**
/ Cancelar (los conteos son reales y visibles → salvaguarda contra borrar de más).
Si no hay grupo, confirmación normal de siempre.
Claves nuevas: `delete_group_title`, `delete_group_message`, `delete_only_selected`, `delete_whole_group`.
Enum top-level `_DeleteScope { selected, group }`.

**Limitación conocida:** si renombrás una página (sale del patrón `base_N`), deja de
agruparse. Aceptable para el uso.
**Mejora futura (robusta):** agregar columna `pdf_group_id` a `documents` (migración v4),
seteada al importar el PDF → elimina la heurística y la ambigüedad por completo.

**PENDIENTE DE VERIFICAR EN DEVICE:** ambas features de UI (sin cobertura de tests):
botón seleccionar + diálogo de borrado de grupo con conteos correctos.
