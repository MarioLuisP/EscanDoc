# Pipeline EscanDoc - Flujo Visual

**Fecha:** 16 Febrero 2026
**Versión:** 2.0 - Flujo optimizado SIN resize A4 previo

---

## 📊 Flujo Completo Optimizado  (diagrama ASCII)

```
┌─────────────────────────────────────────────────────────────┐
│                    ORIGEN DEL ARCHIVO                       │
├──────────────────────┬──────────────────────────────────────┤
│   SCANNER NATIVO     │     IMPORTAR GALERÍA/ARCHIVOS        │
│   (JPG/PNG)          │     (JPG/PNG/WebP/PDF/HEIC)          │
│   ~2-3s              │     Instantáneo (file picker)        │
└──────────────────────┴──────────────────────────────────────┘
                              ↓
            ┌─────────────────────────────────┐
            │   1. CONVERTIR A JPG            │
            │   ImageFormatConverter          │
            ├─────────────────────────────────┤
            │ • JPG → pass-through (~13ms)    │
            │ • PNG → JPG (~500-1000ms)       │
            │ • PDF → render + JPG (~1-2s)    │
            │ • WebP/HEIC → JPG (~500ms)      │
            │ ⚠️  SIN RESIZE (original)       │
            └─────────────────────────────────┘
                              ↓
            ┌─────────────────────────────────┐
            │   2. CLASIFICAR IMAGEN          │
            │   TFLiteImageClassifier         │
            ├─────────────────────────────────┤
            │ • Procesa original (~12.5MP)    │
            │ • dart:ui resize a 224×224      │
            │ • Preprocesado: ~614ms          │
            │   - Decode+Resize (419ms)       │
            │   - Extract RGBA (33ms)         │
            │   - RGBA→RGB Float32 (41ms)     │
            │   - Reshape (21ms)              │
            │ • Inferencia: ~665ms            │
            │ • TOTAL: ~1367ms                │
            └─────────────────────────────────┘
                              ↓
                   ┌──────────┴──────────┐
                   ↓                     ↓
         ┌─────────────────┐   ┌─────────────────┐
         │   DOCUMENTO     │   │      FOTO       │
         │  (99% conf.)    │   │   (99% conf.)   │
         └─────────────────┘   └─────────────────┘
                   ↓                     ↓
    ┌──────────────────────┐   ┌──────────────────────┐
    │ 3a. NORMALIZAR AHORA │   │ 3b. THUMBNAIL PREVIEW│
    │ Resize A4 + Compress │   │ ThumbnailGenerator   │
    ├──────────────────────┤   ├──────────────────────┤
    │ • Resize A4 si excede│   │ • dart:ui nativo     │
    │ • Target: 850 KB     │   │ • Target: 200px width│
    │ • Tiempo: ~2s        │   │ • Decode+resize 188ms│
    │ • Probe Q85 → ajuste │   │ • Encode JPG 142ms   │
    └──────────────────────┘   │ • TOTAL: ~361ms      │
                   ↓            │ • Size: ~10.5 KB     │
                   │            └──────────────────────┘
                   │                      ↓
                   │            ┌─────────┴─────────┐
                   │            ↓                   ↓
                   │      ┌────────────┐    ┌────────────┐
                   │      │ DESDE      │    │  DESDE     │
                   │      │ SCANNER    │    │  IMPORT    │
                   │      └────────────┘    └────────────┘
                   │            ↓                   ↓
                   │  ┌──────────────────┐ ┌──────────────────┐
                   │  │  📱 MODAL 3 OPC  │ │  📱 MODAL 2 OPC  │
                   │  │ PhotoDetected    │ │ PhotoDetected    │
                   │  ├──────────────────┤ ├──────────────────┤
                   │  │ • Guardar galería│ │ • Guardar en app │
                   │  │ • Guardar en app │ │ • Cancelar       │
                   │  │ • Cancelar       │ │                  │
                   │  │ (preview 200px)  │ │ (preview 200px)  │
                   │  └──────────────────┘ └──────────────────┘
                   │            ↓                   ↓
                   │      ┌─────┴──────┬────────────┘
                   │      ↓            ↓            ↓
                   │  ┌────────┐  ┌────────┐  ┌────────┐
                   │  │GALERÍA │  │  APP   │  │CANCELA │
                   │  └────────┘  └────────┘  └────────┘
                   │      ↓            ↓            ↓
                   │  ┌────────┐  ┌────────┐  ┌────────┐
                   │  │ Guardar│  │Normalizr│  │ ❌ABORT│
                   │  │ en gal │  │Resize A4│  │Cleanup │
                   │  │ + ABORT│  │Compress │  └────────┘
                   │  └────────┘  │  ~2s    │
                   │              └────────┘
                   │                   ↓
                   └───────────────────┘
                                ↓
            ┌─────────────────────────────────┐
            │   4. GUARDAR EN BD              │
            │   SaveScannedDocument           │
            ├─────────────────────────────────┤
            │ • Generar nombre (fecha/OCR)    │
            │ • Mover archivo a storage       │
            │ • Insertar documento en BD      │
            │   - documentType = tfliteClass  │
            │ • Crear nota automática         │
            │   "Clasificado como: X (99%)"   │
            │ • Tiempo: ~300ms                │
            └─────────────────────────────────┘
                                ↓
            ┌─────────────────────────────────┐
            │   5. OCR BACKGROUND             │
            │   ProcessOCR (no bloquea UI)    │
            ├─────────────────────────────────┤
            │ • google_mlkit_text_recognition │
            │ • extractAnalysis(jpg,          │
            │     docType: tfliteClass)       │
            │                                 │
            │ blocksToMarkdown(blocks,        │
            │   documentTypeFromString(type)) │
            │ ┌───────────────────────────┐  │
            │ │ 1. imageSize desde bboxes │  │
            │ │ 2. Rotación por mediana   │  │
            │ │    FIX: normalizar < 0    │  │
            │ │    -90° → 270° (CW ✓)    │  │
            │ │    +90° → 90°  (CCW ✓)   │  │
            │ │ 3. Coords transformadas   │  │
            │ │ 4. Clustering columnas    │  │
            │ │ 5a. documento/manuscrito  │  │
            │ │     → # heading, listas   │  │
            │ │ 5b. factura/recibo        │  │
            │ │     + 2 cols → tabla MD   │  │
            │ └───────────────────────────┘  │
            │                                 │
            │ OcrAnalysis(text: markdown,     │
            │   blockCount, avgConfidence)    │
            │ • Tiempo: ~3-5s                 │
            └─────────────────────────────────┘
                                ↓
            ┌─────────────────────────────────┐
            │   6. REFINAMIENTO (background)  │
            │   RefineClassification          │
            ├─────────────────────────────────┤
            │ Solo ajusta 'documento' y       │
            │ 'manuscrito' (resto intocable)  │
            │                                 │
            │ avgConf < 0.55                  │
            │   → manuscrito                  │
            │ avgConf ≥ 0.55                  │
            │   → documento                   │
            │   + keywords + bloques > 80     │
            │     → factura                   │
            │                                 │
            │ Si hubo cambio →                │
            │   • documentType actualizado   │
            │   • título regenerado           │
            │   • nota automática             │
            │     "X → Y (2° paso: motivo)"  │
            │                                 │
            │ Nota extracto (150 chars):      │
            │ strip # ## - | --- del markdown │
            │ → texto plano legible en BD     │
            └─────────────────────────────────┘
                                ↓
            ┌─────────────────────────────────┐
            │   7. RENDER UI                  │
            │   flutter_markdown_plus         │
            ├─────────────────────────────────┤
            │ OcrPreviewSection               │
            │   MarkdownBody(data: ocrText)   │
            │   (30% altura, scroll)          │
            │                                 │
            │ OcrFullscreenPage               │
            │   Markdown(selectable: true)    │
            │   (fullscreen, scrollbar)       │
            └─────────────────────────────────┘
                                ↓
                          ✅ LISTO
```

---

## ⏱️ Tiempos Totales por Escenario

### **Documento JPG (flujo completo):**
```
Convertir (13ms) + Clasificar (1367ms) + Normalizar (2000ms) +
Guardar (300ms) = ~3.7s
+ OCR background (3-5s, no bloquea)

Mejora vs flujo anterior: -0.6s (elimina resize A4 previo)
```

### **Documento PNG (flujo completo):**
```
Convertir PNG→JPG (1000ms) + Clasificar (1367ms) + Normalizar (2000ms) +
Guardar (300ms) = ~4.7s
+ OCR background (3-5s, no bloquea)

Mejora vs flujo anterior: -0.6s
```

### **Foto JPG ACEPTADA (scanner/import):**
```
Convertir (13ms) + Clasificar (1367ms) + Thumbnail (361ms) +
[Usuario acepta "Guardar en App"] + Normalizar (2000ms) +
Guardar (300ms) = ~4.0s
+ OCR background (3-5s, no bloquea)

Mejora vs flujo anterior: +0.4s (agrega thumbnail, pero elimina resize A4)
```

### **Foto JPG CANCELADA:**
```
Convertir (13ms) + Clasificar (1367ms) + Thumbnail (361ms) +
[Usuario cancela] = ~1.8s
(Ahorro: 2.2s al no normalizar ni guardar)

Mejora vs flujo anterior: -0.2s (thumbnail añade 361ms, pero ahorra resize A4 1458ms)
```

### **Foto JPG → GALERÍA (scanner only):**
```
Convertir (13ms) + Clasificar (1367ms) + Thumbnail (361ms) +
[Usuario elige "Guardar en Galería"] + Gal.putImage (200ms) = ~1.9s
(No normaliza, no guarda en BD)

Feature oculta para usuarios que capturan fotos accidentalmente
```

---

## 🎯 Optimizaciones Aplicadas (v2.0)

### **1. Clasificador TFLite con dart:ui nativo** ⚡
- **Antes:** Loops manuales (for anidados, getPixel) = 2300ms
- **Ahora:** dart:ui decode+resize nativo = 614ms
- **Mejora:** -73% (3.7x más rápido)
- **Cambio:** Usa `ui.instantiateImageCodec` con `targetWidth: 224`

### **2. Eliminado resize A4 previo** 🚫
- **Antes:** Resize A4 (1458ms) → Clasificar (499ms) = 1957ms
- **Ahora:** Clasificar original 12.5MP (1367ms) = 1367ms
- **Mejora:** -590ms si usuario acepta, -1458ms si cancela
- **Razón:** TFLite hace su propio resize a 224×224, no necesita A4 previo

### **3. Thumbnail optimizado con una decodificación** 📸
- **Antes:** Doble decodificación (12.5MP completo + resize 400px) = 1137ms
- **Ahora:** Una sola decodificación (dart:ui targetWidth: 200) = 361ms
- **Mejora:** -68% (3.15x más rápido)
- **Cambio:** Eliminada primera decodificación para obtener dimensiones

---

## 📊 Comparativa de Performance

### Pipeline completo (FOTO cancelada):
```
                        Antes    Ahora    Mejora
──────────────────────────────────────────────
Convertir JPG           13ms     13ms     =
Resize A4 previo      1458ms      0ms    -100%
Clasificar             499ms   1367ms     -73%*
Thumbnail 400px       1137ms    361ms     -68%
──────────────────────────────────────────────
TOTAL                 2914ms   1778ms     -39%

* Clasificar tarda más porque procesa 12.5MP en vez de 9.2MP A4,
  pero el preprocesado es 3.7x más rápido (dart:ui vs loops)
```

### Pipeline completo (DOCUMENTO):
```
                        Antes    Ahora    Mejora
──────────────────────────────────────────────
Convertir JPG           13ms     13ms     =
Resize A4 previo      1458ms      0ms    -100%
Clasificar             499ms   1367ms     -73%*
Normalizar (A4+comp)  2000ms   2000ms     =
Guardar                300ms    300ms     =
──────────────────────────────────────────────
TOTAL (sin OCR)       4270ms   3680ms     -14%

* Ahorro neto: 590ms
```

---

## 🔥 Cuellos de Botella Actuales

1. **Normalización (Resize A4 + Compress):** ~2000ms
   - Solo si es documento O si usuario acepta foto
   - Ya optimizado con Probe Compression (4-7x más rápido que iterativo)

2. **Clasificación TFLite:** ~1367ms
   - Procesa imagen original 12.5MP (~3072×4080)
   - Preprocesado dart:ui ya optimizado (614ms)
   - Inferencia del modelo (665ms) - no optimizable sin cambiar modelo

3. **Conversión PNG→JPG:** ~1000ms
   - Solo si formato no es JPG
   - Usa flutter_image_compress (nativo)

---

## 📝 Notas Técnicas

### **Clasificador TFLite:**
- Modelo: Keras Sequential exportado a TFLite
- Input: [1, 224, 224, 3] float32 en rango [0, 255] (SIN normalización)
- Output: [1, 5] float32 (probabilidades softmax)
- Categorías: documento, folleto, foto, manuscrito, recibo
- Optimización: dart:ui `instantiateImageCodec` con targetWidth/targetHeight

### **Thumbnail Generator:**
- Tamaño: 200px width (aspect ratio automático)
- Formato: JPG @ quality 85
- Implementación: dart:ui decode+resize + flutter_image_compress encode
- Uso: Preview en modal PhotoDetectedDialog (solo fotos)

### **Normalización:**
- Resize A4: 2480×3508 @ 300 DPI (si excede)
- Compress: Target 850 KB con Probe Compression
- Estrategia: Probe Q85 → medir → ajustar (lineal down, exponencial up)

### **Modal de fotos:**
- Scanner: 3 opciones (Galería, App, Cancelar)
- Import: 2 opciones (App, Cancelar) - ya está en galería
- Preview: Thumbnail 200px (10.5 KB, ~361ms generación)

---

## 🚀 Próximas Optimizaciones Potenciales

1. **Clasificador en GPU:** Usar GPU delegate de TFLite (~2-3x más rápido)
2. **Modelo cuantizado:** INT8 en vez de FLOAT32 (~2x más rápido, -4x tamaño)
3. **Background classification:** Clasificar mientras usuario revisa scanner
4. **Cache de codecs:** Reutilizar dart:ui codecs para mismas dimensiones
5. **HEIF en Android 12+:** Reemplazar JPG por HEIF (~50% menos tamaño)

---

**Versión:** 2.1 - Flujo con refinamiento de clasificación post-OCR
**Performance:** 39% más rápido que v1.0 en caso de foto cancelada
**Mantenibilidad:** ✅ Tests actualizados, providers unificados, código limpio


## 📝 OCR Markdown Pipeline

**Fecha:** 18 Febrero 2026

### **Problema**

`OCRServiceImpl.extractAnalysis()` retornaba `recognizedText.text` — texto plano desordenado que ML Kit concatena sin respetar jerarquía ni rotación del documento.

### **Solución**

Conectar `blocksToMarkdown()` al pipeline OCR para generar Markdown estructurado real:

```
ML Kit blocks → blocksToMarkdown(blocks, docType) → Markdown estructurado
     ↓                                                        ↓
  texto plano                                    headings, listas, tablas
  desordenado                                    según tipo de documento
```

### **Diagrama del nuevo flujo OCR**

```
ProcessOCR.call(documentId, tfliteClass)
         ↓
extractAnalysis(jpgFile, docType: tfliteClass)
         ↓
  ML Kit processImage()
         ↓
  blocksToMarkdown(blocks, documentTypeFromString(docType))
  ┌─────────────────────────────────────────────────────┐
  │  1. Calcular imageSize desde max de bboxes          │
  │  2. Detectar rotación (mediana de ángulos)          │
  │     ⚠️ FIX: normalizar ángulos negativos primero    │
  │     (-90° → 270°, no 270° < 45° = deg0)            │
  │  3. Aplanar a _Line con coords transformadas        │
  │  4. Clustering de columnas                          │
  │  5. Renderizar según docType:                       │
  │     - documento/folleto/manuscrito → secuencial     │
  │       (# heading si caps grande, ## si caps medio)  │
  │     - factura/recibo + 2+ columnas → tabla Markdown │
  └─────────────────────────────────────────────────────┘
         ↓
  OcrAnalysis(text: markdown, blockCount, avgConfidence)
         ↓
  RefineClassification (2° paso)
         ↓
  _buildPrintedNote(markdown)  ← strip prefijos # ## ### - | ---
         ↓
  DB: ocrText = markdown, nota = texto limpio (150 chars)
```

### **Archivos involucrados**

| Archivo | Rol |
|---------|-----|
| `lib/core/services/blocks_to_markdown.dart` | Movido desde `lib/`, + `documentTypeFromString()` |
| `lib/core/services/ocr_service.dart` | `extractAnalysis({docType})` + llama `blocksToMarkdown` |
| `lib/features/scan/domain/usecases/process_ocr.dart` | Pasa `docType: tfliteClass`, strip markdown en nota |

### **UI: Markdown rendering**

| Widget | Antes | Ahora |
|--------|-------|-------|
| `OcrPreviewSection` | `Text(ocrText)` | `MarkdownBody(data: ocrText)` |
| `OcrFullscreenPage` | `TextField(readOnly: true)` | `Markdown(selectable: true)` |

Dependencia agregada a `pubspec.yaml`:
```yaml
flutter_markdown_plus: ^1.0.7
```

### **Bug fix: Rotación en _detectRotation**

**Problema:** ML Kit reporta `-90°` para rotación CW. El código normalizaba sobre `[0, 360)` con:
```dart
if (median >= 315 || median < 45) return _Rotation.deg0;
```
→ `-90 < 45` → clasificado como `deg0` → rotación ignorada completamente.

**Fix aplicado** (`lib/core/services/blocks_to_markdown.dart`):
```dart
// Normalizar negativos ANTES de calcular la mediana
final normalized = angles.map((a) => a < 0 ? a + 360 : a).toList();
```

**Resultado:**
- `-90°` → `270°` → cae en `[225, 315)` → `_Rotation.deg270` ✓ (rotación CW)
- `+90°` → `90°` → cae en `[45, 135)` → `_Rotation.deg90` ✓ (rotación CCW)

### **Nota sobre la nota de extracto**

`_buildPrintedNote` ahora recibe Markdown y lo limpia antes de truncar:
```dart
final stripped = markdown
    .replaceAll(RegExp(r'^#{1,3}\s+', multiLine: true), '')   // # ## ###
    .replaceAll(RegExp(r'^[-*]\s+', multiLine: true), '')       // listas
    .replaceAll(RegExp(r'\|', multiLine: true), ' ')            // tablas
    .replaceAll(RegExp(r'^---+$', multiLine: true), '')         // separadores
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
```
La nota en BD siempre es texto plano legible (máx 150 chars).

---

## 📚 Referencias

- **MEMORY.md**: Decisiones históricas del proyecto
- **compressor.txt**: Detalles de Probe Compression strategy
- **keras.md**: Clasificador TFLite + Optimización preprocesado dart:ui (NUEVO 16 Feb 2026)

---

**Última actualización:** 18 Febrero 2026
**Autor:** Equipo EscanDoc
**Versión:** 1.2 - OCR Markdown Pipeline + fix rotación ángulos negativos
