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

## 2. 🟠 Borrado secuencial — posible jank al borrar grupos grandes

En `documents_list_page.dart`, `_deleteSelected` hace
`for (id in ids) await provider.deleteDocument(id)` uno por uno. Si
`DocumentsProvider.deleteDocument` recarga la lista en cada iteración, borrar un grupo
de 10+ páginas dispara N recargas seguidas.

**Acción:** revisar `deleteDocument` en el provider; considerar un borrado por lote
(deleteMany) + una sola recarga/notifyListeners. Posible relación con
`scroll_jank_investigation.md` (perf de listas).

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

## Mejora futura ya identificada (no urgente)

- **`pdf_group_id` en la tabla `documents`** (migración v4): hoy el "grupo" de páginas de
  un PDF se infiere por heurística (prefijo `base_N` + ventana de tiempo, ver `65`).
  Una columna real de grupo eliminaría la ambigüedad y la limitación del renombrado.



Lo que ganaste en navegabilidad:

1. Descubribilidad. Antes el botón central era un logo mudo → muchos usuarios nunca iban a encontrar importar/vencimientos. Ahora la caja 🧰 invita a abrirla, y adentro cada función se explica sola con su frase. Pasaste de   
   "menú escondido" a "estante etiquetado".
2. Cero jerga. "Importar documento" → "Traer una foto o un papel". Eso solo le saca un muro de encima a un mayor. Lee y entiende sin traducir.
3. Consistencia = menos miedo. La flecha atrás en vez de la X, el botón [Compartir] grande igual que [Copiar texto]… el usuario aprende un patrón y lo aplica en toda la app. Eso baja la ansiedad, que en este público es clave.
4. Jerarquía honesta. ESCANEAR grande arriba (lo principal), el resto en "¿Qué más querés hacer?" (lo de más). La pantalla ya no compite consigo misma.

Lo único que sigue siendo cierto (no es un problema, es un trade-off que elegiste): las funciones secundarias siguen a un toque de distancia, dentro de la caja. Para un mayor muy novato, lo que no se ve en la primera pantalla
"no existe". Pero centralizarlo ahí es lo correcto para no abrumar — el ESCANEAR, que es el 90% del uso, está a la vista. Está bien resuelto.

Mi veredicto: gran salto, sobre todo en descubribilidad y lenguaje.