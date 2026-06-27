# 66 — Pendientes / deuda técnica para revisar

**Origen:** observaciones de la sesión del 2026-06-27 (ver `65_retomar_junio2026.md`).
Ordenados por prioridad sugerida.

---

## 1. 🔴 Texto hardcodeado en español (rompe regla inquebrantable #4)

En `lib/features/documents/presentation/pages/home_page.dart` hay strings literales en
español, sin claves de localización. En inglés aparecerían en español.

- `_showPdfPagesDialog` (~líneas 656-673): `'PDF largo'`, `'Este PDF tiene $totalPages
  páginas.\n¿Cuántas querés importar?'`, `'Cancelar'`, `'Primeras 10'`, `'Todas ($totalPages)'`.
- Mensajes de error de import (~líneas 617, 639, 695): `'No se pudo leer el PDF'`,
  `'No se pudo importar el PDF'`, `'Error al preparar documento: ...'`.

**Acción:** mover a `es.json`/`en.json` con `.tr()`. Revisar también si hay literales
similares en otras pages de import/scan.

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

## 4. 🟡 Warnings de lint preexistentes en `settings_page.dart`

- Import sin usar: `package:escandoc/core/widgets/notification_permission_dialog.dart` (línea ~6).
- `BuildContext` usado a través de async gap (línea ~78) → `use_build_context_synchronously`.
- (Info) `curly_braces_in_flow_control_structures` en `home_page.dart:146`.

**Acción:** limpieza rápida de lint.

## 5. 🟡 Tests "bomba de tiempo" (fechas hardcodeadas)

En la sesión se arregló uno (`document_classifier_test.dart` usaba fechas de junio 2026
ya caducadas). Pueden existir otros tests con fechas cercanas hardcodeadas que fallen
con el paso del tiempo.

**Acción:** `grep` por fechas literales (`/20\d\d` o `DateTime(202...)`) en `test/` y
migrar a fechas relativas a `DateTime.now()` o lejanas (2099).

---

## Mejora futura ya identificada (no urgente)

- **`pdf_group_id` en la tabla `documents`** (migración v4): hoy el "grupo" de páginas de
  un PDF se infiere por heurística (prefijo `base_N` + ventana de tiempo, ver `65`).
  Una columna real de grupo eliminaría la ambigüedad y la limitación del renombrado.
