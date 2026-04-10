# Pipeline EscanDoc - Flujo Visual

**Fecha:** 16 Febrero 2026
**Versión:** 2.0 - Flujo optimizado SIN resize A4 previo


```
┌──────────────────────────────────────────────────────────────────────┐
│                         ORIGEN DEL ARCHIVO                           │
├──────────────────────┬───────────────────────┬───────────────────────┤
│   SCANNER NATIVO     │  IMPORTAR IMAGEN      │   IMPORTAR PDF        │
│   (JPG/PNG)          │  (JPG/PNG/WebP/HEIC)  │   (multi-página)      │
│   ~2-3s              │  Instantáneo          │   Instantáneo         │
└──────────────────────┴───────────────────────┴───────────────────────┘
         ↓                        ↓                        ↓
         │                        │          ┌─────────────────────────┐
         │                        │          │  0. DETECCIÓN PDF       │
         │                        │          │  PdfImportServiceImpl   │
         │                        │          ├─────────────────────────┤
         │                        │          │ isEditablePdf():        │
         │                        │          │ extraer texto pág 0     │
         │                        │          │ > 50 chars → editable   │
         │                        │          │ Si > 10 pág → dialog    │
         │                        │          └─────────────────────────┘
         │                        │            ↓            ↓         ↓
         │                        │     ┌──────┴───┐ ┌──────┴──┐ ┌───┴──────┐
         │                        │     │ EDITABLE │ │ IMAGEN  │ │ IMAGEN   │
         │                        │     │ (texto   │ │ MULTI   │ │ 1 PÁGINA │
         │                        │     │ nativo)  │ │ PÁGINA  │ │          │
         │                        │     └──────────┘ └─────────┘ └──────────┘
         │                        │          ↓            ↓              ↓
         │                        │  ┌───────────┐ ┌──────────┐         │
         │                        │  │render JPG │ │render JPG│         │
         │                        │  │pdfrx 150  │ │pdfrx 150 │         │
         │                        │  │DPI in-mem │ │DPI in-mem│         │
         │                        │  │extractText│ │          │         │
         │                        │  │por página │ │          │         │
         │                        │  └───────────┘ └──────────┘         │
         │                        │          ↓            ↓              │
         │                        │  ┌───────────┐ ┌──────────┐         │
         │                        │  │completePdf│ │completePdf         │
         │                        │  │Page() sin │ │Page() sin│         │
         │                        │  │TFLite     │ │TFLite    │         │
         │                        │  │customTitle│ │customTitle         │
         │                        │  │= nombre_n │ │= nombre_n│         │
         │                        │  └───────────┘ └──────────┘         │
         │                        │          ↓            ↓              │
         │                        │  ┌───────────┐ ┌──────────┐         │
         │                        │  │OCR back-  │ │OCR back- │         │
         │                        │  │ground con │ │ground con│         │
         │                        │  │preExtract-│ │skipRefine│         │
         │                        │  │edText +   │ │ment=true │         │
         │                        │  │skipRefine │ │          │         │
         │                        │  │ment=true  │ │          │         │
         │                        │  └───────────┘ └──────────┘         │
         │                        │       ↓ BD          ↓ BD             │
         │                        │       └─────────────┘                │
         │                        │             ✅ FIN PDF              │
         │                        │          (no sigue pipeline)         │
         └────────────────────────┴──────────────────────────────────────┘
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
            │ • Si customTitle → usa ese      │
            │   nombre (PDF multipágina)      │
            │ • Si no → genera por fecha/tipo │
            │ • Mover archivo a storage       │
            │ • Insertar documento en BD      │
            │   - documentType = tfliteClass  │
            │ • Tiempo: ~300ms                │
            └─────────────────────────────────┘
                                ↓
            ┌─────────────────────────────────┐
            │   5. OCR BACKGROUND             │
            │   ProcessOCR (no bloquea UI)    │
            ├─────────────────────────────────┤
            │ • 1er pass OCR                  │
            │   extractAnalysis(jpg,          │
            │     docType: tfliteClass)       │
            │                                 │
            │   Dentro de extractAnalysis:    │
            │   detectOrientationDegrees()    │
            │   → detected (0/90/180/270)     │
            │   rotationCorrection =          │
            │     (360 - detected) % 360      │
            │   Si rotación == 0:             │
            │     blocksToMarkdown(...)       │
            │   Si rotación != 0:             │
            │     markdown = '' ← descartado  │
            │                                 │
            │ • Si rotación != 0°:            │
            │   → rotateImage(jpg, degrees)   │
            │     (~200ms, JPEG nativo)       │
            │   → re-classify TFLite (~280ms) │
            │   → 2do pass OCR (con md)       │
            │                                 │
            │ blocksToMarkdown(               │
            │   blocks, docType, detected)    │
            │ ┌───────────────────────────┐  │
            │ │ 1. imageSize desde bboxes │  │
            │ │ 2. Coords transformadas   │  │
            │ │    (rotación ya conocida) │  │
            │ │ 3. totalReadWidth de      │  │
            │ │    TODAS las líneas       │  │
            │ │ 4. Separar wideLines      │  │
            │ │    (ancho>50% AND CAPS)   │  │
            │ │    de narrowLines         │  │
            │ │ 5. maxCapsHeight = max    │  │
            │ │    readHeight de CAPS     │  │
            │ │ 6. Bandas: wideLines como │  │
            │ │    divisores verticales   │  │
            │ │    → _renderBand() por   │  │
            │ │      banda de narrowLines │  │
            │ │      · factura/recibo     │  │
            │ │        + cols → tabla |  │  │
            │ │      · otros + cols      │  │
            │ │        → inline \t\t     │  │
            │ │      · 1 col → secuencial│  │
            │ │    Jerarquía CAPS:        │  │
            │ │    ≥80% maxH → #         │  │
            │ │    ≥50% maxH → ##        │  │
            │ │    resto    → ###        │  │
            │ └───────────────────────────┘  │
            │                                 │
            │ OcrAnalysis(text: markdown,     │
            │   blockCount, avgConfidence,    │
            │   detectedRotationDegrees)      │
            │ • Tiempo: ~3-5s (sin rotar)     │
            │           ~4-6s (con rotación)  │
            └─────────────────────────────────┘
                                ↓
            ┌──────────────────────────────────────┐
            │   6. REFINAMIENTO (background)       │
            │   RefineClassification               │
            ├──────────────────────────────────────┤
            │ foto → intocable                     │
            │                                      │
            │ recibo / folleto:                    │
            │   keywords + >80 bloques → factura   │
            │   folleto + aspectRatio > 2.0        │
            │     → recibo                         │
            │   si no → sin cambio                 │
            │                                      │
            │ documento / manuscrito:              │
            │   avgConf < 0.72?                    │
            │     blocks ≤15 Y chars ≤250          │
            │       → manuscrito                   │claude
            │     si no (impreso mala calidad)     │
            │       → sigue abajo ↓                │
            │   aspectRatio > 2.0 → recibo         │
            │   keywords + >80 bloques → factura   │
            │   si no → documento                  │
            │                                      │
            │ Umbrales (Mar 2026):                 │
            │   avgConf threshold:   0.72          │
            │   maxBlocks manuscrito: 15           │
            │   maxChars manuscrito: 250           │
            │   minAspectRatio recibo: 2.0         │
            │   minBlocks factura:    80           │
            │                                      │
            │ Si wasReclassified:                  │
            │   rebuildMarkdown(refinedKind)       │
            │   → regenera MD con tipo real        │
            │     (síncrono, usa last blocks)      │
            │   • documentType actualizado         │
            │   • título regenerado                │
            │                                      │
            │ Nota extracto (150 chars):           │
            │ strip # ## - | --- del markdown      │
            │ → texto plano legible en BD          │
            └──────────────────────────────────────┘
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


════════════════════════════════════════
         FLUJO DE EXPORT PDF
════════════════════════════════════════

DocumentsListPage
─────────────────
Long-press en item → modo selección
  │  Tap items → toggle ☑/☐
  │  Header: "N seleccionados" + ✕
  │
  ├─ [Eliminar] (≥1 seleccionado)
  │     ↓
  │   bottom sheet confirmación 3D
  │     ↓
  │   repository.deleteDocuments()
  │     ✅ FIN
  │
  └─ [Crear PDF] (≥2 seleccionados)
        ↓
     PdfOrderPage
     ─────────────────────────────────
     Lista documentos seleccionados
     con número de posición + miniatura
     + título + fecha
     Botones ▲ ▼ por item
     (primer item: ▲ deshabilitado)
     (último item: ▼ deshabilitado)
        ↓ [Exportar PDF (N)]
     ─────────────────────────────────
     convertJpgsToPdf(jpgPaths, tmpPath)
       PdfConverterService
       PdfPageFormat.a4 + BoxFit.contain
       → margen blanco si no es A4
       → una página por documento
        ↓
     Share sheet del SO
     (WhatsApp, mail, Drive, etc.)
        ↓
     addPostFrameCallback:
       Navigator.pop() → vuelve a lista
     (temporal en getTemporaryDirectory,
      el SO limpia — no borrar a mano)

     Nombre: EscanDoc_{día}{MesAbrev}.pdf
     Ej: EscanDoc_22Mar.pdf
     (claves i18n de meses ya existentes)
     ─────────────────────────────────
     ← (back) → vuelve a lista
               CON selección preservada
```

---

## ⏱️ Tiempos Totales por Escenario

### **Documento JPG (flujo completo):**
```
Convertir (13ms) + Clasificar (1367ms) + Normalizar (2000ms) +
Guardar (300ms) = ~3.7s
+ OCR background (3-5s sin rotar / 4-6s con rotación, no bloquea)
```

### **Documento PNG (flujo completo):**
```
Convertir PNG→JPG (1000ms) + Clasificar (1367ms) + Normalizar (2000ms) +
Guardar (300ms) = ~4.7s
+ OCR background (3-5s sin rotar / 4-6s con rotación, no bloquea)
```

### **Foto JPG ACEPTADA (scanner/import):**
```
Convertir (13ms) + Clasificar (1367ms) + Thumbnail (361ms) +
[Usuario acepta "Guardar en App"] + Normalizar (2000ms) +
Guardar (300ms) = ~4.0s
+ OCR background (3-5s sin rotar / 4-6s con rotación, no bloquea)
```

### **Foto JPG CANCELADA:**
```
Convertir (13ms) + Clasificar (1367ms) + Thumbnail (361ms) +
[Usuario cancela] = ~1.8s
(Ahorro: 2.2s al no normalizar ni guardar)
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
  detectOrientationDegrees(allAngles)   ← document_orientation_service.dart
    normaliza negativos → mediana → 0/90/180/270
         ↓
  rotationCorrection = (360 - detected) % 360
         ↓
  Si rotationCorrection == 0:
    blocksToMarkdown(blocks, docType, detected)
    ┌─────────────────────────────────────────────────────┐
    │  1. imageSize desde max de bboxes                   │
    │  2. Coords transformadas (rotación ya conocida)     │
    │  3. totalReadWidth de TODAS las líneas              │
    │  4. Separar wideLines (ancho>50% AND ALL_CAPS)      │
    │     de narrowLines                                  │
    │  5. maxCapsHeight = max readHeight de líneas CAPS   │
    │  6. Bandas: wideLines como divisores verticales     │
    │     Por cada banda de narrowLines → _renderBand():  │
    │       · factura/recibo + múltiples cols → tabla |  │
    │       · otros + múltiples cols → inline \t\t       │
    │       · 1 columna → secuencial por readTop          │
    │     Jerarquía ALL_CAPS: ≥80% → #, ≥50% → ##, ###  │
    └─────────────────────────────────────────────────────┘
  Si rotationCorrection != 0:
    markdown = ''  ← se descartaría, no se genera
         ↓
  OcrAnalysis(text: markdown, blockCount, avgConfidence,
              detectedRotationDegrees: rotationCorrection)
         ↓
  Si detectedRotationDegrees != 0:
    rotateImage(jpg) → re-classify → 2do extractAnalysis
         ↓
  RefineClassification (2° paso)
         ↓
  Si wasReclassified:
    rebuildMarkdown(refinedKind)  ← síncrono, reutiliza _lastRecognized
    → regenera MD con tipo correcto (ej: doc→recibo activa tabla)
         ↓
  _buildPrintedNote(markdown)  ← strip prefijos # ## ### - | ---
         ↓
  DB: ocrText = markdown, nota = texto limpio (150 chars)
```

### **Archivos involucrados**

| Archivo | Rol |
|---------|-----|
| `lib/core/services/blocks_to_markdown.dart` | Convierte blocks ML Kit → Markdown. Recibe `rotationDegrees` pre-calculado. |
| `lib/core/services/document_orientation_service.dart` | `detectOrientationDegrees()` — mediana de ángulos ML Kit |
| `lib/core/services/ocr_service.dart` | `extractAnalysis()` + `rebuildMarkdown()` (cachea `_lastRecognized`) |
| `lib/features/scan/domain/usecases/process_ocr.dart` | Orquesta pipeline: 1er OCR → rotación → 2do OCR → refinamiento → rebuild MD |

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

**Última actualización:** 9 Marzo 2026
**Autor:** Equipo EscanDoc
**Versión:** 1.5 - blocksToMarkdown con wide/narrow separation, maxCapsHeight, rebuildMarkdown post-refinamiento


Listo. Ahora el log solo muestra:
═══════════════════════════════════════                                    
BLOQUES: 19
═══════════════════════════════════════                                                                                                                                                                                             
Cuando quieras ver la jerarquía completa, descomentá el bloque que empieza en // print('OCR DEBUG - texto plano completo:') hasta el final de la función (son las líneas con // dentro de _logOCRStructure).                     
Update(lib\core\services\ocr_service.dart)
⎿  Added 35 lines, removed 35 lines
                                                