
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

// Providers
import 'features/scan/presentation/providers/scan_provider.dart';
import 'features/documents/presentation/providers/documents_provider.dart';
import 'features/documents/presentation/providers/import_provider.dart';
import 'features/search/presentation/providers/search_provider.dart';
import 'features/notes/presentation/providers/note_provider.dart';

// Scan dependencies
import 'features/scan/domain/usecases/scan_document.dart';
import 'features/scan/domain/usecases/save_scanned_document.dart';
import 'features/scan/domain/usecases/process_ocr.dart';
import 'core/services/document_scanner_service.dart';
import 'core/services/pdf_generator.dart';
import 'core/services/document_classifier.dart';
import 'core/services/ocr_service.dart';
import 'features/documents/data/repositories/document_repository.dart';

// Image processing dependencies (Épica 6 - OCR-first)
import 'features/image_processing/normalize_image/domain/normalize_image_use_case.dart';
import 'features/image_processing/normalize_image/data/image_normalizer_service_impl.dart';
import 'features/image_processing/format_converter/domain/image_format_converter.dart';
import 'features/image_processing/format_converter/data/image_format_converter_impl.dart';
import 'features/image_processing/classification/domain/image_classifier.dart';
import 'features/image_processing/classification/data/image_classifier_impl.dart';
import 'features/documents/domain/usecases/import_document.dart';
import 'core/services/pdf_converter_service.dart';

// Search dependencies
import 'features/search/data/repositories/search_repository_impl.dart';
import 'features/search/domain/usecases/search_documents.dart';
import 'features/search/domain/usecases/voice_search.dart';
import 'core/services/speech_service_impl.dart';

// Onboarding dependencies
import 'package:shared_preferences/shared_preferences.dart';
import 'features/onboarding/domain/usecases/check_onboarding_status.dart';

// Pages
import 'features/onboarding/presentation/pages/onboarding_page.dart';
import 'features/documents/presentation/pages/documents_list_page.dart';
import 'features/documents/presentation/pages/document_detail_page.dart';
import 'features/scan/presentation/pages/camera_page.dart';
import 'features/scan/presentation/pages/crop_page.dart';
import 'features/search/presentation/pages/search_page.dart';
import 'features/notes/presentation/pages/note_editor_page.dart';

// TEMPORAL: Diagnóstico de SQLite
import 'core/database/diagnostics_page.dart';

// SPIKE TÉCNICO: Scanner custom (Épica 6 - Etapa 0)
import 'features/scanner_custom/spike/scanner_spike_page.dart';
import 'features/scanner_custom/spike/scanner_native_debug_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Verificar estado de onboarding
  final prefs = await SharedPreferences.getInstance();
  final checkOnboarding = CheckOnboardingStatus(prefs);
  final hasCompletedOnboarding = await checkOnboarding.call();

  // Obtener directorio temporal para scratchpad
  final tempDir = await getTemporaryDirectory();
  final scratchpadPath = '${tempDir.path}/scratchpad';

  // Obtener directorio de documentos para guardar PDFs (Épica 6)
  final docsDir = await getApplicationDocumentsDirectory();
  final outputDirectory = docsDir.path;

  // Decidir ruta inicial
  final initialRoute = hasCompletedOnboarding ? '/home' : '/onboarding';

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('es'), Locale('en')],
      path: 'assets/l10n',
      fallbackLocale: const Locale('es'),
      child: MyApp(
        initialRoute: initialRoute,
        scratchpadPath: scratchpadPath,
        outputDirectory: outputDirectory,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  final String scratchpadPath;
  final String outputDirectory;

  const MyApp({
    super.key,
    required this.initialRoute,
    required this.scratchpadPath,
    required this.outputDirectory,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            // Crear servicios para Scan
            final imageNormalizerService = ImageNormalizerServiceImpl();
            final normalizeImageUseCase = NormalizeImageUseCase(imageNormalizerService);
            final scannerService = DocumentScannerServiceImpl(normalizeImageUseCase);
            // SIMPLIFICADO: Solo necesitamos classifier, OCR y repository
            final classifier = DocumentClassifier();
            final ocrService = OCRServiceImpl();
            final documentRepository = DocumentRepository();

            // Crear UseCases
            final scanDocument = ScanDocument(scannerService);
            final saveDocument = SaveScannedDocument(
              classifier,
              documentRepository,
            );
            final processOCR = ProcessOCR(
              ocrService,
              classifier,
              documentRepository,
            );

            return ScanProvider(
              scanDocument: scanDocument,
              saveDocument: saveDocument,
              processOCR: processOCR,
            );
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            // Crear servicios compartidos para Import
            final imageNormalizerService = ImageNormalizerServiceImpl();
            final normalizeImageUseCase = NormalizeImageUseCase(imageNormalizerService);
            final formatConverter = ImageFormatConverterImpl();
            final imageClassifier = ImageClassifierImpl();
            final classifier = DocumentClassifier();
            final ocrService = OCRServiceImpl();
            final documentRepository = DocumentRepository();

            // Crear UseCases
            final importDocument = ImportDocument(
              formatConverter,
              normalizeImageUseCase,
            );
            final saveDocument = SaveScannedDocument(
              classifier,
              documentRepository,
            );
            final processOCR = ProcessOCR(
              ocrService,
              classifier,
              documentRepository,
            );

            return ImportProvider(
              importDocument: importDocument,
              imageClassifier: imageClassifier,
              saveDocument: saveDocument,
              processOCR: processOCR,
            );
          },
        ),
        ChangeNotifierProvider(create: (_) => DocumentsProvider()),
        ChangeNotifierProvider(
          create: (_) {
            // Crear dependencias para Search
            final searchRepository = SearchRepositoryImpl();
            final searchDocuments = SearchDocuments(repository: searchRepository);
            final speechService = SpeechServiceImpl();
            final voiceSearch = VoiceSearch(speechService: speechService);

            return SearchProvider(
              searchDocuments: searchDocuments,
              voiceSearch: voiceSearch,
            );
          },
        ),
        ChangeNotifierProvider(create: (_) => NoteProvider()),
      ],
      child: MaterialApp(
        title: 'EscanDoc',
        debugShowCheckedModeBanner: false,

        // Localization
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,

        // Theme
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          // Tamaños de fuente grandes para personas mayores
          textTheme: const TextTheme(
            titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            titleMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            bodyLarge: TextStyle(fontSize: 18),
            bodyMedium: TextStyle(fontSize: 16),
          ),
        ),

        // Routing
        initialRoute: initialRoute,
        routes: {
          '/onboarding': (context) => const OnboardingPage(),
          '/home': (context) => const DocumentsListPage(),
          '/scan': (context) => const CameraPage(),
          '/scan/crop': (context) => const CropPage(),
          '/document/detail': (context) => const DocumentDetailPage(),
          '/note/edit': (context) => const NoteEditorPage(),
          '/search': (context) => const SearchPage(),

          // TEMPORAL: Diagnóstico de SQLite
          '/diagnostics': (context) => const DiagnosticsPage(),

          // SPIKE TÉCNICO: Scanner custom (Épica 6 - Etapa 0)
          '/spike/scanner': (context) => const ScannerSpikePage(),
          '/spike/native-debug': (context) => const ScannerNativeDebugPage(),
        },
      ),
    );
  }
}
