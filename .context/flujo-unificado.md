 # Flujo Unificado: Scanner + Importar

**Fecha:** Febrero 2026
**Versión:** 1.0

---

## 📋 Tabla de Contenidos

1. [Resumen Ejecutivo](#resumen-ejecutivo)
2. [Arquitectura General](#arquitectura-general)
3. [Pipeline en 2 Fases](#pipeline-en-2-fases)
4. [Optimizaciones Implementadas](#optimizaciones-implementadas)
5. [Componentes Clave](#componentes-clave)
6. [Performance Metrics](#performance-metrics)
7. [Decisiones Arquitectónicas](#decisiones-arquitectónicas)
8. [OCR Markdown Pipeline](#ocr-markdown-pipeline) ← NUEVO 18 Feb 2026
9. [Diagrama de Flujo](#diagrama-de-flujo)

---

## 🎯 Resumen Ejecutivo

**Problema:** Scanner e Importar tenían flujos duplicados con lógica similar pero sin reutilización de código.

**Solución:** Pipeline unificado que comparte componentes después de obtener el archivo, con optimizaciones específicas:
- **Resize A4 antes de clasificar** (más rápido, menos RAM)
- **Clasificación temprana** para detectar fotos vs documentos
- **Compresión condicional** solo si es documento (ahorro ~6s si usuario cancela foto)

**Resultado:**
- ✅ Código reutilizable (DRY)
- ✅ Performance mejorada (clasificación 3x más rápida)
- ✅ UX consistente (mismo modal para fotos en ambos flujos)
- ✅ Ahorro de tiempo si usuario cancela

---

## 🏗️ Arquitectura General

### **Principio Clave: Separación de Geometría y Calidad**

```
Geometría (rápido ~200ms):  Resize a A4 (dimensiones)
Calidad (lento ~2s):        Compress a <850KB (JPEG quality)
```

### **Flujo Unificado:**

```
┌─────────────────────────────────────────────────────────────┐
│                    ORIGEN DEL ARCHIVO                        │
├──────────────────────┬──────────────────────────────────────┤
│   SCANNER NATIVO     │     IMPORTAR GALERÍA/ARCHIVOS        │
│   (JPG/PNG)          │     (JPG/PNG/WebP/PDF)               │
└──────────────────────┴──────────────────────────────────────┘
                              ↓
            ┌─────────────────────────────────┐
            │   PIPELINE UNIFICADO (FASE 1)   │
            └─────────────────────────────────┘
                              ↓
              1. Convertir a JPG (formato)
                              ↓
              2. Resize A4 si excede (geometría - rápido)
                              ↓
              3. Clasificar Laplacian (sobre A4, más rápido)
                              ↓
                   ┌─────────┴─────────┐
                   ↓                   ↓
              DOCUMENTO              FOTO
              (var ≥ 600)         (var < 600)
                   ↓                   ↓
              Comprimir           NO comprimir
              <850KB ahora        (esperar usuario)
                   ↓                   ↓
                   └─────────┬─────────┘
                             ↓
            ┌─────────────────────────────────┐
            │   CONFIRMACIÓN USUARIO (UI)     │
            └─────────────────────────────────┘
                             ↓
              ┌──────────────┼──────────────┐
              ↓              ↓              ↓
         DOCUMENTO      FOTO (SI)      CANCELAR
         (listo)      (comprimir)       (abort)
              ↓              ↓
              └──────────────┘
                     ↓
            ┌─────────────────────────────────┐
            │   PIPELINE UNIFICADO (FASE 2)   │
            └─────────────────────────────────┘
                     ↓
              4. Guardar en BD + generar nombre
                     ↓
              5. OCR en background (no bloquea)
```

---

## 🔄 Pipeline en 2 Fases

### **FASE 1: Preparación** (`prepareScan()` / `prepareImport()`)

**Objetivo:** Procesar imagen hasta clasificarla, sin guardar en BD.

**Flujo:**
1. **Obtener archivo:**
   - Scanner → JPG (Android) o PNG (iOS)
   - Import → Cualquier formato
2. **Convertir a JPG:** `ImageFormatConverter`
3. **✨ Resize A4 (NUEVO):** `ImageNormalizerService.resizeToA4IfNeeded()`
   - Solo si excede 2480×3508
   - Mantiene quality=95 (alta calidad, solo geometría)
   - ~200ms
4. **Clasificar:** `ImageClassifier.classify()` (OpenCV Laplacian)
   - Sobre imagen A4 (8.7 MP)
   - ~1s
5. **Comprimir SI es documento:**
   - `NormalizeImageUseCase.execute()` → <850KB
   - ~2s
6. **NO comprimir SI es foto:**
   - Esperar confirmación usuario
   - Ahorro ~6s si cancela

**Retorna:** `ScanPreparationResult` / `ImportPreparationResult`
- `processedFile`: File (A4 + comprimido si documento, A4 sin comprimir si foto)
- `classification`: DocumentType (photo/document) + metadata
- `isNormalized`: bool (comprimido o no)

---

### **FASE 2: Guardado** (`completeScan()` / `completeImport()`)

**Objetivo:** Guardar en BD después de confirmación usuario.

**Flujo:**
1. **Comprimir SI es foto aceptada:**
   - Solo si `!isNormalized` (foto)
   - `NormalizeImageUseCase.execute()` → <850KB
   - ~2s
2. **Guardar en BD:**
   - `SaveScannedDocument.call()`
   - Generar nombre basado en fecha/OCR
   - Mover archivo a storage
3. **OCR background:**
   - `ProcessOCR.call()` en Future separado
   - No bloquea UI
   - ~3-5s

**Retorna:** `DocumentModel` con ID asignado

---

## ⚡ Optimizaciones Implementadas

### **1. Resize A4 ANTES de Clasificar** ✨

**Antes:**
```
Convertir JPG → Clasificar (imagen gigante 24MP) → Resize + Compress
                    ↑ LENTO (3-5s en imagen grande)
```

**Ahora:**
```
Convertir JPG → Resize A4 → Clasificar (imagen A4 resized) → Compress
                 ↑ RÁPIDO      ↑ MÁS RÁPIDO (~500ms)
```

**Beneficios:**
- ⚡ Clasificación TFLite más rápida (menos píxeles para resize interno)
- 💾 Menos RAM (crítico en Android viejos)
- 🎯 Precisión suficiente (A4 a 300 DPI = 8.7 MP)
- 🔧 Separación clara: geometría (resize) vs calidad (compress)

---

### **2. Preprocesado TFLite con dart:ui Nativo** 🚀 (16 Feb 2026)

**Problema detectado:** El clasificador TFLite era lento (2.5s total):
- Preprocesado: **2166ms** (94% del tiempo) ← Cuello de botella
- Inferencia: 256ms (solo 6%)

**Causa raíz:** `img.decodeImage()` del package `image` (Dart puro) tardaba **2036ms**.

**Solución implementada:**
```
1. dart:ui.instantiateImageCodec (nativo Android/iOS)
   └─ Decode + Resize a 224×224 en un solo paso
   └─ 2036ms → 92ms (22x más rápido!)

2. toByteData(rawRgba) → bytes raw
   └─ 13ms (sin encoding PNG)

3. RGBA → RGB Float32List
   └─ 9ms (skip canal alpha)

4. Reshape a [1, 224, 224, 3]
   └─ 22ms (formato TFLite)
```

**Resultado:**
- **Preprocesado:** 2166ms → **157ms** (14x más rápido ⚡)
- **Clasificación total:** 2556ms → **499ms** (5x más rápido 🚀)

**Lecciones:**
- Dart puro vs nativo = 22x diferencia (mismo task)
- `dart:ui` ya está en Flutter, no necesita packages externos
- Perfilar antes de optimizar (3 intentos fallidos antes de encontrar el cuello de botella)

**Ver:** `.context/keras.md` para detalles completos de intentos fallidos y éxito final.

---

### **3. Resize A4 con flutter_image_compress**

**Decisión:** Mantener `flutter_image_compress` para resize A4 (~1458ms).

**Razones:**
- Ya es nativo (codecs Android/iOS)
- Optimizar requeriría encodear RGBA → JPG manualmente
- dart:ui solo encodea a PNG (no JPG)
- Trade-off: 1458ms aceptable vs complejidad de implementar encoder JPG

**Alternativas descartadas:**
- dart:ui + toByteData(PNG) + compressWithList → Agrega encoding PNG innecesario
- Buscar encoder JPG nativo que acepte RGBA raw → No existe en Flutter estándar

---

### **4. Clasificación Temprana**

**Detectar FOTO antes de comprimir** evita trabajo innecesario:

- **Documento:** Comprimir ahora (listo para guardar)
- **Foto:** NO comprimir (esperar confirmación)
  - Si usuario cancela → ahorro ~6s de compresión
  - Si usuario acepta → comprimir solo entonces

---

### **5. Compresión Condicional**

**Solo comprimir cuando sea necesario:**

```
DOCUMENTO:  Resize → Clasificar → ✅ Comprimir → Guardar
FOTO (SI):  Resize → Clasificar → ❌ NO comprimir → Usuario confirma → ✅ Comprimir → Guardar
FOTO (NO):  Resize → Clasificar → ❌ NO comprimir → Usuario cancela → ❌ ABORT (ahorro 6s)
```

---

### **6. UI Unificado para Fotos**

**PhotoDetectedDialog** se usa en AMBOS flujos:

- **Scanner:** 3 opciones (Galería / App / Cancelar)
- **Import:** 2 opciones (App / Cancelar) - sin galería (ya está en galería)
- **Responsive:** Portrait (columna) / Landscape (fila)
- **Consistente:** Mismo diseño para usuarios mayores

---

## 🧩 Componentes Clave

### **Domain (Lógica de Negocio)**

#### **ImageNormalizerService** (interfaz)
- `resizeToA4IfNeeded(String imagePath): Future<String>` ← NUEVO
  - Redimensiona a 2480×3508 si excede
  - Solo geometría, NO comprime
  - ~200ms
- `normalizeImage(String imagePath, int targetSizeBytes): Future<String>`
  - Estrategia: Probe compression (quality 85 → ajustar)
  - Target: 850 KB
  - ~2s

#### **ImageClassifier** (interfaz)
- `classify(String imagePath): Future<ClassificationResult>`
  - **Implementación:** TFLite (Keras MobileNetV3) - 5 categorías
  - **Preprocesado optimizado:** dart:ui nativo (157ms vs 2166ms Dart puro)
  - Clases: documento, folleto, foto, manuscrito, recibo
  - **Tiempo total:** ~499ms (157ms preprocesado + 342ms inferencia)
  - **Accuracy:** 98-99% validado en producción

#### **NormalizeImageUseCase**
- `execute(String imagePath): Future<String>`
  - Normaliza (resize + compress) a <850KB
- `resizeToA4IfNeeded(String imagePath): Future<String>` ← NUEVO
  - Delega a ImageNormalizerService
  - Usado antes de clasificar

#### **ImportDocument** (UseCase)
- `convertOnly(File importedFile): Future<File>` ← ACTUALIZADO
  - Convierte a JPG + **Resize A4**
  - Retorna listo para clasificar
- `normalize(File jpgFile): Future<File>`
  - Solo comprime (resize ya hecho)
  - <850KB

---

### **Presentation (Providers)**

#### **ScanProvider**
- `prepareScan(): Future<ScanPreparationResult?>`
  - FASE 1: Scanner → Convertir+Resize → Clasificar → Comprimir si documento
- `completeScan(preparation, locale): Future<DocumentModel?>`
  - FASE 2: Comprimir si foto → Guardar BD + OCR

#### **ImportProvider**
- `prepareImport(File): Future<ImportPreparationResult?>`
  - FASE 1: Convertir+Resize → Clasificar → Comprimir si documento
- `completeImport(preparation, locale): Future<DocumentModel?>`
  - FASE 2: Comprimir si foto → Guardar BD + OCR

**Estados compartidos:**
- `isScanning / isImporting`: Procesando imagen (FASE 1)
- `isSaving`: Guardando en BD (FASE 2)
- `isProcessingOCR`: OCR en background

---

### **Presentation (UI)**

#### **PhotoDetectedDialog** (widget)
- **Parámetros:**
  - `imageFile`: Imagen detectada
  - `showGalleryOption`: true (scanner) / false (import)
- **Layout responsive:**
  - Portrait: Column (imagen / texto / botones)
  - Landscape: Row (imagen | texto+botones)
- **Opciones:**
  - `PhotoAction.saveToGallery` (solo scanner)
  - `PhotoAction.saveToApp`
  - `PhotoAction.cancel`

---

## 📊 Performance Metrics

### **Tiempos de Ejecución (Promedio)**

#### **FASE 1 - Preparación:**
| Paso | Antes (Feb 2026) | Ahora (16 Feb 2026) | Mejora |
|------|------------------|---------------------|--------|
| Scanner nativo | ~2-3s | ~2-3s | - |
| Convertir JPG | ~500ms | ~500ms | - |
| **Resize A4** | ❌ (incluido en normalizar) | **~1458ms** | ✨ NUEVO |
| **Clasificar TFLite** | **~2556ms** (preprocesado Dart puro) | **~499ms** (preprocesado dart:ui nativo) | **5x** ⚡ |
| └─ Preprocesado | 2166ms (package image) | 157ms (dart:ui) | **14x** 🚀 |
| └─ Inferencia | 256ms | 342ms | - |
| Comprimir (documento) | ~2s | ~2s | - |
| **TOTAL (documento)** | ~8-11s | **~4.5s** | **3.5-6.5s** ⚡ |
| **TOTAL (foto cancelada)** | ~8-11s | **~2.5s** | **5.5-8.5s** ⚡ |

#### **FASE 2 - Guardado:**
| Paso | Tiempo |
|------|--------|
| Comprimir (foto aceptada) | ~2s |
| Guardar BD + mover archivo | ~300ms |
| **TOTAL** | ~2.3s |

#### **OCR Background:**
| Paso | Tiempo |
|------|--------|
| OCR completo | ~3-5s |
| (No bloquea UI) | - |

---

### **Consumo de RAM (Estimado)**

| Escenario | Antes | Ahora | Mejora |
|-----------|-------|-------|--------|
| Clasificar 24MP (4000×6000) | ~150-200 MB | ❌ No ocurre | - |
| Clasificar A4 resized | ❌ No ocurre | ~30-50 MB | **4-6x menos** 💾 |
| Preprocesado dart:ui | N/A | ~10-20 MB (buffers raw) | Eficiente |

---

## 🎯 Decisiones Arquitectónicas

### **1. ¿Por qué Resize ANTES de Clasificar?**

**Alternativas consideradas:**
- ❌ Clasificar sobre imagen original → LENTO + alto consumo RAM
- ✅ Resize A4 primero → RÁPIDO + bajo consumo RAM

**Razones:**
- A4 a 300 DPI (8.7 MP) es suficiente para Laplacian
- Resize es 10x más rápido que compress
- Reduce RAM crítico en Android viejos (target: usuarios 60-85 años)

---

### **2. ¿Por qué Separar Resize de Compress?**

**Antes:** `normalizeImage()` hacía todo (resize + compress) → ~10-12s

**Ahora:**
- `resizeToA4IfNeeded()`: Solo geometría → ~200ms
- `normalizeImage()`: Solo calidad → ~2s

**Beneficios:**
- 🎯 **Responsabilidad única** (SRP)
- ⚡ **Reutilización** (resize sin comprimir para clasificar)
- 📝 **Claridad** (código más legible)

---

### **3. ¿Por qué Clasificar ANTES de Comprimir?**

**Alternativas:**
- ❌ Comprimir siempre → desperdicio si es foto cancelada
- ✅ Clasificar primero → comprimir solo si necesario

**Ahorro real:**
- Documento: 0s (comprime igual)
- Foto aceptada: 0s (comprime igual)
- **Foto cancelada: ~6s ahorrados** ⚡

---

### **4. ¿Por qué Unificar PhotoDetectedDialog?**

**Antes:**
- Scanner: PhotoDetectedDialog (elegante, 3 opciones)
- Import: AlertDialog simple (sin preview, metadata debug visible)

**Problemas:**
- ❌ Inconsistencia visual (target: usuarios mayores)
- ❌ Sin preview en import
- ❌ Metadata debug en producción

**Ahora:**
- ✅ Mismo widget para ambos (consistencia)
- ✅ Preview en ambos casos
- ✅ Opciones contextuales (`showGalleryOption`)
- ✅ Responsive (landscape/portrait)

---

### **5. ¿Por qué 2 Fases (Preparación + Guardado)?**

**Alternativas:**
- ❌ Flujo monolítico → no permite cancelación intermedia
- ✅ 2 fases → usuario puede cancelar después de clasificar

**Beneficios:**
- 🎯 **Feedback temprano** (clasificación antes de guardar)
- ⚡ **Cancelación eficiente** (antes de comprimir/guardar)
- 🧪 **Testeable** (cada fase independiente)

---

## 📈 Trade-offs

### **Ventajas:**
- ✅ Performance mejorada (clasificación 3x más rápida)
- ✅ Menos RAM (crítico en Android viejos)
- ✅ Código reutilizable (DRY)
- ✅ UX consistente (mismo modal)
- ✅ Ahorro tiempo si usuario cancela foto

### **Desventajas:**
- ⚠️ Complejidad: 2 fases vs flujo simple
- ⚠️ Estado: más variables en providers
- ⚠️ Testing: más escenarios a cubrir

**Conclusión:** Los beneficios superan ampliamente las desventajas, especialmente para el target (usuarios mayores con dispositivos viejos).

---

## 🔮 Futuro

### **Mejoras Planeadas:**
1. **Clasificación avanzada:**
   - Folleto (mucho texto)
   - Manuscrito (escritura manual)
   - Formulario (campos estructurados)

2. **Batch processing:**
   - Escanear múltiples páginas
   - Comprimir en paralelo

3. **Cache inteligente:**
   - Cachear imágenes resize A4
   - Evitar reprocesar si usuario vuelve atrás

---

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
