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
8. [Diagrama de Flujo](#diagrama-de-flujo)

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

### **1. Resize A4 ANTES de Clasificar** ✨ (NUEVO)

**Antes:**
```
Convertir JPG → Clasificar (imagen gigante 24MP) → Resize + Compress
                    ↑ LENTO (3-5s en imagen grande)
```

**Ahora:**
```
Convertir JPG → Resize A4 → Clasificar (imagen A4 8.7MP) → Compress
                 ↑ RÁPIDO      ↑ MÁS RÁPIDO (1s)
```

**Beneficios:**
- ⚡ Clasificación 3x más rápida (menos píxeles)
- 💾 Menos RAM (crítico en Android viejos)
- 🎯 Precisión suficiente (A4 a 300 DPI = 8.7 MP)
- 🔧 Separación clara: geometría (resize) vs calidad (compress)

---

### **2. Clasificación Temprana**

**Detectar FOTO antes de comprimir** evita trabajo innecesario:

- **Documento:** Comprimir ahora (listo para guardar)
- **Foto:** NO comprimir (esperar confirmación)
  - Si usuario cancela → ahorro ~6s de compresión
  - Si usuario acepta → comprimir solo entonces

---

### **3. Compresión Condicional**

**Solo comprimir cuando sea necesario:**

```
DOCUMENTO:  Resize → Clasificar → ✅ Comprimir → Guardar
FOTO (SI):  Resize → Clasificar → ❌ NO comprimir → Usuario confirma → ✅ Comprimir → Guardar
FOTO (NO):  Resize → Clasificar → ❌ NO comprimir → Usuario cancela → ❌ ABORT (ahorro 6s)
```

---

### **4. UI Unificado para Fotos**

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
  - Método: OpenCV Laplacian variance
  - Threshold: 600
  - Varianza < 600 → FOTO
  - Varianza ≥ 600 → DOCUMENTO
  - ~1s sobre imagen A4

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
| Paso | Antes | Ahora | Mejora |
|------|-------|-------|--------|
| Scanner nativo | ~2-3s | ~2-3s | - |
| Convertir JPG | ~500ms | ~500ms | - |
| **Resize A4** | ❌ (incluido en normalizar) | **~200ms** | ✨ NUEVO |
| **Clasificar** | **~3-5s** (imagen gigante) | **~1s** (A4) | **3-5x** ⚡ |
| Comprimir (documento) | ~2s | ~2s | - |
| **TOTAL (documento)** | ~8-11s | ~6-7s | **2-4s** ⚡ |
| **TOTAL (foto cancelada)** | ~8-11s | ~4s | **4-7s** ⚡ |

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
| Clasificar 8.7MP (A4) | ❌ No ocurre | ~50-70 MB | **3x menos** 💾 |

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

## 📚 Referencias

- **MEMORY.md**: Decisiones históricas del proyecto
- **compressor.txt**: Detalles de Probe Compression strategy
- **clasificador.md**: Implementación OpenCV Laplacian
- **opencv.md**: Integración nativa OpenCV

---

**Última actualización:** Febrero 2026
**Autor:** Equipo EscanDoc
**Versión:** 1.0
