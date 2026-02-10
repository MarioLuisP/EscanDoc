import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:escandoc/features/scan/domain/usecases/process_ocr.dart';
import 'package:escandoc/core/services/ocr_service.dart';
import 'package:escandoc/core/services/document_classifier.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';

// Mocks
class MockOCRService extends Mock implements OCRService {}
class MockDocumentClassifier extends Mock implements DocumentClassifier {}
class MockDocumentRepository extends Mock implements DocumentRepository {}

// Fakes para registerFallbackValue
class FakeDocumentModel extends Fake implements DocumentModel {}
class FakeFile extends Fake implements File {}

void main() {
  late ProcessOCR useCase;
  late MockOCRService mockOCRService;
  late MockDocumentClassifier mockClassifier;
  late MockDocumentRepository mockRepository;
  late Directory tempDir;
  late File testJpgFile;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(FakeDocumentModel());
    registerFallbackValue(FakeFile());
  });

  setUp(() async {
    mockOCRService = MockOCRService();
    mockClassifier = MockDocumentClassifier();
    mockRepository = MockDocumentRepository();

    // Create temporary directory and test JPG file
    tempDir = await Directory.systemTemp.createTemp('process_ocr_test_');
    testJpgFile = File(path.join(tempDir.path, 'test_document.jpg'));
    await testJpgFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]); // Minimal JPG header

    useCase = ProcessOCR(
      mockOCRService,
      mockClassifier,
      mockRepository,
    );
  });

  tearDown(() async {
    // Clean up temporary files
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

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

    test('debe extraer texto con OCR desde JPG', () async {
      // Arrange
      final testDoc = createTestDocument();
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockOCRService.extractText(any()))
          .thenAnswer((_) async => 'Texto extraído del documento');
      when(() => mockClassifier.detectType(any())).thenReturn('documento');
      when(() => mockClassifier.extractDueDate(any())).thenReturn(null);
      when(() => mockRepository.updateDocument(any()))
          .thenAnswer((_) async => 1);

      // Act
      await useCase.call(1);

      // Assert - OCR debe ser llamado con el archivo JPG
      final captured = verify(() => mockOCRService.extractText(captureAny()))
          .captured.single as File;
      expect(captured.path, testJpgFile.path);
    });

    test('debe actualizar documento con ocr_text', () async {
      // Arrange
      const extractedText = 'Este es el texto extraído con OCR';
      final testDoc = createTestDocument();
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockOCRService.extractText(any()))
          .thenAnswer((_) async => extractedText);
      when(() => mockClassifier.detectType(extractedText)).thenReturn('factura');
      when(() => mockClassifier.extractDueDate(extractedText)).thenReturn(null);
      when(() => mockRepository.updateDocument(any()))
          .thenAnswer((_) async => 1);

      // Act
      await useCase.call(1);

      // Assert
      final captured = verify(() => mockRepository.updateDocument(captureAny()))
          .captured.single as DocumentModel;
      expect(captured.ocrText, extractedText);
    });

    test('debe detectar tipo después de OCR', () async {
      // Arrange
      const extractedText = 'FACTURA número 12345';
      final testDoc = createTestDocument();
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockOCRService.extractText(any()))
          .thenAnswer((_) async => extractedText);
      when(() => mockClassifier.detectType(extractedText)).thenReturn('factura');
      when(() => mockClassifier.extractDueDate(extractedText)).thenReturn(null);
      when(() => mockRepository.updateDocument(any()))
          .thenAnswer((_) async => 1);

      // Act
      await useCase.call(1);

      // Assert
      verify(() => mockClassifier.detectType(extractedText)).called(1);
    });

    test('debe procesar OCR y actualizar documento', () async {
      // Arrange
      const extractedText = 'RECIBO de pago mensual';
      final testDoc = createTestDocument();
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockOCRService.extractText(any()))
          .thenAnswer((_) async => extractedText);
      when(() => mockClassifier.detectType(extractedText)).thenReturn('recibo');
      when(() => mockClassifier.extractDueDate(extractedText)).thenReturn(null);
      when(() => mockRepository.updateDocument(any()))
          .thenAnswer((_) async => 1);

      // Act
      await useCase.call(1);

      // Assert
      final captured = verify(() => mockRepository.updateDocument(captureAny()))
          .captured.single as DocumentModel;
      expect(captured.ocrText, extractedText);
    });

    test('debe extraer fecha de vencimiento si existe', () async {
      // Arrange
      const extractedText = 'Vencimiento: 15/02/2026';
      final expectedDate = DateTime(2026, 2, 15);
      final testDoc = createTestDocument();
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockOCRService.extractText(any()))
          .thenAnswer((_) async => extractedText);
      when(() => mockClassifier.detectType(extractedText)).thenReturn('factura');
      when(() => mockClassifier.extractDueDate(extractedText)).thenReturn(expectedDate);
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
      when(() => mockOCRService.extractText(any()))
          .thenAnswer((_) async => extractedText);
      when(() => mockClassifier.detectType(extractedText)).thenReturn('factura');
      when(() => mockClassifier.extractDueDate(extractedText)).thenReturn(expectedDate);
      when(() => mockRepository.updateDocument(any()))
          .thenAnswer((_) async => 1);

      // Act
      await useCase.call(1);

      // Assert
      final captured = verify(() => mockRepository.updateDocument(captureAny()))
          .captured.single as DocumentModel;
      expect(captured.extractedDate, expectedDate);
    });

    test('debe manejar error de OCR sin fallar', () async {
      // Arrange
      final testDoc = createTestDocument();
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockOCRService.extractText(any()))
          .thenAnswer((_) async => ''); // OCR falló, retorna vacío
      when(() => mockClassifier.detectType('')).thenReturn('documento');
      when(() => mockClassifier.extractDueDate('')).thenReturn(null);
      when(() => mockRepository.updateDocument(any()))
          .thenAnswer((_) async => 1);

      // Act & Assert - no debe lanzar excepción
      await expectLater(useCase.call(1), completes);
    });

    test('debe retornar documento actualizado', () async {
      // Arrange
      const extractedText = 'CONTRATO de alquiler';
      final testDoc = createTestDocument();
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockOCRService.extractText(any()))
          .thenAnswer((_) async => extractedText);
      when(() => mockClassifier.detectType(extractedText)).thenReturn('contrato');
      when(() => mockClassifier.extractDueDate(extractedText)).thenReturn(null);
      when(() => mockRepository.updateDocument(any()))
          .thenAnswer((_) async => 1);

      // Act
      final result = await useCase.call(1);

      // Assert
      expect(result, isA<DocumentModel>());
      expect(result.ocrText, extractedText);
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
