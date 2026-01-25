
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

// Providers
import 'features/scan/presentation/providers/scan_provider.dart';
import 'features/documents/presentation/providers/documents_provider.dart';
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

// Search dependencies
import 'features/search/data/repositories/search_repository_impl.dart';
import 'features/search/domain/usecases/search_documents.dart';
import 'features/search/domain/usecases/voice_search.dart';
import 'core/services/speech_service_impl.dart';

// Pages
import 'features/onboarding/presentation/pages/onboarding_page.dart';
import 'features/documents/presentation/pages/documents_list_page.dart';
import 'features/documents/presentation/pages/document_detail_page.dart';
import 'features/scan/presentation/pages/camera_page.dart';
import 'features/scan/presentation/pages/crop_page.dart';
import 'features/search/presentation/pages/search_page.dart';
import 'features/notes/presentation/pages/note_editor_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('es'), Locale('en')],
      path: 'assets/l10n',
      fallbackLocale: const Locale('es'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            // Crear servicios para Scan
            final scannerService = DocumentScannerServiceImpl();
            final pdfGenerator = PDFGeneratorImpl();
            final classifier = DocumentClassifier();
            final ocrService = OCRServiceImpl();
            final documentRepository = DocumentRepository();

            // Crear UseCases
            final scanDocument = ScanDocument(scannerService);
            final saveDocument = SaveScannedDocument(
              pdfGenerator,
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
        initialRoute: '/home', // TODO: Cambiar a /onboarding cuando se implemente
        routes: {
          '/onboarding': (context) => const OnboardingPage(),
          '/home': (context) => const DocumentsListPage(),
          '/scan': (context) => const CameraPage(),
          '/scan/crop': (context) => const CropPage(),
          '/document/detail': (context) => const DocumentDetailPage(),
          '/note/edit': (context) => const NoteEditorPage(),
          '/search': (context) => const SearchPage(),
        },
      ),
    );
  }
}
