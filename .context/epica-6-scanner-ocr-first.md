# Épica 6: Scanner OCR-First

**Fecha inicio:** 2026-02-03
**Estado:** 🧪 Spike completado - Listo para implementación
**Prioridad:** ALTA - Mejora crítica para OCR (core de la app)

---

## 🎯 Objetivo

**Cambiar el flujo de escaneo para priorizar OCR** (el corazón de la app) en lugar de PDF.

### Motivación

OCR es lo más importante porque de ahí se extrae:
- ✅ Categoría del documento
- ✅ Nombre amigable automático
- 🔜 Fecha de vencimiento (futuro)
- 🔜 Monto de vencimiento (futuro)

PDF es secundario - se puede generar al guardar en db.

---

## 📊 Flujo Actual (Ineficiente)

```
Usuario escanea
  ↓
flutter_doc_scanner → PDF guardado en DB
  ↓
Extracción temporal: PDF → Imagen PNG (150 DPI, ~35 MB)
  ↓
ML Kit OCR procesa imagen temporal
  ↓
Guardar texto OCR en DB
  ↓
Eliminar imagen temporal
```

**Problemas:**
❌ Conversión PDF→Imagen (procesamiento extra)
❌ Imagen temporal muy grande (35 MB)
❌ Pérdida de calidad en conversión
❌ OCR depende de extracción de PDF

---


---

## 🧪 Resultados del Spike

### Test 1: `getScanDocuments()` - Retorna PDF

```
Tipo: Map
Keys: [pdfUri, pageCount]

Resultado:
{
  "pdfUri": "file:///.../260219357880881.pdf",
  "pageCount": 1
}
```

**Conclusión:** Solo retorna PDF, NO sirve para OCR-first.

---

### Test 2: `getScannedDocumentAsImages()` - Retorna JPG/PNG

```
Tipo: Map
Keys: [images, count, Uri, Count]

Resultado:
{
  "images": ["file:///.../260920317995033.jpg"],
  "count": 1,
  "Uri": ["file:///.../260920317995033.jpg"],  // Duplicado
  "Count": 1                                    // Duplicado
}
```

**Conclusión:** Retorna paths de imágenes (JPG en Android, PNG en iOS).

---

### Test 3: Análisis Profundo JPG ✅

**Documento A4, iluminación media:**

```
✅ Archivo existe: true
✅ Path: /data/user/0/.../261787841901767.jpg
✅ Tamaño: 0.50 MB (515 KB) = 527,281 bytes
✅ Formato: JPG válido (firma JFIF: ff d8 ff e0 00 10 4a 46 49 46)
✅ Listo para ML Kit OCR
```

**Conclusión Android:** JPG de ~515 KB es perfecto para OCR.

---

## 🚨 Problema Crítico Descubierto

### Crash con Archivos Grandes

**Observación:**
- ❌ App crashea con archivos de apenas **1.2 MB** (OutOfMemoryError)
- ✅ Funciona bien con **~515 KB**

**Causa:**
- Target: personas mayores con dispositivos posiblemente antiguos
- Poca RAM disponible
- 1.2 MB comprimido = ~5-10 MB descomprimido en memoria
- ML Kit OCR requiere memoria adicional
- **Total:** ~15-20 MB solo para una imagen → OutOfMemoryError

### iOS: Problema Adicional

**Documentación de `flutter_doc_scanner`:**
- Android: Retorna **JPG** (~515 KB) ✅
- iOS: Retorna **PNG** (~1-2 MB o más) ❌

**PNG vs JPG para A4:**
- JPG: ~515 KB (compresión con pérdida)
- PNG: ~2-5 MB (sin compresión, lossless)

**Implicación:**
- iOS generará archivos mucho más grandes
- Mayor riesgo de crashes
- Inconsistencia cross-platform

---

## ✅ Solución Decidida: Normalización Iterativa

### Estrategia de Normalización

**NO tocar píxeles - Solo ajustar calidad de compresión JPG**

#### Parámetros

```
Target: 650 KB (margen de seguridad)
Límite mínimo calidad: 70
Step iteración: 5 puntos
Calidades: [90, 85, 80, 75, 70]
```

#### Algoritmo Android (JPG)

```
Si tamaño > 650 KB:
  Comprimir JPG con calidad 90
  Si aún > 650 KB → calidad 85
  Si aún > 650 KB → calidad 80
  Si aún > 650 KB → calidad 75
  Si aún > 650 KB → calidad 70
  Si aún > 650 KB → FALLBACK (redimensionar 80% + calidad 85)
```

#### Algoritmo iOS (PNG)

```
Convertir PNG → JPG con calidad 90
Si tamaño > 650 KB:
  Comprimir JPG con calidad 85
  Si aún > 650 KB → calidad 80
  Si aún > 650 KB → calidad 75
  Si aún > 650 KB → calidad 70
  Si aún > 650 KB → FALLBACK (redimensionar 80% + calidad 85)
```

### Ventajas del Enfoque

✅ **Preserva resolución** - Todos los píxeles originales
✅ **Calidad adaptativa** - Solo comprime lo necesario
✅ **Simple** - Un solo parámetro (calidad JPG)
✅ **Cross-platform** - Normaliza Android + iOS
✅ **Previene crashes** - Tamaño controlado
✅ **Optimiza almacenamiento** - DB más liviana

### Fallback para Edge Cases

Si con calidad 70 aún supera 650 KB:
1. Redimensionar a 80% del ancho original
2. Comprimir con calidad 85
3. Guardar resultado

---

## 📁 Archivos del Spike

Ubicación: `lib/features/scanner_custom/spike/`

### 1. `scanner_spike_page.dart`
- Spike técnico de `cunning_document_scanner` (Plan B)
- **Estado:** No probado aún
- **Propósito:** Alternativa si `flutter_doc_scanner` no funciona

### 2. `scanner_native_debug_page.dart` ✅
- Debug de `flutter_doc_scanner` (scanner actual)
- **Tests implementados:**
  - TEST 1: `getScanDocuments()` → retorna PDF
  - TEST 2: `getScannedDocumentAsImages()` → retorna imágenes
  - TEST 3: Análisis profundo JPG → verifica tamaño, calidad, firma
- **Estado:** Completado con éxito
- **Rutas agregadas en main.dart:**
  - `/spike/scanner` → ScannerSpikePage
  - `/spike/native-debug` → ScannerNativeDebugPage

### 3. Diagnósticos SQLite
- `lib/core/database/diagnostics_page.dart`
- `lib/core/database/sqlite_diagnostics.dart`
- **Propósito:** Diagnosticar problemas FTS
- **Ruta:** `/diagnostics`

---

## 🔧 Dependencias Necesarias

**Ya instaladas:**
- ✅ `flutter_doc_scanner` - Scanner nativo
- ✅ `google_mlkit_text_recognition` - OCR
- ✅ `image` - Procesamiento de imágenes (redimensionado, compresión)
- ✅ `pdf` - Generación de PDFs

**No se necesitan dependencias nuevas.**

---

## ⚠️ Consideraciones Importantes

### 2. Thumbnail

**Actualmente:** Se genera del PDF.

**Con nuevo flujo:**
- Thumbnail se genera de la imagen guardada (más fácil)
- Misma imagen para OCR + thumbnail
- Redimensionar a tamaño thumbnail (~200px ancho)

### 3. Performance

**Normalización añade tiempo de procesamiento:**
- Iteración de calidad puede tardar 1-2 segundos
- Mostrar indicador de progreso al usuario
- Ejecutar en background (como OCR actual)

---


## 📝 Notas Finales

**Este flujo OCR-first es la decisión correcta porque:**

1. **OCR es el corazón de la app** - Todo depende de la calidad del OCR
2. **Imagen directa es superior** - Sin pérdida de conversión
3. **Normalización previene crashes** - Crítico para target (personas mayores, dispositivos antiguos)
5. **Cross-platform consistente** - Mismo comportamiento Android/iOS

**El spike confirmó la viabilidad técnica. Ahora toca implementar.**

---

**Fin del documento. Listo para implementación. 🚀**
