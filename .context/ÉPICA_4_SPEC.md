# ÉPICA 4 - SCAN: Especificación de Desarrollo

**Fecha:** 24 de Enero 2026  
**Versión:** 1.0  
**Historias:** HU-007, HU-008, HU-009, HU-010, HU-011, HU-012

---

## OBJETIVO DE LA ÉPICA

Implementar escaneo de documentos usando scanner nativo (flutter_doc_scanner), procesamiento OCR offline, auto-detección de tipo y generación de nombres localizados. Core diferenciador del producto.

**Dependencia:** Requiere Épica 1 (Documents) completada.

---

## HISTORIAS DE USUARIO


## ÉPICA 4: SCAN (Feature 4 - Escaneo con OCR)
**Prioridad:** CRÍTICA (core del producto)

### HU-007: Escanear documento por primera vez
**Prioridad:** CRÍTICA (fundacional)

**Como** persona mayor que no usa mucho el celular  
**Quiero** escanear una factura con un solo botón grande  
**Para** guardarla digitalmente sin perder el papel

**Criterios de Aceptación:**
- [ ] Botón "ESCANEAR" visible en pantalla principal (mínimo 60x60 dp)
- [ ] Texto del botón en español, tamaño 24sp mínimo
- [ ] Al tocar, abre scanner nativo (flutter_doc_scanner)
- [ ] Scanner nativo maneja detección automática de bordes
- [ ] Scanner nativo maneja ajuste de bordes si es necesario
- [ ] No requiere configuración previa (funciona de inmediato)
- [ ] Tiempo de apertura: <1 segundo

---

### HU-008: Guardar documento escaneado automáticamente
**Prioridad:** CRÍTICA

**Como** persona mayor  
**Quiero** que el documento se guarde con 1 toque  
**Para** no perderme en opciones complicadas

**Criterios de Aceptación:**
- [ ] Después de escanear con flutter_doc_scanner, retorna a la app
- [ ] Guarda automáticamente como PDF en storage local
- [ ] Genera thumbnail (miniatura) automáticamente
- [ ] Nombre generado automáticamente: {tipo}_{día}_{mes}_{año}
- [ ] Formato localizado según idioma activo:
    - ES: "factura_25_Ene_2026"
    - EN: "invoice_25_Jan_2026"
- [ ] Si no detecta tipo: "documento_25_Ene_2026"
- [ ] Confirmación visual clara: "✓ Documento guardado" (3 segundos)
- [ ] NO pide nombre/carpeta al usuario
- [ ] Tiempo total desde scan a guardado: <5 segundos
- [ ] Vuelve a lista mostrando nuevo documento arriba

---

### HU-009: Extraer texto del documento automáticamente
**Prioridad:** ALTA

**Como** usuario  
**Quiero** que la app extraiga el texto automáticamente  
**Para** poder buscar documentos por contenido después

**Criterios de Aceptación:**
- [ ] OCR se ejecuta en background después de guardar
- [ ] Usa google_mlkit_text_recognition v0.15.0
- [ ] Funciona offline (no requiere internet)
- [ ] Texto extraído se guarda en campo `ocr_text` de BD
- [ ] No bloquea UI (proceso asíncrono)
- [ ] Indicador visual discreto: "Procesando texto..." (opcional)
- [ ] Si OCR falla, documento igual se guarda (OCR no es bloqueante)
- [ ] Precisión esperada: >85% en documentos bien iluminados

---

### HU-010: Auto-detectar tipo de documento
**Prioridad:** ALTA (diferenciador clave)

**Como** usuario  
**Quiero** que la app detecte automáticamente si es factura o recibo  
**Para** tener nombres claros sin categorizar manualmente

**Criterios de Aceptación:**
- [ ] Después de OCR, analiza texto y detecta tipo automáticamente
- [ ] Tipos detectables:
    - "factura" (si encuentra: factura, invoice)
    - "recibo" (si encuentra: recibo, receipt)
    - "contrato" (si encuentra: contrato, contract)
    - "médico" (si encuentra: médico, medical, consulta, prescription)
    - "documento" (default si no detecta nada)
- [ ] Tipo detectado se usa para generar nombre
- [ ] Usuario ve resultado directamente: "factura_25_Ene_2026"
- [ ] NO hay confirmación manual (simplificado vs v1.0)
- [ ] Guarda tipo detectado en BD campo `doc_type`

---

### HU-011: Extraer fecha de vencimiento automáticamente
**Prioridad:** MEDIA (WOW factor)

**Como** usuario  
**Quiero** que detecte "Vence: 15/02/2026" en la factura  
**Para** crear recordatorios sin buscar la fecha manualmente

**Criterios de Aceptación:**
- [ ] Después de OCR, busca patrones de fecha:
    - "vencimiento:", "vence:", "pagar antes de:", "due date:"
    - Formatos: DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD
- [ ] Si encuentra fecha futura (>hoy), la extrae
- [ ] Muestra mensaje: "Detecté vencimiento: 15/02/2026. ¿Crear recordatorio?"
- [ ] Botones "SÍ" (crea recordatorio en Fase 2) y "NO" (ignora)
- [ ] Guarda fecha en BD (`extracted_date`)
- [ ] Si no encuentra fecha o no está seguro, no muestra nada
- [ ] NO bloquea guardado de documento

---

### HU-012: Ver texto OCR extraído (NUEVA)
**Prioridad:** BAJA

**Como** usuario  
**Quiero** ver el texto que la app extrajo del documento  
**Para** verificar que el OCR funcionó correctamente

**Criterios de Aceptación:**
- [ ] En pantalla detalle, botón "VER TEXTO EXTRAÍDO"
- [ ] Abre diálogo o pantalla con texto OCR completo
- [ ] Texto copiable (long-press para copiar)
- [ ] Si no hay texto OCR: "No se pudo extraer texto"
- [ ] Fuente legible 16sp
- [ ] Scroll si el texto es largo

---

### HU-007: Escanear documento por primera vez
**Prioridad:** CRÍTICA

**Criterios clave:**
- Botón "ESCANEAR" 60x60dp visible en home
- Abre scanner nativo (flutter_doc_scanner)
- Scanner maneja detección y ajuste de bordes
- Tiempo apertura <1 segundo

---

### HU-008: Guardar documento escaneado automáticamente
**Prioridad:** CRÍTICA

**Criterios clave:**
- Después de scan, guarda automáticamente como PDF
- Genera thumbnail
- Nombre formato: {tipo}_{día}_{mes}_{año} localizado
- Confirmación visual "✓ Documento guardado" (3 seg)
- Vuelve a lista mostrando nuevo documento
- Tiempo total <5 segundos

---

### HU-009: Extraer texto automáticamente
**Prioridad:** ALTA

**Criterios clave:**
- OCR en background (google_mlkit_text_recognition v0.15.0)
- Offline, no bloquea UI
- Guarda en campo ocr_text
- Si falla, documento igual se guarda
- Precisión >85% en docs bien iluminados

---

### HU-010: Auto-detectar tipo
**Prioridad:** ALTA

**Criterios clave:**
- Analiza texto OCR
- Detecta: factura, recibo, contrato, médico, documento
- Tipo se usa automáticamente en nombre
- Sin confirmación manual

---

### HU-011: Extraer fecha vencimiento
**Prioridad:** MEDIA

**Criterios clave:**
- Busca patrones de fecha en OCR
- Si encuentra fecha futura, muestra mensaje
- Opción crear recordatorio (Fase 2)
- No bloquea guardado

---

### HU-012: Ver texto OCR extraído
**Prioridad:** BAJA (post-MVP)

**Criterios clave:**
- Botón en detalle documento
- Muestra texto completo
- Texto copiable
- Si no hay OCR: mensaje claro

---

## CONTRATO DE TESTS

### PASO 1: Domain (UseCases)

**Tests unitarios requeridos:**

```
test/features/scan/domain/usecases/

├── scan_document_test.dart
│   ├── ✓ Debe llamar scanner nativo correctamente
│   ├── ✓ Debe retornar imagen escaneada
│   ├── ✓ Debe fallar si usuario cancela scan
│   └── ✓ Debe manejar error de permisos
│
├── save_scanned_document_test.dart
│   ├── ✓ Debe generar PDF desde imagen
│   ├── ✓ Debe generar thumbnail
│   ├── ✓ Debe ejecutar OCR en background
│   ├── ✓ Debe detectar tipo automáticamente
│   ├── ✓ Debe generar nombre localizado
│   ├── ✓ Debe guardar en BD con metadata
│   ├── ✓ Debe guardar incluso si OCR falla
│   └── ✓ Debe usar fecha actual para nombre
│
└── process_ocr_test.dart
    ├── ✓ Debe extraer texto con ML Kit
    ├── ✓ Debe actualizar documento con ocr_text
    ├── ✓ Debe detectar tipo después de OCR
    ├── ✓ Debe extraer fecha vencimiento si existe
    └── ✓ Debe manejar error de OCR sin fallar
```

**Cobertura mínima Domain:** 100%

---

### PASO 2: Core Services

**Tests de servicios requeridos:**

```
test/core/services/

├── document_classifier_test.dart
│   ├── ✓ Debe detectar "factura" con keywords correctas
│   ├── ✓ Debe detectar "recibo" con keywords correctas
│   ├── ✓ Debe detectar "contrato" con keywords correctas
│   ├── ✓ Debe detectar "médico" con keywords correctas
│   ├── ✓ Debe retornar "documento" por default
│   ├── ✓ Debe generar nombre ES: "factura_25_Ene_2026"
│   ├── ✓ Debe generar nombre EN: "invoice_25_Jan_2026"
│   ├── ✓ Debe extraer fecha DD/MM/YYYY
│   ├── ✓ Debe extraer fecha DD-MM-YYYY
│   ├── ✓ Debe extraer fecha YYYY-MM-DD
│   ├── ✓ Debe ignorar fechas pasadas
│   └── ✓ Debe retornar null si no encuentra fecha
│
├── ocr_service_test.dart
│   ├── ✓ Debe extraer texto de imagen
│   ├── ✓ Debe funcionar offline
│   ├── ✓ Debe retornar string vacío si falla
│   └── ✓ Debe cerrar recursos correctamente
│
└── pdf_generator_test.dart
    ├── ✓ Debe crear PDF desde imagen
    ├── ✓ Debe generar thumbnail 200x200
    ├── ✓ Debe guardar en path correcto
    └── ✓ Debe manejar errores de escritura
```

---

### PASO 3: Data (Repository)

**Tests de integración requeridos:**

```
test/features/scan/data/repositories/

└── scan_repository_test.dart
    ├── ✓ Debe coordinar scanner + OCR + guardado
    ├── ✓ Debe insertar documento completo en BD
    ├── ✓ Debe guardar archivos PDF y thumbnail
    └── ✓ Debe actualizar FTS5 después de OCR
```

---

## ORDEN DE IMPLEMENTACIÓN (TDD)

### PASO 1: Core Services (fundacionales)

**Objetivo:** Servicios compartidos sin UI

**Artefactos a crear:**
```
lib/core/services/
├── ocr_service.dart
├── document_classifier.dart
├── pdf_generator.dart
└── image_processor.dart (opcional - thumbnails)
```

**OCRService:**
- Wrapper de google_mlkit_text_recognition
- Método extractText(File image) → Future<String>
- Manejo de errores sin lanzar excepciones
- Dispose correcto de recursos

**DocumentClassifier:**
- Método detectType(String ocrText) → String
- Keywords para cada tipo (case-insensitive)
- Método generateDocumentName(tipo, fecha, locale) → String
- Traducción de meses según locale
- Método extractDueDate(String ocrText) → DateTime?
- Regex para patrones de fecha
- Validación fecha futura

**PDFGenerator:**
- Crear PDF desde imagen (package pdf)
- Generar thumbnail 200x200 (package image)
- Guardar en paths correctos
- Retornar File objects

**Workflow:**
1. Escribir tests de cada servicio
2. Implementar hasta tests en verde
3. Validar integración entre servicios

**Criterio de avance:** Todos los tests de services en verde

---

### PASO 2: Domain Layer

**Objetivo:** Orquestar servicios sin Flutter

**Artefactos a crear:**
```
lib/features/scan/domain/usecases/
├── scan_document.dart
├── save_scanned_document.dart
└── process_ocr.dart
```

**ScanDocument UseCase:**
- Llama flutter_doc_scanner
- Retorna File con imagen escaneada
- Maneja cancelación de usuario
- Maneja errores de permisos

**SaveScannedDocument UseCase:**
- Recibe File de imagen
- Genera PDF
- Genera thumbnail
- Ejecuta OCR en background (Future.microtask)
- Detecta tipo
- Genera nombre localizado
- Inserta en BD
- Retorna Document guardado

**ProcessOCR UseCase:**
- Recibe document_id
- Ejecuta OCR
- Detecta tipo
- Extrae fecha vencimiento
- Actualiza documento en BD

**Workflow:**
1. Tests primero (mocks de services)
2. Implementar lógica de orquestación
3. Validar flujo completo con mocks

**Criterio de avance:** Tests Domain en verde

---

### PASO 3: Data Layer

**Objetivo:** Repository real

**Artefactos a crear:**
```
lib/features/scan/data/repositories/
└── scan_repository.dart
```

**Responsabilidades:**
- Coordinar UseCases
- Insertar documentos en BD
- Guardar archivos en storage
- Triggear actualización FTS5

**Workflow:**
1. Implementar repository
2. Tests de integración
3. Validar paths de archivos correctos

**Criterio de avance:** Tests repository en verde

---

### PASO 4: Presentation Layer

**Objetivo:** UI mínima + integración

**Artefactos a crear:**
```
lib/features/scan/presentation/
├── providers/
│   └── scan_provider.dart
└── pages/
    └── scan_launcher_page.dart (opcional - puede ser solo botón)
```

**Modificar:**
```
lib/features/documents/presentation/pages/
└── documents_list_page.dart
    └── Agregar: FloatingActionButton "ESCANEAR" (60x60dp)
```

**ScanProvider:**
- Estado: isScanning, isSaving
- Método scanAndSave() que orquesta todo
- Notifica listeners en cada paso

**Integración con Documents:**
- FAB llama scan_provider.scanAndSave()
- Muestra loading durante proceso
- SnackBar confirmación al terminar
- Refresca lista automáticamente

**Workflow:**
1. Crear ScanProvider
2. Agregar FAB en DocumentsListPage
3. Testing manual con documentos reales

**Criterio de avance:** Escaneo end-to-end funciona

---

## FLUJO COMPLETO (sin código)

**Usuario toca ESCANEAR:**
1. ScanProvider cambia isScanning = true
2. Llama ScanDocument UseCase
3. flutter_doc_scanner abre UI nativa
4. Usuario escanea (detección automática bordes)
5. Scanner retorna imagen
6. ScanProvider cambia isSaving = true
7. Llama SaveScannedDocument UseCase:
    - PDFGenerator crea PDF
    - PDFGenerator crea thumbnail
    - DocumentClassifier genera nombre temporal
    - Inserta en BD
    - Lanza ProcessOCR en background
8. ProcessOCR (asíncrono):
    - OCRService extrae texto
    - DocumentClassifier detecta tipo
    - DocumentClassifier genera nombre final
    - Actualiza documento en BD
9. ScanProvider actualiza lista
10. UI muestra SnackBar "✓ Documento guardado"
11. Nuevo documento aparece arriba de lista

---

## CONFIGURACIÓN CRÍTICA

**flutter_doc_scanner:**
- Configurar permisos cámara en AndroidManifest.xml
- Configurar permisos cámara en Info.plist (iOS)
- Revisar documentación del package para opciones

**google_mlkit_text_recognition:**
- No requiere API keys (offline)
- Descargar modelo ML Kit automáticamente
- Configurar idioma español por defecto

**Localización:**
- Meses en español: Ene, Feb, Mar, Abr, May, Jun, Jul, Ago, Sep, Oct, Nov, Dic
- Meses en inglés: Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec
- Usar AppLocalizations para obtener traducciones

---

## DATOS DE PRUEBA

**No hay datos de prueba previos - esta épica crea los primeros documentos**

**Para testing manual:**
- Escanear factura real (Edesur, Ecogas, etc.)
- Escanear recibo médico
- Escanear documento sin texto claro
- Validar nombres generados
- Validar OCR en diferentes iluminaciones

---

## CRITERIOS DE COMPLETITUD ÉPICA 4

**Checklist antes de pasar a Épica 5:**

### Tests
- [ ] Todos tests Domain pasan (100% cobertura)
- [ ] Tests de services pasan (OCR, Classifier, PDF)
- [ ] Tests de repository pasan
- [ ] No hay tests rojos

### Funcionalidad - Escaneo
- [ ] FAB "ESCANEAR" visible en home (60x60dp, texto 24sp)
- [ ] Al tocar, abre scanner nativo inmediatamente
- [ ] Scanner detecta bordes automáticamente
- [ ] Usuario puede ajustar bordes en scanner nativo
- [ ] Al confirmar scan, vuelve a app
- [ ] Tiempo apertura scanner <1 segundo

### Funcionalidad - Guardado
- [ ] Genera PDF automáticamente
- [ ] Genera thumbnail 200x200
- [ ] Nombre formato: tipo_día_mes_año (localizado)
- [ ] ES: "factura_24_Ene_2026"
- [ ] EN: "invoice_24_Jan_2026"
- [ ] Confirmación "✓ Documento guardado" (3 seg)
- [ ] Vuelve a lista mostrando documento arriba
- [ ] Tiempo total scan→guardado <5 segundos

### Funcionalidad - OCR
- [ ] Se ejecuta en background (no bloquea UI)
- [ ] Usa google_mlkit_text_recognition v0.15.0
- [ ] Funciona offline
- [ ] Texto guardado en campo ocr_text
- [ ] Si OCR falla, documento igual se guarda
- [ ] Indicador discreto "Procesando texto..." (opcional)

### Funcionalidad - Auto-detección
- [ ] Detecta "factura" correctamente (keywords: factura, invoice)
- [ ] Detecta "recibo" correctamente (keywords: recibo, receipt)
- [ ] Detecta "contrato" correctamente (keywords: contrato, contract)
- [ ] Detecta "médico" correctamente (keywords: médico, medical, consulta)
- [ ] Default: "documento" si no detecta
- [ ] Tipo usado automáticamente en nombre
- [ ] Sin confirmación manual del usuario

### Funcionalidad - Fecha vencimiento
- [ ] Busca patrones: "vencimiento:", "vence:", "pagar antes"
- [ ] Extrae fechas DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD
- [ ] Ignora fechas pasadas
- [ ] Guarda en campo extracted_date
- [ ] Mensaje opcional si encuentra fecha (no implementado aún)

### Arquitectura
- [ ] Domain NO importa Flutter
- [ ] Domain NO importa packages directamente (OCR, PDF, scanner)
- [ ] Services son inyectables (pueden mockearse)
- [ ] OCR en background no bloquea main thread

### Performance
- [ ] Scan→guardado <5 segundos (sin OCR)
- [ ] OCR completo <10 segundos (background)
- [ ] UI responsive durante todo el proceso
- [ ] No memory leaks (dispose services)

### Localización
- [ ] Todos textos usan claves
- [ ] Nombres documentos localizados correctamente
- [ ] Meses traducidos según idioma activo

---

## ENTREGABLES ESPERADOS

```
lib/core/services/
├── ocr_service.dart               ✓ Completo + tests
├── document_classifier.dart       ✓ Completo + tests
├── pdf_generator.dart             ✓ Completo + tests
└── image_processor.dart           ✓ Completo (thumbnails)

lib/features/scan/
├── data/
│   └── repositories/
│       └── scan_repository.dart   ✓ Completo + tests
├── domain/
│   └── usecases/
│       ├── scan_document.dart     ✓ Completo + tests
│       ├── save_scanned_document.dart ✓ Completo + tests
│       └── process_ocr.dart       ✓ Completo + tests
└── presentation/
    └── providers/
        └── scan_provider.dart     ✓ Completo

test/core/services/
├── ocr_service_test.dart          ✓ ~4 tests
├── document_classifier_test.dart  ✓ ~12 tests
└── pdf_generator_test.dart        ✓ ~4 tests

test/features/scan/
├── domain/
│   └── usecases/                  ✓ 3 archivos, ~15 tests
└── data/
    └── repositories/              ✓ 1 archivo, ~4 tests

Modificaciones:
lib/features/documents/presentation/pages/
└── documents_list_page.dart       ✓ FAB ESCANEAR integrado
```

---

## NOTAS PARA CLAUDE CODE

1. **flutter_doc_scanner maneja UI** - No construir cámara custom
2. **OCR background crítico** - Usar Future.microtask o Isolate
3. **Nombres localizados desde día 1** - No hardcodear meses
4. **Services deben ser stateless** - No guardar estado interno
5. **Dispose crítico** - OCRService debe liberar recursos
6. **Permisos en manifest** - Documentar en README
7. **Testing real necesario** - Emulador puede no tener cámara funcional
8. **HU-012 es BAJA prioridad** - Implementar solo si sobra tiempo

---


## REFERENCIAS en /.context

- **Arquitectura:** /architecture.md`
- **Schema BD:** `/database_schema.md` (FTS5 tables)
- **Historias completas:** `/user_stories_mvp.md`
- **Épicas previas:** `ÉPICA_1_SPEC.md`, `ÉPICA_2_SPEC.md`
- **Decisiones técnicas:** `/project/ADDS.md`(scanner nativo)
- **Package speech_to_text:** Revisar docs para permisos Android/iOS 
- **Packages:** flutter_doc_scanner ^0.0.17, google_mlkit_text_recognition ^0.15.0