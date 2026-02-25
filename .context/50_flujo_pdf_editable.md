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

1. Import PDF imagen (más común, extiende pipeline existente)
2. Export individual (extiende pdf_converter_service)
3. Export combinado multi-página
4. Import PDF editable (menos urgente, es un bonus de UX)
