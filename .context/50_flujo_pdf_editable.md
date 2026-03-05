# Flujo PDF — Plan de implementación

## Principio fundamental

La app siempre trabaja con JPG internamente.
El PDF de entrada es solo una fuente de datos, nunca se almacena.
El PDF de salida se genera al momento del export, nunca se guarda en la app.

---

## Flujo de Import (PDF → documentos)

### Paso 1: Detección del tipo de PDF

Al importar un PDF, antes de cualquier procesamiento:
- Intentar extraer texto de la primera página con pdfrx
- Si el texto extraído tiene sustancia (> 50 caracteres significativos) → PDF editable
- Si devuelve vacío o basura → PDF imagen

### Paso 2a: PDF editable (texto nativo)

- Extraer texto completo directamente con pdfrx (sin OCR, sin conversión)
- Renderizar página 1 como JPG (thumbnail + imagen del documento)
- Guardar como documento normal: JPG + texto ya extraído en `ocr_text`
- `document_type` inferido por keywords del texto (clasificador existente)
- Sin TFLite ni OCR → mucho más rápido

### Paso 2b: PDF imagen (páginas escaneadas)

- Renderizar cada página como JPG con pdfrx
- Cada página → documento independiente en la DB
- Cada JPG pasa por el pipeline normal: TFLite → clasificador → OCR
- Límite: máximo 10 páginas por PDF
  - Si el PDF tiene más de 10 páginas → dialog al usuario:
    "Este PDF tiene N páginas. ¿Importar solo las primeras 10 o elegir cuántas?"

---

## Flujo de Export

### Export documento individual

- Tomar el JPG almacenado del documento
- Generar PDF de una página con pdf_converter_service.dart (ya existe, optimizado)
- Compartir vía share sheet del SO (WhatsApp, mail, etc.)
- El PDF generado es temporal, se borra después de compartir

### Export combinado (multi-selección)

- Usuario selecciona N documentos
- Tomar los N JPGs en el orden seleccionado
- Generar PDF de N páginas (extender pdf_converter_service para multi-página)
- Compartir o guardar en carpeta de descargas
- PDF temporal igual que el individual

---

## Dependencias resultantes

| Paquete | Para qué | Estado |
|---|---|---|
| `pdfrx` | Leer PDF al importar: detectar tipo, extraer texto, renderizar páginas | Mantener |
| `pdf` + `pdf/widgets` | Generar PDF al exportar | Mantener |
| `printing` | Reemplazado por pdfrx para el raster | **Eliminar** |
| `image` | Solo lee headers JPEG en pdf_converter_service | Evaluar |

---

## Archivos

**Existente — conservar:**
- `lib/core/services/pdf_converter_service.dart`
  - Export JPG → PDF (ya implementado y optimizado)
  - Extender para recibir lista de JPGs → PDF multi-página

**A crear cuando se implemente:**
- `lib/features/import/data/services/pdf_import_service.dart`
  - Detección editable vs imagen
  - Extracción de texto directo (PDF editable)
  - Renderizado de páginas a JPG (PDF imagen)
  - Lógica del límite de páginas + dialog

**Eliminado:**
- `lib/core/services/pdf_generator.dart` → borrado (duplicados + sin uso activo)

---

## Orden de implementación sugerido

1. Import PDF imagen (más común, extiende pipeline existente) ✅ IMPLEMENTADO
2. Export individual (extiende pdf_converter_service)
3. Export combinado multi-página
4. Import PDF editable (menos urgente, es un bonus de UX)

---

## Estado: Import PDF imagen — COMPLETADO (Feb 2026)

### Qué se implementó

**Domain:** `PdfImportService` (abstract) + `PdfImportException`
- `getPageCount(pdfPath)` → int
- `renderPagesToJpg(pdfPath, outputDir, {maxPages})` → List<File>

**Data:** `PdfImportServiceImpl` usando pdfrx
- Renderizado a 150 DPI (suficiente para OCR en texto vectorial: sin ruido, bordes nítidos)
- Flujo in-memory sin archivo PNG temporal: pdfrx → dart:ui → PNG bytes en memoria → FlutterImageCompress → JPG (una sola escritura a disco)

**Provider:** dos métodos nuevos en `ImportProvider`
- `checkPdfPageCount(path)` → retorna cantidad de páginas para que la UI decida
- `importPdfPages(path, pagesToImport, locale)` → renderiza y pasa cada página al pipeline existente (TFLite + OCR + BD), con progreso `pdfCurrentPage / pdfTotalPages`
- `PdfImportService` es opcional (nullable) para no romper tests existentes

**UI:** `home_page.dart`
- `_handleImport()` detecta extensión: si es PDF bifurca a `_handlePdfImport()`
- `_handlePdfImport()` pide pageCount, muestra dialog si > 10 páginas (opciones: Primeras 10 / Todas / Cancelar), llama `importPdfPages()`, navega al detalle de la primera página
- Dialog con strings hardcodeados — pendiente mover a claves i18n cuando se internacionalice

**DI:** `PdfImportServiceImpl` inyectado en `ImportProvider` en `main.dart`

### Decisiones técnicas
- 150 DPI elegido sobre 200 DPI: menos presión de memoria, suficiente para MLKit en PDFs digitales
- Cada página → documento independiente en BD (mismo comportamiento que importar N imágenes)
- Si una página falla, las demás se procesan igual (no aborta todo)
- Los JPG temporales renderizados se borran después de procesar cada página
- Pipeline de imagen (TFLite, clasificación, normalización, OCR) sin cambios

### Pendiente de esta etapa
- Mover strings del dialog a claves i18n (`pdf_too_long`, `pdf_import_first_10`, etc.)

La sesión anterior terminó bien — paso 1 (Import PDF imagen) completado y diagrama actualizado.

Estado actual del plan (50_flujo_pdf_editable.md):                                                                                                                                                                               
1. ✅ Import PDF imagen
2. ⏳ Export individual — próximo paso                                                                                                                                                                                           ─
3. ⏳ Export combinado multi-página
4. ⏳ Import PDF editable

  ---
Resumen de lo implementado:

┌─────────────────────────────────┬───────────────────────────────────────────────────┐
│             Archivo             │                      Cambio                       │
├─────────────────────────────────┼───────────────────────────────────────────────────┤
│ a4_normalizer_service.dart      │ Abstract + calculateA4Fit (lógica pura testeable) │
├─────────────────────────────────┼───────────────────────────────────────────────────┤
│ a4_normalizer_service_impl.dart │ Impl con dart:ui: canvas A4 blanco + contain fit  │
├─────────────────────────────────┼───────────────────────────────────────────────────┤
│ pdf_converter_service.dart      │ convertImageBytesToPdfA4() con dimensiones fijas  │
├─────────────────────────────────┼───────────────────────────────────────────────────┤
│ photo_fullscreen_page.dart      │ StatefulWidget + bottom sheet + loading inline    │
├─────────────────────────────────┼───────────────────────────────────────────────────┤
│ pubspec.yaml                    │ share_plus: ^10.1.0                               │
├─────────────────────────────────┼───────────────────────────────────────────────────┤
│ es.json / en.json               │ 5 claves nuevas                                   │
├─────────────────────────────────┼───────────────────────────────────────────────────┤
│ photo_fullscreen_page_test.dart │ Removidos tests del botón print                   │
└─────────────────────────────────┴───────────────────────────────────────────────────┘

El A4FitResult con calculateA4Fit queda disponible para cuando implementemos el export combinado multi-página — cada JPG se normaliza a A4 y después los unimos en un solo PDF.
