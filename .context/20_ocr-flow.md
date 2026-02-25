# Flujo OCR - EscanDoc

**Última actualización:** 2026-02-02 (Migración FTS5→FTS4, fix OutOfMemoryError)
**Estado:** ✅ Funcionando correctamente
**Propósito:** Referencia rápida del flujo de OCR post-escaneo para futuras sesiones

**Cambios recientes (2 Feb 2026):**
- ✅ Migrado de FTS5 a FTS4 para compatibilidad con más dispositivos Android
- ✅ Resuelto OutOfMemoryError reduciendo DPI de 300 a 150 en imagen temporal OCR
- ⚠️ Tests con FTS pendientes (sqflite_common_ffi no tiene FTS en Windows)

---

## Stack OCR

- **Scanner:** flutter_doc_scanner (UI nativa)
- **Text OCR:** google_mlkit_text_recognition
- **Barcode:** barcode_scanning

---

## Flujo Completo

```
Usuario presiona ESCANEAR
  ↓
Scanner nativo captura imagen
  ↓
OCR procesa texto
  ↓
Clasificar documento
  ↓
Generar nombre automático
  ↓
Guardar en BD
```

---

## Archivos Clave por Capa

### **Feature: Scan**

#### Domain Layer
- `lib/features/scan/domain/usecases/scan_and_save_document.dart`
  - UseCase principal del flujo de escaneo
  - Orquesta: scanner → guardar → OCR background

- `lib/features/scan/domain/usecases/process_ocr.dart`
  - UseCase que procesa OCR después de guardar
  - Recibe documentId, carga imagen de BD, ejecuta extractores, actualiza documento

- `lib/features/scan/domain/usecases/extract_text_from_image.dart`
  - Extractor de texto usando ML Kit Text Recognition
  - Recibe path de imagen, retorna String con texto extraído

- `lib/features/scan/domain/usecases/extract_barcode_from_image.dart`
  - Extractor de códigos de barras
  - Recibe path de imagen, retorna String con barcode (si existe)

#### Data Layer
- `lib/features/scan/data/repositories/scanner_repository_impl.dart`
  - Implementación del repositorio de scanner
  - Usa flutter_doc_scanner para captura nativa

#### Presentation Layer
- `lib/features/scan/presentation/providers/scan_provider.dart`
  - Provider que coordina el escaneo
  - Método clave: `scanAndSave()` → llama a ScanAndSaveDocument
  - Método: `_processOCRInBackground()` → ejecuta ProcessOCR sin await (fire-and-forget)
  - Estado: `_isProcessingOCR` indica si OCR está ejecutándose

---

### **Feature: Documents**

#### Data Layer
- `lib/features/documents/data/models/document_model.dart`
  - Modelo de documento con campos:
    - `imagePath` - ruta de la imagen escaneada
    - `ocrText` - texto extraído por OCR (puede ser null)
    - `barcode` - código de barras (si existe)

- `lib/features/documents/data/repositories/documents_repository_impl.dart`
  - Implementación del repositorio de documentos
  - Métodos: insert, update, getById, getAll
  - Usa SQLite directamente

#### Presentation Layer
- `lib/features/documents/presentation/providers/documents_provider.dart`
  - Provider de gestión de documentos
  - Método: `selectDocument(id)` carga documento de BD una sola vez
  - Estado: `_selectedDocument` es el documento actualmente visto

- `lib/features/documents/presentation/pages/document_detail_page.dart`
  - Página de detalle del documento
  - Muestra 3 secciones: Imagen, Nota, OCR
  - Carga documento llamando `selectDocument()` en initState

- `lib/features/documents/presentation/pages/documents_list_page.dart`
  - Lista de documentos
  - Método: `_handleScan()` ejecuta scanProvider.scanAndSave() y luego loadDocuments()

---

## Base de Datos

- `lib/core/database/database_helper.dart`
  - Gestión de SQLite + FTS4 (búsqueda full-text)
  - Tabla `documents` tiene columnas:
    - `file_path` TEXT (ruta del PDF)
    - `ocr_text` TEXT (nullable)
    - `barcode` TEXT (nullable - preparado para futuro)
  - Tablas virtuales FTS4: `documents_fts`, `notes_fts`

---

## Puntos de Integración

### **Escaneo → OCR**
1. `ScanProvider.scanAndSave()` ejecuta `ScanAndSaveDocument`
2. `ScanAndSaveDocument` guarda documento y retorna
3. `ScanProvider._processOCRInBackground()` ejecuta `ProcessOCR` en background
4. `ProcessOCR` carga imagen desde `imagePath`, ejecuta extractores, actualiza documento

### **OCR → BD**
- `ProcessOCR.call()` actualiza documento usando `DocumentsRepository.updateDocument()`
- Actualiza campos `ocrText` y `barcode`

### **BD → UI**
- `DocumentsProvider.selectDocument()` carga documento de BD
- `DocumentDetailPage` muestra `_selectedDocument.ocrText`
- Widget de OCR en `document_detail_page.dart` (líneas ~190-210)

---

## ✅ Solución Implementada

### **OCR Funcional**
- Scanner captura PDF → Se extrae página como PNG (150 DPI) → ML Kit procesa → Guarda en BD
- El flujo completo funciona correctamente
- OCR se ejecuta en background sin bloquear UI
- Texto extraído se guarda en campo `ocrText` de la tabla `documents`

### **Extracción Temporal de Imagen**
- PDF se convierte a PNG temporalmente en directorio scratchpad
- Se usa para OCR con ML Kit Text Recognition
- Archivo temporal se elimina automáticamente después del procesamiento
- No requiere almacenamiento permanente de imagen adicional

---

## ✅ Migración de FTS5 a FTS4 (2 Feb 2026)

### **Problema Original**
Muchos dispositivos Android (ej: Moto G52 API 33) NO tienen FTS5 habilitado:
- Motorola y otros fabricantes compilan SQLite sin FTS5
- Error: `no such module: fts5` al crear tablas virtuales
- FTS4 SÍ está disponible en estos dispositivos (desde 2010)

### **Solución Implementada**
Migración completa de FTS5 → FTS4:
- Cambios en `database_helper.dart`: tablas virtuales y triggers usan FTS4
- Cambios en queries de búsqueda: usar `docid` en lugar de `rowid`
- Eliminado `ORDER BY rank` (no existe en FTS4, ahora ordena por fecha)
- FTS4 funciona en Android 5.0+ (target mínimo de Flutter)

### **Compatibilidad**
- ✅ **Producción Android**: FTS4 disponible en todos los dispositivos modernos
- ❌ **Tests Windows**: `sqflite_common_ffi` no tiene FTS habilitado (problema separado)
- ✅ **Funcionalidad**: Búsqueda full-text funciona igual que con FTS5

### **Trigger UPDATE Deshabilitado**
Bug conocido de FTS (aplica a FTS4 y FTS5) con triggers UPDATE:
- Trigger UPDATE deshabilitado en `database_helper.dart`
- No afecta funcionalidad: OCR se escribe UNA VEZ al escanear
- INSERT y DELETE triggers funcionan correctamente

---

## ✅ OutOfMemoryError Resuelto (2 Feb 2026)

### **Problema**
Imagen temporal para OCR era de 138MB con 300 DPI:
- Causaba `OutOfMemoryError` en dispositivos con poca RAM
- App crasheaba al procesar OCR en background
- Peor con documentos escaneados con poca luz

### **Solución**
Reducido DPI de 300 a 150 en `pdf_generator.dart`:
- Tamaño de imagen reducido 4x (~35MB en lugar de 138MB)
- 150 DPI es óptimo para Google ML Kit OCR
- Calidad de OCR sin cambios, memoria reducida significativamente

---

## Problemas Conocidos Pendientes

### **1. Sin indicador de progreso**
- Usuario no sabe si OCR está procesando
- No hay feedback visual en DocumentDetailPage mientras procesa en background

### **2. Sin manejo de errores visible**
- Si OCR falla, solo se registra en debug logs
- Usuario no recibe notificación de error

---

## Testing

- Tests ubicados en `test/features/scan/domain/usecases/`
- Archivos:
  - `extract_text_from_image_test.dart`
  - `extract_barcode_from_image_test.dart`
  - `process_ocr_test.dart`
  - `scan_and_save_document_test.dart`

---

## Dependencias Importantes

**pubspec.yaml:**
- `google_mlkit_text_recognition` - OCR de texto
- `flutter_doc_scanner` - Scanner nativo
- `sqflite` - SQLite con FTS4 (en dispositivos modernos)
- `sqlite3_flutter_libs` - Para habilitar FTS en tests (via sqflite_common_ffi)
- `image` - Procesamiento de imágenes

---

## Notas para Debug

### Verificar OCR funciona:
1. Revisar logs en `ProcessOCR.call()` (línea ~35-60)
2. Verificar que `ExtractTextFromImage` recibe path válido
3. Confirmar que ML Kit está inicializado
4. Verificar permisos de cámara en AndroidManifest/Info.plist

### Verificar actualización BD:
1. Revisar logs en `DocumentsRepositoryImpl.updateDocument()`
2. Verificar que `ocrText` no es null después de ProcessOCR
3. Hacer query directa a SQLite para confirmar datos

### Verificar UI:
1. Logs en `DocumentDetailPage.initState()` para ver qué carga
2. Widget de OCR muestra `document.ocrText ?? 'Sin texto'`
3. Verificar que `_selectedDocument` tiene datos correctos

---

## Para Futuras Sesiones

**Si se trabaja en OCR:**
1. Leer este documento primero
2. Identificar qué capa del flujo tiene problema (Domain/Data/Presentation)
3. Revisar tests correspondientes
4. Verificar logs en cada paso del flujo

**Archivos críticos a revisar:**
- `process_ocr.dart` - Lógica de extracción
- `scan_provider.dart` - Coordinación del flujo
- `document_detail_page.dart` - Visualización
- `pdf_generator.dart` - Generación de imagen temporal para OCR

