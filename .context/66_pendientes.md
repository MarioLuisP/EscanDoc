# 66 — Pendientes / deuda técnica para revisar

**Origen:** observaciones de la sesión del 2026-06-27 (ver `65_retomar_junio2026.md`).
Ordenados por prioridad sugerida.

---

## 1. ✅ HECHO (2026-06-27) — Texto hardcodeado en español (rompía regla inquebrantable #4)

Migrados 10 strings a `es.json`/`en.json` con `.tr()` (8 del doc + 2 extra encontrados en
`_savePhotoToGallery`: `photo_saved_gallery`, `photo_save_gallery_error`). Claves nuevas:
`pdf_read_error`, `pdf_import_error`, `import_prepare_error`, `pdf_pages_dialog_title`,
`pdf_pages_dialog_message`, `pdf_pages_cancel`, `pdf_pages_first_10`, `pdf_pages_all`.
Tests GREEN (343). Pendiente menor opcional: `throw Exception('El archivo no existe…')`
(~línea 687) — mensaje interno developer-facing, no se localizó.

<details><summary>Detalle original</summary>

## 1. 🔴 Texto hardcodeado en español (rompe regla inquebrantable #4)

En `lib/features/documents/presentation/pages/home_page.dart` hay strings literales en
español, sin claves de localización. En inglés aparecerían en español.

- `_showPdfPagesDialog` (~líneas 656-673): `'PDF largo'`, `'Este PDF tiene $totalPages
  páginas.\n¿Cuántas querés importar?'`, `'Cancelar'`, `'Primeras 10'`, `'Todas ($totalPages)'`.
- Mensajes de error de import (~líneas 617, 639, 695): `'No se pudo leer el PDF'`,
  `'No se pudo importar el PDF'`, `'Error al preparar documento: ...'`.

**Acción:** mover a `es.json`/`en.json` con `.tr()`. Revisar también si hay literales
similares en otras pages de import/scan.

</details>

## 2. ✅ HECHO (2026-06-27) — Borrado secuencial → borrado por lote

**Diagnóstico corregido:** `DocumentsProvider.deleteDocument` NO recargaba de la DB
(actualizaba en memoria). El jank real venía de: (1) N transacciones DB + N borrados de
archivo serializados con `await`, (2) **N× `notifyListeners()`** → N rebuilds de la lista
en cascada, (3) N× filtro O(n) → O(n²).

**Solución (TDD, Domain→Tests→Data→UI):** `deleteDocuments(List<int>)` end-to-end:
- `DeleteDocuments` UseCase (`domain/usecases/delete_documents.dart`) → devuelve ids
  borrados; lista vacía no toca repo; fail-safe `[]`.
- `DocumentRepository.deleteDocuments`: **una transacción** (SELECT paths + DELETE con
  `id IN (...)`) + borrado de archivos en paralelo (`Future.wait`). Devuelve ids borrados.
- `DocumentsProvider.deleteDocuments`: un filtro en memoria + **un solo `notifyListeners`**.
- UI `documents_list_page.dart`: el `for` reemplazado por una llamada; snackbar usa el
  conteo real devuelto.

`deleteDocument` (singular) se mantiene intacto (lo usa la pantalla de detalle).
12 tests nuevos (4 UseCase + 4 repo ffi + 4 provider, incl. aserción de notify único).
Suite GREEN (355). `analyze` limpio.

## 3. 🟡 Posible fuga del handle nativo del PDF

`image_format_converter_impl.dart` → `_convertPdfToJpg`: si salta una excepción entre
`pdf.open()` y `pdf.close()`, el documento nativo no se cierra (no hay `finally`).
Heredado del wrapper original. Menor, pero real.

**Acción:** envolver open→render→close en `try/finally` para garantizar el `close()`.

## 4. ✅ HECHO (2026-06-27) — Warnings de lint preexistentes en `settings_page.dart`

Los tres resueltos:
- Import sin usar `notification_permission_dialog.dart` → eliminado.
- `BuildContext` a través de async gap (`_toggleNotifications`) → se captura
  `documentsProvider` con `context.read` **antes** del `await _confirmDisable()`.
- `curly_braces_in_flow_control_structures` (`_detectFormatByMagicBytes`, el `if` de WebP)
  → llaves agregadas.

`flutter analyze` de ambos archivos: **No issues found!**. Tests GREEN (343).

## 5. ✅ AUDITADO (2026-06-27) — Tests "bomba de tiempo" (fechas hardcodeadas)

Auditoría completa de todas las fechas literales en `test/`. **No quedan bombas.** La
única real ya se había desactivado (`document_classifier_test.dart` jun 2026 → 2099).
El resto es seguro:
- **Relativo a `now()`** (patrón correcto): `expiry_date_extractor_test` (`now.year + N`),
  `update_expiry_date_test` (`tomorrow`/`yesterday`/`today`).
- **Mockeado** (fecha es stub, reloj real no corre): `process_ocr_test` (15/02/2026,
  31/12/2026 → `when(mockClassifier.extractDueDate).thenReturn(...)`).
- **Parsing puro / clock-independent**: `document_classifier_test` extractDueDate usa 2099
  (válidas) y 2020 (pasada); `generateDocumentName` solo formatea día/mes (año irrelevante).
- **Fixtures de datos** (no comparados contra `now`): `createdAt`, títulos `*_Ene_2026`,
  orden en repository/provider/search tests.

Firma de la bomba = fecha futura hardcodeada que pasa por lógica que la compara contra
`DateTime.now()` real (sin mock). Confirmado por grep: no hay comparaciones con `now`
fuera de los 2 archivos que ya usan patrón relativo.

<details><summary>Acción original</summary>

**Acción:** `grep` por fechas literales (`/20\d\d` o `DateTime(202...)`) en `test/` y
migrar a fechas relativas a `DateTime.now()` o lejanas (2099).

</details>

---

## 6. ⏸️ EVALUADO Y POSPUESTO (2026-06-27) — `pdf_group_id` (migración v4)

Hoy el "grupo" de páginas de un PDF se infiere por heurística: prefijo `base_N` +
ventana de tiempo sobre `createdAt`. Un `group_id` real sería lo correcto en abstracto,
pero **no vale la pena ahora**: costo alto (migración v4 + backfill + path de inserción +
formato backup `.escdc` + tests en todas las capas) vs. riesgo bajo (peor caso = scope de
borrado equivocado, recuperable con "borrar solo seleccionadas"; no hay pérdida de datos).

**Hallazgos de la evaluación:**
- `createdAt` NO refleja el tiempo de procesamiento. `ImportProvider` captura `baseTime`
  una sola vez y asigna `createdAt = baseTime + offset_ms`. **Verificado en device:** 10
  páginas de un PDF abarcaron **9 milisegundos** (no ~1s/página como sugería la cadencia
  visual de renderizado).
- El flanco real es el *false-positive* (fusionar 2 imports), acotado por el **prefijo de
  nombre**, no por el tiempo. Para imports vía *compartir*, el `pdfBaseName` ya incluye un
  epoch único (`..._1782601091474_N`) → imposible fusionar. El hueco solo existe para
  imports vía *selector de archivos* con nombre idéntico en poco tiempo.

**Mitigación barata aplicada (sin migración):** `_groupWindow` bajado de **2 min → 30 s**
en `documents_list_page.dart`. Imposible partir un PDF real (necesitaría ~30.000 páginas)
y achica 4× la ventana de fusión accidental.

Si el hueco del selector de archivos llegara a molestar: meter un epoch/hash en el
`pdfBaseName` del título también lo cerraría sin tocar schema.



Lo que ganaste en navegabilidad:

1. Descubribilidad. Antes el botón central era un logo mudo → muchos usuarios nunca iban a encontrar importar/vencimientos. Ahora la caja 🧰 invita a abrirla, y adentro cada función se explica sola con su frase. Pasaste de   
   "menú escondido" a "estante etiquetado".
2. Cero jerga. "Importar documento" → "Traer una foto o un papel". Eso solo le saca un muro de encima a un mayor. Lee y entiende sin traducir.
3. Consistencia = menos miedo. La flecha atrás en vez de la X, el botón [Compartir] grande igual que [Copiar texto]… el usuario aprende un patrón y lo aplica en toda la app. Eso baja la ansiedad, que en este público es clave.
4. Jerarquía honesta. ESCANEAR grande arriba (lo principal), el resto en "¿Qué más querés hacer?" (lo de más). La pantalla ya no compite consigo misma.

Lo único que sigue siendo cierto (no es un problema, es un trade-off que elegiste): las funciones secundarias siguen a un toque de distancia, dentro de la caja. Para un mayor muy novato, lo que no se ve en la primera pantalla
"no existe". Pero centralizarlo ahí es lo correcto para no abrumar — el ESCANEAR, que es el 90% del uso, está a la vista. Está bien resuelto.

Mi veredicto: gran salto, sobre todo en descubribilidad y lenguaje.