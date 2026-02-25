# Épica 6 - PASO 1: Arquitectura JPG-First (COMPLETADO)

**Fecha:** 2026-02-04 → 2026-02-05
**Estado:** ✅ COMPLETADO - PHASE 1 (JPG-only)
**Prioridad:** CRÍTICA - Performance para usuarios mayores (60-85 años)

---

## 🎯 Evolución del Objetivo

### Problema Inicial (2026-02-04)
App funcionaba pero era **extremadamente lenta**:
- UI congelada durante escaneo
- Pantallas negras
- Progress indicators congelados
- Procesamiento innecesario bloqueando UI thread

### Solución Final (2026-02-05)
**Arquitectura JPG-First:** Guardar solo JPG, eliminar toda generación de PDF/thumbnails automáticos.

---

## 📊 Flujo FINAL Implementado (PHASE 1)

### Flujo Simplificado (JPG-only)

```
1. Usuario escanea documento
   ↓
2. Scanner nativo retorna JPG (~600-700 KB)
   ↓
3. Guardar en DB:
   - filePath = JPG permanente
   - thumbnailPath = JPG (mismo archivo)
   - Sin generación de thumbnail
   - Sin conversión a PDF
   ↓
4. [BACKGROUND] OCR desde JPG (6-10s)
   ↓
5. [BACKGROUND] Actualizar DB con texto OCR
   ↓
6. LISTO ✅

PDF on-demand (FUTURO - PHASE 2):
- Solo al compartir/imprimir
- Usar PdfConverterService optimizado (JPG directo)
```

### Ventajas vs Flujo Anterior

| Aspecto | ANTES (Paso 0) | AHORA (Phase 1) | Mejora |
|---------|----------------|-----------------|--------|
| **Guardar documento** | ~2,600ms (thumbnail) | ~160ms | **94% más rápido** ⚡ |
| **Conversión PDF** | ~14,800ms (bloqueante) | 0ms (eliminado) | **100% eliminado** 🚀 |
| **Storage por doc** | JPG + PDF (~7 MB) | Solo JPG (~600 KB) | **91% menos** 💾 |
| **Frames saltados** | 56 frames | 38 frames | **32% menos** ✅ |
| **Pantalla negra** | ~1s | <100ms | **90% reducida** ✨ |
| **UI bloqueada** | Thumbnail + PDF | Ninguna | **100% desbloqueada** 🎉 |

---

## 🗂️ Archivos Modificados (PHASE 1)

### 1. Save Document Use Case
**Archivo:** `lib/features/scan/domain/usecases/save_scanned_document.dart`

**Cambios:**
- ❌ **ELIMINADO:** PDFGenerator dependency
- ❌ **ELIMINADO:** Generación de thumbnail
- ✅ **SIMPLIFICADO:** filePath y thumbnailPath apuntan al mismo JPG
- ✅ **RESULTADO:** De ~2.6s a ~160ms (94% más rápido)

**Código clave:**
```dart
// ANTES:
final thumbnailFile = await _pdfGenerator.generateThumbnail(...);
final document = DocumentModel(
  filePath: scannedFile.path,
  thumbnailPath: thumbnailFile.path,  // Thumbnail separado
);

// AHORA:
final document = DocumentModel(
  filePath: scannedFile.path,           // JPG permanente
  thumbnailPath: scannedFile.path,      // Mismo JPG
);
```

### 2. Process OCR Use Case
**Archivo:** `lib/features/scan/domain/usecases/process_ocr.dart`

**Cambios:**
- ❌ **ELIMINADO:** PdfConverterService dependency
- ❌ **ELIMINADO:** Conversión JPG→PDF automática (~14.8s)
- ❌ **ELIMINADO:** Borrado de JPG
- ✅ **SIMPLIFICADO:** Solo OCR + clasificación + DB update

**Código clave:**
```dart
// ANTES:
await _ocrService.extractText(jpgFile);         // 7.5s
await _pdfConverter.convertJpgToPdf(...);       // 14.8s ← ELIMINADO
await jpgFile.delete();                         // ← ELIMINADO
await _repository.updateDocument(withPdfPath);  // ← ELIMINADO

// AHORA:
await _ocrService.extractText(jpgFile);         // 7.5s
await _repository.updateDocument(withOcrText);  // Solo OCR
// JPG permanece como archivo maestro
```

### 3. Dependency Injection
**Archivo:** `lib/main.dart`

**Cambios:**
- ❌ **ELIMINADO:** PDFGeneratorImpl instantiation
- ❌ **ELIMINADO:** PdfConverterServiceImpl instantiation
- ✅ **SIMPLIFICADO:** SaveScannedDocument sin PDFGenerator
- ✅ **SIMPLIFICADO:** ProcessOCR sin PdfConverter

### 4. Document Card (Thumbnail Display)
**Archivo:** `lib/features/documents/presentation/widgets/document_card.dart`

**Cambios:**
- ✅ **OPTIMIZADO:** Agregado `cacheWidth: 200`
- ✅ **RESULTADO:** Carga eficiente de JPG en thumbnails (200px en lugar de 1800px)

**Código clave:**
```dart
Image.file(
  thumbnailFile,
  width: 80,
  height: 80,
  cacheWidth: 200,  // ← NUEVO: Decode at 200px for efficiency
  fit: BoxFit.contain,
)
```

### 5. Documents List Page (Navigation)
**Archivo:** `lib/features/documents/presentation/pages/documents_list_page.dart`

**Cambios:**
- ✅ **OPTIMIZADO:** Eliminado `await` en loadDocuments después de escanear
- ✅ **RESULTADO:** Lista aparece inmediatamente sin bloquear UI
- ✅ **RESULTADO:** Pantalla negra reducida de ~1s a <100ms

**Código clave:**
```dart
// ANTES:
await documentsProvider.loadDocuments();  // Bloqueaba UI ~100ms

// AHORA:
documentsProvider.loadDocuments();  // Sin await - background load
```

### 6. Photo Fullscreen Page (Viewer)
**Archivo:** `lib/features/documents/presentation/pages/photo_fullscreen_page.dart`

**Cambios:**
- ✅ **DOCUMENTADO:** Arquitectura JPG-first
- ✅ **PREPARADO:** TODOs para share/print on-demand PDF conversion

**Código clave:**
```dart
/// NOTA: Ahora los documentos se almacenan como JPG por defecto.
/// PDF solo se genera on-demand para compartir/imprimir.

void _shareDocument(BuildContext context) {
  // TODO: Si es JPG, convertir a PDF on-demand antes de compartir
}

void _printDocument(BuildContext context) {
  // TODO: Si es JPG, convertir a PDF on-demand antes de imprimir
}
```

---

## 🔧 Estado del Conversor JPG→PDF

### PdfConverterService (Optimizado, On-Demand)

**Archivo:** `lib/core/services/pdf_converter_service.dart`

**Estado:** ✅ **OPTIMIZADO** pero **NO usado automáticamente**

**Optimización realizada:**
- ✅ Embebe JPG directo en PDF (sin decodificar a PNG)
- ✅ 98.9% más rápido: de 14,831ms a 166-408ms
- ✅ 90% menos storage: de 6.5 MB a 526-681 KB
- ✅ Mantiene calidad original del JPG

**Uso futuro (PHASE 2):**
- Al compartir documento → convertir JPG→PDF on-demand
- Al imprimir documento → convertir JPG→PDF on-demand
- Opcionalmente: cachear PDF generado temporalmente

**Código optimizado:**
```dart
// Optimización clave: Embed JPG directly
final jpgBytes = await jpgFile.readAsBytes();
final pdfImage = pw.MemoryImage(jpgBytes);  // JPG directo, no PNG

// Solo leer headers para dimensiones (no full decode)
final decoder = img.JpegDecoder();
final imageInfo = decoder.startDecode(jpgBytes);

// PDF del mismo tamaño que imagen
final pageFormat = PdfPageFormat(
  imageInfo.width.toDouble(),
  imageInfo.height.toDouble(),
  marginAll: 0,
);

pdf.addPage(pw.Page(
  pageFormat: pageFormat,
  build: (pw.Context context) => pw.Image(pdfImage, fit: pw.BoxFit.fill),
));
```

---

## 📈 Resultados PHASE 1

### Performance Medido (Logs Reales)

**Test Run - 2026-02-05:**
```
Scanner nativo:        17,240ms (incluye tiempo usuario)
Guardar documento:        159ms ✅ (antes: 2,600ms)
────────────────────────────────
Flujo hasta guardar:  17,399ms (UI desbloqueada)

[Background] OCR:     10,753ms (primera ejecución - cold start)
                       ~7,500ms (ejecuciones subsecuentes)
```

**Comparación Before/After:**

| Métrica | ANTES | DESPUÉS | Mejora |
|---------|-------|---------|--------|
| Guardar documento | 2,600ms | 159ms | **94% más rápido** |
| PDF conversion | 14,800ms | 0ms | **100% eliminado** |
| Total user-facing | 18,385ms | 17,399ms | **5% más rápido** |
| Frames saltados | 56 | 38 | **32% menos** |
| Storage por doc | ~7 MB | ~600 KB | **91% menos** |

### Experiencia de Usuario

**ANTES:**
```
1. Presionar ESCANEAR
2. Tomar foto (scanner nativo)
3. Presionar "Siguiente"
4. ⚫ PANTALLA NEGRA ~1 segundo
5. Ver lista (documento agregado)
6. [Background] OCR 7s con indicador
```

**AHORA:**
```
1. Presionar ESCANEAR
2. Tomar foto (scanner nativo)
3. Presionar "Siguiente"
4. ⚡ Pantalla negra <100ms (solo transición nativa)
5. Ver lista inmediatamente (documento agregado)
6. [Background] OCR 7s con indicador
```

---

## 🚀 PHASE 2 - Próximos Pasos (On-Demand PDF)

### Objetivos PHASE 2

1. **Implementar conversión JPG→PDF on-demand** para share/print
2. **Investigar opciones para pantalla negra remanente**

### Tareas PHASE 2

#### 1. Share/Print con PDF On-Demand

**Archivos a modificar:**
- `photo_fullscreen_page.dart` - Implementar _shareDocument y _printDocument
- Usar `PdfConverterService` existente (ya optimizado)
- Opcionalmente: cachear PDF temporalmente en scratchpad

**Flujo propuesto:**
```dart
void _shareDocument(BuildContext context) async {
  final isPdf = filePath.endsWith('.pdf');

  String fileToShare;
  if (isPdf) {
    fileToShare = filePath;
  } else {
    // Convertir JPG→PDF on-demand
    final pdfConverter = PdfConverterServiceImpl();
    final pdfPath = await pdfConverter.convertJpgToPdf(
      File(filePath),
      outputDirectory,
      'shared_${DateTime.now().millisecondsSinceEpoch}',
    );
    fileToShare = pdfPath;
  }

  // Compartir usando share_plus
  await Share.shareXFiles([XFile(fileToShare)]);
}
```

#### 2. Reducir Pantalla Negra Remanente

**Opciones a explorar:**

**Opción A: Cambiar color de fondo del Theme**
- Cambiar scaffold background de negro a color de la app
- Transición menos brusca visualmente

**Opción B: Splash/Loading overlay**
- Mostrar un overlay con logo/spinner mientras scanner cierra
- Ocultar la transición nativa

**Opción C: Mantener scaffold persistente**
- Usar overlay para scanner en lugar de navegación
- Evitar completamente la transición de Activity

**Recomendación:** Empezar con Opción A (más simple), luego evaluar si es necesario Opción B/C.

---

## 🔍 Decisiones Arquitecturales Clave

### 1. JPG como Archivo Maestro
**Decisión:** Mantener JPG permanentemente, generar PDF solo on-demand.

**Razones:**
- JPG es suficiente para visualización en app
- PDF solo necesario para compartir/imprimir (casos de uso externos)
- Ahorro masivo de storage (91% menos)
- Evita procesamiento bloqueante en flujo principal

### 2. Mismo JPG para FilePath y ThumbnailPath
**Decisión:** Usar mismo archivo para documento y thumbnail.

**Razones:**
- Flutter optimiza carga con `cacheWidth` parameter
- Elimina 2.6s de generación de thumbnail
- Storage más eficiente (un solo archivo)
- Calidad superior (thumbnail es JPG original, no comprimido extra)

### 3. Eliminar await en loadDocuments
**Decisión:** Cargar lista en background después de escanear.

**Razones:**
- Reduce pantalla negra de ~1s a <100ms
- UI responde inmediatamente
- Lista se actualiza automáticamente cuando carga termina
- Mejor UX para usuarios mayores (menos espera percibida)

### 4. cacheWidth en Image.file()
**Decisión:** Decodificar thumbnails a 200px en lugar de resolución completa.

**Razones:**
- Ahorra memoria RAM (crítico en dispositivos antiguos)
- Más rápido para mostrar lista con muchos documentos
- Thumbnail se ve igual visualmente (80dp → 200px @ 2.5x DPI)

### 5. PdfConverterService Optimizado Pero Inactivo
**Decisión:** Mantener servicio optimizado pero no usarlo automáticamente.

**Razones:**
- Servicio está listo para share/print on-demand
- Optimización (embed JPG directo) ya implementada y validada
- Fácil activar cuando se necesite
- No agrega complejidad al flujo principal

---

## 📝 Logs de Performance (Referencia)

### Test 1 - Sin Flash
```
[SaveScannedDocument] Guardado (JPG only) - 86ms
[ProcessOCR] OCR extractText - 7,429ms
[ProcessOCR] Update DB - 24ms
Total OCR: 7,507ms
```

### Test 2 - Con Flash (Cold Start OCR)
```
[SaveScannedDocument] Guardado (JPG only) - 159ms
[ProcessOCR] OCR extractText - 10,420ms (loading models)
[ProcessOCR] Update DB - 50ms
Total OCR: 10,753ms
```

**Nota:** OCR más lento en cold start por carga de modelos TensorFlow. Subsecuentes ejecuciones ~7.5s.

---

## 🧪 Testing

### Validación Manual en Dispositivo Real

**Dispositivo:** Moto G52 (Android, target user: 60-85 años)

**Resultados:**
- ✅ Escaneo fluido sin congelamientos
- ✅ Lista aparece inmediatamente (<100ms pantalla negra)
- ✅ Thumbnails cargan rápido con cacheWidth
- ✅ OCR background no bloquea UI
- ✅ Storage eficiente (~600 KB por doc vs ~7 MB antes)
- ✅ Indicador de progreso visible durante OCR
- ⚠️ Pantalla negra remanente <100ms (transición scanner nativo - inevitable)

### Tests Pendientes PHASE 2

- [ ] Share con conversión JPG→PDF on-demand
- [ ] Print con conversión JPG→PDF on-demand
- [ ] Cacheo temporal de PDFs generados
- [ ] Opciones para reducir pantalla negra remanente

---

## 🎉 Conclusión PHASE 1

**Estado:** COMPLETADO exitosamente.

**Logros:**
1. ✅ Arquitectura JPG-First implementada
2. ✅ 94% más rápido guardando documentos
3. ✅ 100% eliminada conversión PDF bloqueante
4. ✅ 91% menos storage por documento
5. ✅ 90% reducida pantalla negra (de ~1s a <100ms)
6. ✅ UI 100% desbloqueada durante procesamiento
7. ✅ PdfConverterService optimizado y listo para on-demand

**Próximos Pasos:** PHASE 2 (Share/Print on-demand + reducir pantalla negra remanente)

---

**Fin del documento - PHASE 1 completado exitosamente. 🎉**
**Última actualización:** 2026-02-05
