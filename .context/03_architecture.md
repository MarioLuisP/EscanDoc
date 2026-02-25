# EscanDoc - Arquitectura de Alto Nivel

**Fecha:** 17 de Enero 2026  
**Versión:** 1.0  
**Basado en:** Clean Architecture simplificada

---

## DECISIONES ARQUITECTÓNICAS CLAVE

### 1. Arquitectura: Clean Architecture (3 capas)
```
Presentation (UI + State)
    ↓
Domain (Lógica de negocio)
    ↓
Data (BD + Storage + Services)
```

**Razón:** Separación clara de responsabilidades, testeable, mantenible.

### 2. State Management: Provider
- **Un Provider por feature** (no globales gigantes)
- Simple, bien conocido, menos boilerplate que Bloc
- Suficiente para complejidad del proyecto

### 3. Base de Datos: SQLite local + FTS5
- Offline-first (crítico para privacidad)
- FTS5 para búsqueda full-text eficiente
- Sin backend necesario para MVP

### 4. Procesamiento de Imagen: Flutter nativo
- Todo offline (sin Python backend)
- Packages: `image`, `edge_detection`, `google_ml_kit`
- Performance suficiente para target (mayores no exigen FPS alto)

### 5. Navegación: Named routes
- MaterialApp con rutas nombradas
- Facilita deep linking futuro
- Clean y predecible

---

## ESTRUCTURA DE PROYECTO

```
lib/
├── core/                          # Compartido entre módulos
│   ├── database/           
│   │   └── database_helper.dart    # Singleton SQLite + migrations
│   │
│   ├── services/                   # Servicios compartidos
│   │   ├── ocr_service.dart        # Google ML Kit para OCR
│   │   ├── document_classifier.dart # Smart tagging (HU-012)
│   │   ├── image_processor.dart     # Crop, deskew, contrast, binarize
│   │   └── pdf_generator.dart       # Genera PDFs desde imagen
│   │
│   ├── utils/                      # Helpers
│   │   ├── date_utils.dart         # Formateo fechas, parse, etc
│   │   └── validators.dart         # Validación inputs
│   │
│   └── constants/
│       └── app_constants.dart      # Colores, tamaños, strings
│
├── features/                       # Módulos por funcionalidad
│   │
│   ├── scan/                       # ÉPICA 1: HU-001 a HU-004
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── scan_repository.dart
│   │   │
│   │   ├── domain/
│   │   │   └── usecases/
│   │   │       ├── capture_document.dart
│   │   │       ├── detect_edges.dart
│   │   │       └── save_document.dart
│   │   │
│   │   └── presentation/
│   │       ├── pages/
│   │       │   ├── camera_page.dart         # HU-001, HU-002
│   │       │   └── crop_page.dart           # HU-003
│   │       │
│   │       ├── widgets/
│   │       │   ├── scan_button.dart         # Botón gigante
│   │       │   ├── edge_overlay.dart        # Marco verde/rojo
│   │       │   └── crop_handles.dart        # 4 puntos ajuste
│   │       │
│   │       └── providers/
│   │           └── scan_provider.dart       # State para scan
│   │
│   ├── documents/                  # ÉPICA 2 & 3: HU-005, HU-008, HU-009, HU-015
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   └── document_model.dart      # id, title, file_path, ocr_text, 
│   │   │   │                                 # thumbnail_path, category, doc_type,
│   │   │   │                                 # created_at, updated_at
│   │   │   │
│   │   │   └── repositories/
│   │   │       └── document_repository.dart # CRUD documentos + OCR trigger
│   │   │
│   │   ├── domain/
│   │   │   └── usecases/
│   │   │       ├── get_documents.dart
│   │   │       ├── get_document_by_id.dart
│   │   │       ├── delete_document.dart
│   │   │       └── process_ocr.dart         # HU-005
│   │   │
│   │   └── presentation/
│   │       ├── pages/
│   │       │   ├── documents_list_page.dart # HU-008
│   │       │   └── document_detail_page.dart # HU-009
│   │       │
│   │       ├── widgets/
│   │       │   ├── document_card.dart       # Item lista con thumbnail
│   │       │   ├── empty_state.dart         # "No hay documentos..."
│   │       │   └── delete_confirmation_dialog.dart # HU-015
│   │       │
│   │       └── providers/
│   │           └── documents_provider.dart  # State para lista docs
│   │
│   ├── search/                     # ÉPICA 2: HU-006, HU-007
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── search_repository.dart   # FTS5 queries
│   │   │
│   │   ├── domain/
│   │   │   └── usecases/
│   │   │       ├── search_documents.dart    # HU-006
│   │   │       └── voice_search.dart        # HU-007
│   │   │
│   │   └── presentation/
│   │       ├── pages/
│   │       │   └── search_page.dart         # Barra búsqueda + resultados
│   │       │
│   │       ├── widgets/
│   │       │   ├── search_bar.dart
│   │       │   ├── voice_button.dart
│   │       │   └── search_result_card.dart
│   │       │
│   │       └── providers/
│   │           └── search_provider.dart
│   │
│   ├── notes/                      # ÉPICA 3: HU-010
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   └── note_model.dart          # id, title, content, document_id
│   │   │   │
│   │   │   └── repositories/
│   │   │       └── note_repository.dart     # CRUD notas
│   │   │
│   │   ├── domain/
│   │   │   └── usecases/
│   │   │       ├── create_note.dart
│   │   │       ├── update_note.dart
│   │   │       └── delete_note.dart
│   │   │
│   │   └── presentation/
│   │       ├── pages/
│   │       │   └── note_editor_page.dart    # Editor simple
│   │       │
│   │       ├── widgets/
│   │       │   └── note_display.dart        # Muestra nota en detalle doc
│   │       │
│   │       └── providers/
│   │           └── note_provider.dart
│   │
│   ├── categories/                 # ÉPICA 4: HU-011, HU-012
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── category_repository.dart
│   │   │
│   │   ├── domain/
│   │   │   └── usecases/
│   │   │       ├── assign_category.dart     # HU-011
│   │   │       └── auto_detect_type.dart    # HU-012
│   │   │
│   │   └── presentation/
│   │       ├── widgets/
│   │       │   ├── category_selector.dart   # 6 botones carpetas
│   │       │   └── category_filter.dart     # Dropdown filtro
│   │       │
│   │       └── providers/
│   │           └── category_provider.dart
│   │
│   └── onboarding/                 # ÉPICA 5: HU-014
│       └── presentation/
│           ├── pages/
│           │   └── onboarding_page.dart     # 3 pantallas tutorial
│           │
│           └── widgets/
│               └── onboarding_step.dart     # Widget reutilizable paso
│
└── main.dart                       # Entry point + routes + providers
```

---

## FLUJO DE DATOS (Ejemplo: Escanear documento)

### Caso: Usuario escanea factura Edesur

```
1. UI: CameraPage 
   └─> Usuario toca botón "CAPTURAR"

2. Provider: ScanProvider
   └─> notifyListeners() para mostrar loading
   
3. UseCase: CaptureDocument
   └─> Ejecuta lógica: validar imagen, procesar

4. Repository: ScanRepository
   └─> Coordina servicios:
       ├─> ImageProcessor.cropImage()
       ├─> ImageProcessor.enhanceQuality()
       └─> PDFGenerator.createPDF()

5. Database: DatabaseHelper
   └─> INSERT documento
   
6. Background: OCRService (asíncrono)
   └─> Extrae texto
   └─> DocumentClassifier.detectType() → "Factura"
   └─> UPDATE documento con ocr_text y doc_type

7. Provider: notifyListeners()
   └─> UI muestra "✓ Documento guardado"
```

---

## PROVIDERS POR FEATURE (No globales)

### Providers definidos:

```dart
// features/scan/presentation/providers/scan_provider.dart
class ScanProvider extends ChangeNotifier {
  // State: imagen capturada, bordes detectados, loading
  // Methods: captureImage(), adjustEdges(), saveDocument()
}

// features/documents/presentation/providers/documents_provider.dart
class DocumentsProvider extends ChangeNotifier {
  // State: lista documentos, selected document, loading
  // Methods: loadDocuments(), selectDocument(), deleteDocument()
}

// features/search/presentation/providers/search_provider.dart
class SearchProvider extends ChangeNotifier {
  // State: query, resultados, loading, voice listening
  // Methods: search(), voiceSearch(), clearResults()
}

// features/notes/presentation/providers/note_provider.dart
class NoteProvider extends ChangeNotifier {
  // State: nota actual, loading
  // Methods: createNote(), updateNote(), deleteNote()
}

// features/categories/presentation/providers/category_provider.dart
class CategoryProvider extends ChangeNotifier {
  // State: categorías, filtro activo
  // Methods: assignCategory(), filterByCategory()
}
```

### Inyección en main.dart:

```dart
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ScanProvider()),
        ChangeNotifierProvider(create: (_) => DocumentsProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => NoteProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
      ],
      child: MyApp(),
    ),
  );
}
```

---

## SERVICIOS CORE (Compartidos)

### 1. OCRService
```dart
// core/services/ocr_service.dart
class OCRService {
  Future<String> extractText(File imageFile);
  // Usa google_ml_kit
  // Retorna texto extraído o empty string si falla
}
```

### 2. DocumentClassifier
```dart
// core/services/document_classifier.dart
class DocumentClassifier {
  String detectType(String ocrText);
  // Analiza texto OCR
  // Retorna: "factura", "recibo", "contrato", "otros"
  
  DateTime? extractDueDate(String ocrText);
  // Busca patrones de fecha vencimiento
  // Retorna fecha o null
}
```

### 3. ImageProcessor
```dart
// core/services/image_processor.dart
class ImageProcessor {
  Future<File> cropImage(File input, List<Offset> corners);
  Future<File> enhanceQuality(File input);
  Future<File> deskewImage(File input);
  Future<File> binarizeImage(File input);
  // Pre-procesamiento para mejorar OCR
}
```

### 4. PDFGenerator
```dart
// core/services/pdf_generator.dart
class PDFGenerator {
  Future<File> createPDF(File imageFile, String filename);
  Future<File> createThumbnail(File pdfFile);
  // Genera PDF + thumbnail
}
```

---

## NAVEGACIÓN

### Rutas nombradas:

```dart
// main.dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EscanDoc',
      initialRoute: '/onboarding', // o '/home' si ya completó
      routes: {
        '/onboarding': (context) => OnboardingPage(),
        '/home': (context) => DocumentsListPage(),
        '/scan': (context) => CameraPage(),
        '/scan/crop': (context) => CropPage(),
        '/document/detail': (context) => DocumentDetailPage(),
        '/note/edit': (context) => NoteEditorPage(),
        '/search': (context) => SearchPage(),
      },
    );
  }
}
```

### Navegación típica:

```dart
// Desde home a scan
Navigator.pushNamed(context, '/scan');

// Desde crop a home (con resultado)
Navigator.popUntil(context, ModalRoute.withName('/home'));

// A detalle documento (con args)
Navigator.pushNamed(
  context, 
  '/document/detail',
  arguments: {'documentId': doc.id},
);
```

---

## DATABASE HELPER (Singleton)

```dart
// core/database/database_helper.dart
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  
  DatabaseHelper._init();
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('escandoc.db');
    return _database!;
  }
  
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }
  
  Future _createDB(Database db, int version) async {
    // Ver database_schema.md para SQL completo
  }
  
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Migrations futuras
  }
}
```

---

## PRINCIPIOS DE DISEÑO

### 1. Separation of Concerns
- **Presentation:** Solo UI y state
- **Domain:** Solo lógica de negocio
- **Data:** Solo acceso a datos

### 2. Dependency Injection
- Providers inyectados en main.dart
- Repositorios reciben servicios en constructor
- Fácil mockear en tests

### 3. Single Responsibility
- Cada clase hace una cosa
- Servicios especializados (OCR, PDF, Classifier)
- Providers por feature (no God objects)

### 4. Testability
- Lógica separada de UI
- Dependencias inyectables
- Cada capa testeable independiente

**Última actualización:** 17 Enero 2026
