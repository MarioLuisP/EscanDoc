import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:escandoc/features/scan/domain/usecases/process_ocr.dart';
import 'package:escandoc/features/scan/domain/usecases/refine_classification.dart';
import 'package:escandoc/core/services/ocr_service.dart';
import 'package:escandoc/core/services/ocr_analysis.dart';
import 'package:escandoc/core/services/document_classifier.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';

// Mocks
class MockOCRService extends Mock implements OCRService {}
class MockDocumentClassifier extends Mock implements DocumentClassifier {}
class MockDocumentRepository extends Mock implements DocumentRepository {}
class MockRefineClassification extends Mock implements RefineClassification {}

// Fakes para registerFallbackValue
class FakeDocumentModel extends Fake implements DocumentModel {}
class FakeFile extends Fake implements File {}
class FakeOcrAnalysis extends Fake implements OcrAnalysis {}

void main() {
  late ProcessOCR useCase;
  late MockOCRService mockOCRService;
  late MockDocumentClassifier mockClassifier;
  late MockDocumentRepository mockRepository;
  late MockRefineClassification mockRefinement;
  late Directory tempDir;
  late File testJpgFile;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(FakeDocumentModel());
    registerFallbackValue(FakeFile());
    registerFallbackValue(FakeOcrAnalysis());
  });

  setUp(() async {
    mockOCRService = MockOCRService();
    mockClassifier = MockDocumentClassifier();
    mockRepository = MockDocumentRepository();
    mockRefinement = MockRefineClassification();

    // Create temporary directory and test JPG file
    tempDir = await Directory.systemTemp.createTemp('process_ocr_test_');
    testJpgFile = File(path.join(tempDir.path, 'test_document.jpg'));
    await testJpgFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]); // Minimal JPG header

    useCase = ProcessOCR(
      mockOCRService,
      mockClassifier,
      mockRepository,
      mockRefinement,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // Helper para OcrAnalysis
  OcrAnalysis makeAnalysis(String text, {String topConfidenceText = ''}) => OcrAnalysis(
        text: text,
        blockCount: 10,
        avgConfidence: 0.85,
        topConfidenceText: topConfidenceText,
      );

  // Helper para RefinementResult sin cambio
  RefinementResult noChange(String type) =>
      RefinementResult(refinedClass: type);

  group('ProcessOCR', () {
    DocumentModel createTestDocument() {
      return DocumentModel(
        id: 1,
        title: 'documento_25_Ene_2026',
        filePath: testJpgFile.path,
        createdAt: DateTime(2026, 1, 25),
        updatedAt: DateTime(2026, 1, 25),
      );
    }

    test('debe extraer análisis OCR desde JPG', () async {
      // Arrange
      final testDoc = createTestDocument();
      final analysis = makeAnalysis('Texto extraído del documento');
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockOCRService.extractAnalysis(any(), docType: any(named: 'docType')))
          .thenAnswer((_) async => analysis);
      when(() => mockRefinement.call(any(), any()))
          .thenReturn(noChange('documento'));
      when(() => mockClassifier.extractDueDate(any())).thenReturn(null);
      when(() => mockRepository.updateDocument(any()))
          .thenAnswer((_) async => 1);

      // Act
      await useCase.call(1);

      // Assert - extractAnalysis debe ser llamado con el archivo JPG
      final captured =
          verify(() => mockOCRService.extractAnalysis(captureAny(), docType: any(named: 'docType')))
              .captured.single as File;
      expect(captured.path, testJpgFile.path);
    });

    test('debe actualizar documento con ocr_text', () async {
      // Arrange
      const extractedText = 'Este es el texto extraído con OCR';
      final testDoc = createTestDocument();
      final analysis = makeAnalysis(extractedText);
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockOCRService.extractAnalysis(any(), docType: any(named: 'docType')))
          .thenAnswer((_) async => analysis);
      when(() => mockRefinement.call(any(), any()))
          .thenReturn(noChange('documento'));
      when(() => mockClassifier.extractDueDate(extractedText)).thenReturn(null);
      when(() => mockRepository.updateDocument(any()))
          .thenAnswer((_) async => 1);

      // Act
      await useCase.call(1);

      // Assert
      final captured =
          verify(() => mockRepository.updateDocument(captureAny()))
              .captured.single as DocumentModel;
      expect(captured.ocrText, extractedText);
    });

    test('debe llamar al refinamiento con la clase TFLite', () async {
      // Arrange
      final testDoc = createTestDocument();
      final analysis = makeAnalysis('texto');
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockOCRService.extractAnalysis(any(), docType: any(named: 'docType')))
          .thenAnswer((_) async => analysis);
      when(() => mockRefinement.call(any(), any()))
          .thenReturn(noChange('documento'));
      when(() => mockClassifier.extractDueDate(any())).thenReturn(null);
      when(() => mockRepository.updateDocument(any()))
          .thenAnswer((_) async => 1);

      // Act
      await useCase.call(1, tfliteClass: 'manuscrito');

      // Assert
      verify(() => mockRefinement.call('manuscrito', any())).called(1);
    });

    test('nota de impreso: guarda primeros 150 chars en note_content', () async {
      // Arrange
      const text = 'Este es el texto extraído con OCR del documento impreso';
      final testDoc = createTestDocument();
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockOCRService.extractAnalysis(any(), docType: any(named: 'docType')))
          .thenAnswer((_) async => makeAnalysis(text));
      when(() => mockRefinement.call(any(), any()))
          .thenReturn(noChange('documento'));
      when(() => mockClassifier.extractDueDate(any())).thenReturn(null);
      when(() => mockRepository.updateDocument(any()))
          .thenAnswer((_) async => 1);

      // Act
      await useCase.call(1);

      // Assert: noteContent en el documento actualizado
      final captured =
          verify(() => mockRepository.updateDocument(captureAny()))
              .captured.single as DocumentModel;
      expect(captured.noteContent, text);
    });

    test('nota de impreso: texto largo → note_content truncado a 150 chars', () async {
      // Arrange
      final longText = 'A' * 200;
      final testDoc = createTestDocument();
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockOCRService.extractAnalysis(any(), docType: any(named: 'docType')))
          .thenAnswer((_) async => makeAnalysis(longText));
      when(() => mockRefinement.call(any(), any()))
          .thenReturn(noChange('documento'));
      when(() => mockClassifier.extractDueDate(any())).thenReturn(null);
      when(() => mockRepository.updateDocument(any()))
          .thenAnswer((_) async => 1);

      // Act
      await useCase.call(1);

      // Assert: noteContent truncado a 150 chars
      final captured =
          verify(() => mockRepository.updateDocument(captureAny()))
              .captured.single as DocumentModel;
      expect(captured.noteContent?.length, 150);
    });

    test('nota de manuscrito: note_content empieza con "Nota manuscrita de"', () async {
      // Arrange
      final testDoc = createTestDocument();
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockOCRService.extractAnalysis(any(), docType: any(named: 'docType')))
          .thenAnswer((_) async => makeAnalysis(
                'texto borroso',
                topConfidenceText: 'Hospital Central',
              ));
      when(() => mockRefinement.call(any(), any()))
          .thenReturn(RefinementResult(refinedClass: 'manuscrito'));
      when(() => mockClassifier.extractDueDate(any())).thenReturn(null);
      when(() => mockRepository.updateDocument(any()))
          .thenAnswer((_) async => 1);

      // Act
      await useCase.call(1, tfliteClass: 'manuscrito');

      // Assert
      final captured =
          verify(() => mockRepository.updateDocument(captureAny()))
              .captured.single as DocumentModel;
      expect(captured.noteContent, 'Nota manuscrita de Hospital Central');
    });

    test('nota de manuscrito sin palabras reconocibles: note_content = "Nota manuscrita"', () async {
      // Arrange
      final testDoc = createTestDocument();
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockOCRService.extractAnalysis(any(), docType: any(named: 'docType')))
          .thenAnswer((_) async => makeAnalysis(
                'texto muy borroso',
                topConfidenceText: '',
              ));
      when(() => mockRefinement.call(any(), any()))
          .thenReturn(RefinementResult(refinedClass: 'manuscrito'));
      when(() => mockClassifier.extractDueDate(any())).thenReturn(null);
      when(() => mockRepository.updateDocument(any()))
          .thenAnswer((_) async => 1);

      // Act
      await useCase.call(1, tfliteClass: 'manuscrito');

      // Assert
      final captured =
          verify(() => mockRepository.updateDocument(captureAny()))
              .captured.single as DocumentModel;
      expect(captured.noteContent, 'Nota manuscrita');
    });

    test('OCR vacío → note_content es null en el documento actualizado', () async {
      // Arrange
      final testDoc = createTestDocument();
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockOCRService.extractAnalysis(any(), docType: any(named: 'docType')))
          .thenAnswer((_) async => OcrAnalysis.empty);
      when(() => mockRefinement.call(any(), any()))
          .thenReturn(noChange('documento'));
      when(() => mockClassifier.extractDueDate('')).thenReturn(null);
      when(() => mockRepository.updateDocument(any()))
          .thenAnswer((_) async => 1);

      // Act
      await useCase.call(1);

      // Assert: texto vacío → noteContent null
      final captured =
          verify(() => mockRepository.updateDocument(captureAny()))
              .captured.single as DocumentModel;
      expect(captured.noteContent, isNull);
    });

    test('debe extraer fecha de vencimiento si existe', () async {
      // Arrange
      const extractedText = 'Vencimiento: 15/02/2026';
      final expectedDate = DateTime(2026, 2, 15);
      final testDoc = createTestDocument();
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockOCRService.extractAnalysis(any(), docType: any(named: 'docType')))
          .thenAnswer((_) async => makeAnalysis(extractedText));
      when(() => mockRefinement.call(any(), any()))
          .thenReturn(noChange('documento'));
      when(() => mockClassifier.extractDueDate(extractedText))
          .thenReturn(expectedDate);
      when(() => mockRepository.updateDocument(any()))
          .thenAnswer((_) async => 1);

      // Act
      await useCase.call(1);

      // Assert
      verify(() => mockClassifier.extractDueDate(extractedText)).called(1);
    });

    test('debe actualizar fecha extraída en documento', () async {
      // Arrange
      const extractedText = 'Pagar antes de: 31/12/2026';
      final expectedDate = DateTime(2026, 12, 31);
      final testDoc = createTestDocument();
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockOCRService.extractAnalysis(any(), docType: any(named: 'docType')))
          .thenAnswer((_) async => makeAnalysis(extractedText));
      when(() => mockRefinement.call(any(), any()))
          .thenReturn(noChange('documento'));
      when(() => mockClassifier.extractDueDate(extractedText))
          .thenReturn(expectedDate);
      when(() => mockRepository.updateDocument(any()))
          .thenAnswer((_) async => 1);

      // Act
      await useCase.call(1);

      // Assert
      final captured =
          verify(() => mockRepository.updateDocument(captureAny()))
              .captured.single as DocumentModel;
      expect(captured.extractedDate, expectedDate);
    });

    test('debe retornar documento actualizado', () async {
      // Arrange
      const extractedText = 'CONTRATO de alquiler';
      final testDoc = createTestDocument();
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockOCRService.extractAnalysis(any(), docType: any(named: 'docType')))
          .thenAnswer((_) async => makeAnalysis(extractedText));
      when(() => mockRefinement.call(any(), any()))
          .thenReturn(noChange('documento'));
      when(() => mockClassifier.extractDueDate(extractedText)).thenReturn(null);
      when(() => mockRepository.updateDocument(any()))
          .thenAnswer((_) async => 1);

      // Act
      final result = await useCase.call(1);

      // Assert
      expect(result, isA<DocumentModel>());
      expect(result.ocrText, extractedText);
    });

    test('manuscrito: ocrText empieza con aviso de errores', () async {
      // Arrange
      const rawText = 'Serviio iru gia nareela';
      final testDoc = createTestDocument();
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockOCRService.extractAnalysis(any(), docType: any(named: 'docType')))
          .thenAnswer((_) async => makeAnalysis(rawText));
      when(() => mockRefinement.call(any(), any()))
          .thenReturn(RefinementResult(refinedClass: 'manuscrito'));
      when(() => mockClassifier.extractDueDate(any())).thenReturn(null);
      when(() => mockRepository.updateDocument(any()))
          .thenAnswer((_) async => 1);

      // Act
      final result = await useCase.call(1, tfliteClass: 'manuscrito');

      // Assert
      expect(result.ocrText, startsWith('⚠️ Texto manuscrito'));
      expect(result.ocrText, contains(rawText));
    });

    test('cuando hay reclasificación → título se actualiza con nuevo tipo', () async {
      // Arrange
      final testDoc = createTestDocument();
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockOCRService.extractAnalysis(any(), docType: any(named: 'docType')))
          .thenAnswer((_) async => makeAnalysis('texto'));
      when(() => mockRefinement.call(any(), any())).thenReturn(
        RefinementResult(
          refinedClass: 'factura',
          correctionNote: 'documento → factura (2° paso: keywords + 132 bloques)',
        ),
      );
      when(() => mockClassifier.extractDueDate(any())).thenReturn(null);
      when(() => mockClassifier.getTypeDisplayName('factura', 'es'))
          .thenReturn('Factura');
      when(() => mockRepository.countByTypePrefix('Factura', any()))
          .thenAnswer((_) async => 0);
      when(() => mockClassifier.generateDocumentName('factura', any(), 'es', 1))
          .thenReturn('Factura 1 del 17/2');
      when(() => mockRepository.updateDocument(any())).thenAnswer((_) async => 1);

      // Act
      final result = await useCase.call(1, tfliteClass: 'documento', locale: 'es');

      // Assert
      expect(result.title, 'Factura 1 del 17/2');
    });

    test('manuscrito reclasificado desde documento: también lleva aviso', () async {
      // Arrange
      const rawText = 'texto con baja confianza';
      final testDoc = createTestDocument();
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockOCRService.extractAnalysis(any(), docType: any(named: 'docType')))
          .thenAnswer((_) async => makeAnalysis(rawText));
      when(() => mockRefinement.call(any(), any())).thenReturn(
        RefinementResult(
          refinedClass: 'manuscrito',
          correctionNote: 'documento → manuscrito (2° paso: confianza promedio baja: 0.37)',
        ),
      );
      when(() => mockClassifier.extractDueDate(any())).thenReturn(null);
      when(() => mockClassifier.getTypeDisplayName('manuscrito', any()))
          .thenReturn('Nota');
      when(() => mockRepository.countByTypePrefix('Nota', any()))
          .thenAnswer((_) async => 0);
      when(() => mockClassifier.generateDocumentName('manuscrito', any(), any(), any()))
          .thenReturn('Nota 1 del 17/2');
      when(() => mockRepository.updateDocument(any()))
          .thenAnswer((_) async => 1);

      // Act
      final result = await useCase.call(1, tfliteClass: 'documento');

      // Assert
      expect(result.ocrText, startsWith('⚠️ Texto manuscrito'));
      expect(result.ocrText, contains(rawText));
    });

    test('documento normal: ocrText sin aviso', () async {
      // Arrange
      const rawText = 'Informe médico del paciente';
      final testDoc = createTestDocument();
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockOCRService.extractAnalysis(any(), docType: any(named: 'docType')))
          .thenAnswer((_) async => makeAnalysis(rawText));
      when(() => mockRefinement.call(any(), any()))
          .thenReturn(noChange('documento'));
      when(() => mockClassifier.extractDueDate(any())).thenReturn(null);
      when(() => mockRepository.updateDocument(any()))
          .thenAnswer((_) async => 1);

      // Act
      final result = await useCase.call(1);

      // Assert
      expect(result.ocrText, equals(rawText));
      expect(result.ocrText, isNot(contains('⚠️')));
    });

    test('debe lanzar excepción si documento no existe', () async {
      // Arrange
      when(() => mockRepository.getDocumentById(999))
          .thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () async => await useCase.call(999),
        throwsA(isA<Exception>()),
      );
    });
  });
}
