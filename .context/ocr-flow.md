# Flujo OCR - EscanDoc

**Última actualización:** 2026-02-02
**Estado:** ✅ Funcionando correctamente
**Propósito:** Referencia rápida del flujo de OCR post-escaneo para futuras sesiones

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
  - Gestión de SQLite + FTS5
  - Tabla `documents` tiene columnas:
    - `image_path` TEXT
    - `ocr_text` TEXT (nullable)
    - `barcode` TEXT (nullable)

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

## ⚠️ Bug Conocido: FTS5 + UPDATE Trigger

### **Problema**
SQLite FTS5 tiene un **bug conocido** que causa corrupción de BD cuando se usa trigger UPDATE:
- Reportado en SQLite 3.37, 3.35, 3.24
- **NO es problema de SQLCipher** - es bug de FTS5 en SQLite regular también
- El error: `DatabaseException(database disk image is malformed (code 267))`

### **Causa Raíz**
Los triggers FTS5 que intentan hacer UPDATE directo o DELETE+INSERT en la tabla FTS5 causan corrupción:
```sql
-- ❌ CAUSA CORRUPCIÓN (ambas formas)
UPDATE documents_fts SET title = new.title WHERE rowid = new.id;
-- O incluso:
DELETE FROM documents_fts WHERE rowid = old.id;
INSERT INTO documents_fts(rowid, title, ocr_text) VALUES (new.id, new.title, new.ocr_text);
```

### **Solución Implementada**
**Trigger UPDATE deshabilitado** en `database_helper.dart` línea ~160:
```dart
// DESHABILITADO: Bug conocido de FTS5 + UPDATE triggers en SQLite
// La búsqueda FTS5 funciona con el trigger INSERT, solo no se actualiza en cambios
```

### **Impacto**
- ✅ **INSERT trigger activo**: FTS5 se sincroniza al crear documentos nuevos
- ❌ **UPDATE trigger deshabilitado**: FTS5 NO se actualiza si se edita título/OCR
- ✅ **DELETE trigger activo**: FTS5 se limpia al eliminar documentos
- ✅ **Notas siguen funcionando**: La tabla `notes` tiene sus propios triggers FTS5 que funcionan

### **No Afecta la Funcionalidad Actual**
- El OCR se escribe **UNA SOLA VEZ** al escanear (no se edita después)
- La búsqueda funciona correctamente para todos los documentos
- Solo afectaría si en el futuro se implementa edición de títulos o re-procesamiento de OCR

### **Alternativas Evaluadas**
1. ❌ Cambiar a `sqflite` regular → No ayuda, es bug de FTS5
2. ❌ Usar DELETE + INSERT en trigger → Sigue causando corrupción
3. ✅ **Deshabilitar trigger UPDATE** → Solución pragmática que funciona

---

## Problemas Conocidos Secundarios

### **1. Tamaño de Imagen con Poca Luz**
- Con poca iluminación, el PNG temporal puede ser muy grande (100+ MB)
- Puede causar OutOfMemoryError en dispositivos con poca RAM
- **Pendiente optimización:** Reducir DPI o comprimir imagen para OCR

### **2. Sin indicador de progreso**
- Usuario no sabe si OCR está procesando
- No hay feedback visual en DocumentDetailPage mientras procesa en background

### **3. Sin manejo de errores visible**
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
- `image` - Procesamiento de imágenes
- `barcode_scanning` (verificar si está agregado)

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



Por qué NO arreglarlo:                                                                                                                                                                                                             - OCR se escribe UNA VEZ al escanear (nunca se actualiza)
- Título autogenerado raramente se edita
- No existe feature de "re-procesar OCR" ni "editar título manual"
- FTS5 INSERT funciona perfecto (búsqueda funciona 100%)

Cuándo SÍ arreglarlo:
- Si en el futuro implementás edición manual de documentos
- Solución: Sync manual en el método updateDocument():
  // Al actualizar documento, actualizar FTS5 manualmente
  await db.delete('documents_fts', where: 'rowid = ?', whereArgs: [id]);
  await db.insert('documents_fts', {...});

Veredicto: Dejalo así. Es pragmático y funcional. Si algún día lo necesitás, es una feature de 5 líneas. 👍

