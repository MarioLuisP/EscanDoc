
import 'package:flutter/material.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

// Providers
import 'features/scan/presentation/providers/scan_provider.dart';
import 'features/documents/presentation/providers/documents_provider.dart';
import 'features/documents/presentation/providers/import_provider.dart';
import 'features/search/presentation/providers/search_provider.dart';

// Scan dependencies
import 'features/scan/domain/usecases/scan_document.dart';
import 'features/scan/domain/usecases/save_scanned_document.dart';
import 'features/scan/domain/usecases/process_ocr.dart';
import 'features/scan/domain/usecases/refine_classification.dart';
import 'core/services/document_orientation_service_impl.dart';
import 'core/services/document_scanner_service.dart';
import 'core/services/document_classifier.dart';
import 'core/services/ocr_service.dart';
import 'core/services/document_pipeline.dart';
import 'features/documents/data/repositories/document_repository.dart';

// Image processing dependencies (Épica 6 - OCR-first)
import 'features/image_processing/normalize_image/domain/normalize_image_use_case.dart';
import 'features/image_processing/normalize_image/data/image_normalizer_service_impl.dart';
import 'features/image_processing/format_converter/data/image_format_converter_impl.dart';
import 'features/documents/domain/usecases/import_document.dart';
import 'features/image_processing/classification/data/tflite_image_classifier.dart';
import 'features/image_processing/thumbnail/data/thumbnail_generator_impl.dart';
import 'features/documents/data/services/pdf_import_service_impl.dart';

// Search dependencies
import 'features/search/data/repositories/search_repository_impl.dart';
import 'features/search/domain/usecases/search_documents.dart';
import 'features/search/domain/usecases/voice_search.dart';
import 'core/services/speech_service_impl.dart';

// Onboarding dependencies
import 'package:shared_preferences/shared_preferences.dart';
import 'features/onboarding/domain/usecases/check_onboarding_status.dart';

// Notifications
import 'core/services/notification_service.dart';

// Pages
import 'features/onboarding/presentation/pages/onboarding_page.dart';
import 'features/documents/presentation/pages/documents_list_page.dart';
import 'features/documents/presentation/pages/home_page.dart';
import 'features/documents/presentation/pages/document_detail_page.dart';
import 'features/search/presentation/pages/search_page.dart';
import 'features/notes/presentation/pages/note_editor_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'features/calendar/presentation/pages/calendar_page.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await pdfrxFlutterInitialize();

  tz_data.initializeTimeZones();
  final timezoneInfo = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
  NotificationService.navigatorKey = _navigatorKey;

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

class MyApp extends StatefulWidget {
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
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService.initialize();
      await NotificationService.requestPermission();

      final docId = await NotificationService.getNotificationLaunchDocumentId();
      if (docId != null) {
        _navigatorKey.currentState?.pushNamed('/document/detail', arguments: docId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DocumentPipeline>(
          create: (_) {
            // Servicios e UseCases compartidos — instanciados UNA SOLA VEZ
            final imageNormalizerService = ImageNormalizerServiceImpl();
            final normalizeImageUseCase = NormalizeImageUseCase(imageNormalizerService);
            final formatConverter = ImageFormatConverterImpl();
            final imageClassifier = TFLiteImageClassifier();
            final classifier = DocumentClassifier();
            final ocrService = OCRServiceImpl();
            final documentRepository = DocumentRepository();
            final thumbnailGenerator = ThumbnailGeneratorImpl();

            final importDocument = ImportDocument(formatConverter, normalizeImageUseCase);
            final saveDocument = SaveScannedDocument(classifier, documentRepository);
            final processOCR = ProcessOCR(
              ocrService,
              classifier,
              documentRepository,
              RefineClassification(),
              orientationService: DocumentOrientationServiceImpl(),
              imageClassifier: imageClassifier,
            );

            return DocumentPipeline(
              importDocument: importDocument,
              imageClassifier: imageClassifier,
              saveDocument: saveDocument,
              processOCR: processOCR,
              thumbnailGenerator: thumbnailGenerator,
            );
          },
        ),
        ChangeNotifierProvider(
          create: (context) => ScanProvider(
            scanDocument: ScanDocument(DocumentScannerServiceImpl()),
            pipeline: context.read<DocumentPipeline>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => ImportProvider(
            pipeline: context.read<DocumentPipeline>(),
            pdfImportService: PdfImportServiceImpl(),
          ),
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
      ],
      child: MaterialApp(
        title: 'EscanDoc',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,

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
        initialRoute: widget.initialRoute,
        onUnknownRoute: (settings) => MaterialPageRoute(
          settings: settings,
          builder: (_) => const HomePage(),
        ),
        routes: {
          '/onboarding': (context) => const OnboardingPage(),
          '/home': (context) => const HomePage(),
          '/documents': (context) => const DocumentsListPage(),
          '/document/detail': (context) => const DocumentDetailPage(),
          '/note/edit': (context) => const NoteEditorPage(),
          '/search': (context) => const SearchPage(),
          '/settings': (context) => const SettingsPage(),
          '/calendar': (context) => const CalendarPage(),

        },
      ),
    );
  }
}
