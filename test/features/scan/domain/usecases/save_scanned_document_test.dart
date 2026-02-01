import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/scan/domain/usecases/save_scanned_document.dart';
import 'package:escandoc/core/services/pdf_generator.dart';
import 'package:escandoc/core/services/document_classifier.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';

// Mocks
class MockPDFGenerator extends Mock implements PDFGenerator {}
class MockDocumentClassifier extends Mock implements DocumentClassifier {}
class MockDocumentRepository extends Mock implements DocumentRepository {}

// Fakes para registerFallbackValue
class FakeDocumentModel extends Fake implements DocumentModel {}
class FakeFile extends Fake implements File {}

void main() {
  late SaveScannedDocument useCase;
  late MockPDFGenerator mockPDFGenerator;
  late MockDocumentClassifier mockClassifier;
  late MockDocumentRepository mockRepository;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(FakeDocumentModel());
    registerFallbackValue(FakeFile());
  });

  setUp(() {
    mockPDFGenerator = MockPDFGenerator();
    mockClassifier = MockDocumentClassifier();
    mockRepository = MockDocumentRepository();

    useCase = SaveScannedDocument(
      mockPDFGenerator,
      mockClassifier,
      mockRepository,
    );
  });

  group('SaveScannedDocument - Imagen escaneada', () {
    final testImage = File('scanned_image.jpg');
    final testPDF = File('document.pdf');
    final testThumbnail = File('thumbnail.jpg');
    final now = DateTime(2026, 1, 25);

    test('debe generar PDF desde imagen', () async {
      // Arrange
      when(() => mockPDFGenerator.createPDF(any(), any()))
          .thenAnswer((_) async => testPDF);
      when(() => mockPDFGenerator.generateThumbnail(any(), any()))
          .thenAnswer((_) async => testThumbnail);
      when(() => mockClassifier.detectType(any())).thenReturn('documento');
      when(() => mockClassifier.generateDocumentName(any(), any(), any()))
          .thenReturn('documento_25_Ene_2026');
      when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => 1);

      // Act
      await useCase.call(testImage, '/test/output', 'es', currentDate: now);

      // Assert
      verify(() => mockPDFGenerator.createPDF(testImage, any())).called(1);
    });

    test('debe generar thumbnail', () async {
      // Arrange
      when(() => mockPDFGenerator.createPDF(any(), any()))
          .thenAnswer((_) async => testPDF);
      when(() => mockPDFGenerator.generateThumbnail(any(), any()))
          .thenAnswer((_) async => testThumbnail);
      when(() => mockClassifier.detectType(any())).thenReturn('documento');
      when(() => mockClassifier.generateDocumentName(any(), any(), any()))
          .thenReturn('documento_25_Ene_2026');
      when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => 1);

      // Act
      await useCase.call(testImage, '/test/output', 'es', currentDate: now);

      // Assert
      verify(() => mockPDFGenerator.generateThumbnail(testImage, any())).called(1);
    });

    test('debe detectar tipo automáticamente', () async {
      // Arrange
      when(() => mockPDFGenerator.createPDF(any(), any()))
          .thenAnswer((_) async => testPDF);
      when(() => mockPDFGenerator.generateThumbnail(any(), any()))
          .thenAnswer((_) async => testThumbnail);
      when(() => mockClassifier.detectType('')).thenReturn('documento');
      when(() => mockClassifier.generateDocumentName(any(), any(), any()))
          .thenReturn('documento_25_Ene_2026');
      when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => 1);

      // Act
      await useCase.call(testImage, '/test/output', 'es', currentDate: now);

      // Assert
      verify(() => mockClassifier.detectType('')).called(1);
    });

    test('debe generar nombre localizado', () async {
      // Arrange
      when(() => mockPDFGenerator.createPDF(any(), any()))
          .thenAnswer((_) async => testPDF);
      when(() => mockPDFGenerator.generateThumbnail(any(), any()))
          .thenAnswer((_) async => testThumbnail);
      when(() => mockClassifier.detectType(any())).thenReturn('factura');
      when(() => mockClassifier.generateDocumentName('factura', now, 'es'))
          .thenReturn('factura_25_Ene_2026');
      when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => 1);

      // Act
      await useCase.call(testImage, '/test/output', 'es', currentDate: now);

      // Assert
      verify(() => mockClassifier.generateDocumentName('factura', now, 'es')).called(1);
    });

    test('debe guardar en BD con metadata', () async {
      // Arrange
      when(() => mockPDFGenerator.createPDF(any(), any()))
          .thenAnswer((_) async => testPDF);
      when(() => mockPDFGenerator.generateThumbnail(any(), any()))
          .thenAnswer((_) async => testThumbnail);
      when(() => mockClassifier.detectType(any())).thenReturn('factura');
      when(() => mockClassifier.generateDocumentName(any(), any(), any()))
          .thenReturn('factura_25_Ene_2026');
      when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => 1);

      // Act
      final result = await useCase.call(testImage, '/test/output', 'es', currentDate: now);

      // Assert
      verify(() => mockRepository.insertDocument(any())).called(1);
      expect(result, isA<DocumentModel>());
      expect(result.title, 'factura_25_Ene_2026');
      expect(result.docType, 'factura');
    });

    test('debe usar fecha actual para nombre', () async {
      // Arrange
      final customDate = DateTime(2026, 12, 31);
      when(() => mockPDFGenerator.createPDF(any(), any()))
          .thenAnswer((_) async => testPDF);
      when(() => mockPDFGenerator.generateThumbnail(any(), any()))
          .thenAnswer((_) async => testThumbnail);
      when(() => mockClassifier.detectType(any())).thenReturn('recibo');
      when(() => mockClassifier.generateDocumentName('recibo', customDate, 'es'))
          .thenReturn('recibo_31_Dic_2026');
      when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => 1);

      // Act
      await useCase.call(testImage, '/test/output', 'es', currentDate: customDate);

      // Assert
      verify(() => mockClassifier.generateDocumentName('recibo', customDate, 'es')).called(1);
    });

    test('debe retornar documento guardado con ID', () async {
      // Arrange
      when(() => mockPDFGenerator.createPDF(any(), any()))
          .thenAnswer((_) async => testPDF);
      when(() => mockPDFGenerator.generateThumbnail(any(), any()))
          .thenAnswer((_) async => testThumbnail);
      when(() => mockClassifier.detectType(any())).thenReturn('factura');
      when(() => mockClassifier.generateDocumentName(any(), any(), any()))
          .thenReturn('factura_25_Ene_2026');
      when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => 123);

      // Act
      final result = await useCase.call(testImage, '/test/output', 'es', currentDate: now);

      // Assert
      expect(result.id, 123);
      expect(result.title, 'factura_25_Ene_2026');
    });
  });

  group('SaveScannedDocument - PDF escaneado', () {
    final testScannedPDF = File('scanned_document.pdf');
    final testCopiedPDF = File('pdf_123456.pdf');
    final testExtractedImage = File('page_123456.png');
    final testThumbnail = File('thumb_123456.jpg');
    final now = DateTime(2026, 1, 25);

    test('debe copiar PDF cuando el scanner devuelve PDF', () async {
      // Arrange
      when(() => mockPDFGenerator.copyPDF(any(), any()))
          .thenAnswer((_) async => testCopiedPDF);
      when(() => mockPDFGenerator.extractFirstPageAsImage(any(), any()))
          .thenAnswer((_) async => testExtractedImage);
      when(() => mockPDFGenerator.generateThumbnail(any(), any()))
          .thenAnswer((_) async => testThumbnail);
      when(() => mockClassifier.detectType(any())).thenReturn('documento');
      when(() => mockClassifier.generateDocumentName(any(), any(), any()))
          .thenReturn('documento_25_Ene_2026');
      when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => 1);

      // Act
      await useCase.call(testScannedPDF, '/test/output', 'es', currentDate: now);

      // Assert - debe llamar copyPDF
      verify(() => mockPDFGenerator.copyPDF(testScannedPDF, any())).called(1);

      // Y debe haber guardado un PDF
      final captured = verify(
        () => mockRepository.insertDocument(captureAny()),
      ).captured.first as DocumentModel;

      expect(captured.filePath, contains('.pdf'));
    });

    test('debe extraer primera página como imagen desde PDF', () async {
      // Arrange
      when(() => mockPDFGenerator.copyPDF(any(), any()))
          .thenAnswer((_) async => testCopiedPDF);
      when(() => mockPDFGenerator.extractFirstPageAsImage(any(), any()))
          .thenAnswer((_) async => testExtractedImage);
      when(() => mockPDFGenerator.generateThumbnail(any(), any()))
          .thenAnswer((_) async => testThumbnail);
      when(() => mockClassifier.detectType(any())).thenReturn('documento');
      when(() => mockClassifier.generateDocumentName(any(), any(), any()))
          .thenReturn('documento_25_Ene_2026');
      when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => 1);

      // Act
      await useCase.call(testScannedPDF, '/test/output', 'es', currentDate: now);

      // Assert - debe llamar extractFirstPageAsImage
      verify(() => mockPDFGenerator.extractFirstPageAsImage(any(), any())).called(1);
    });

    test('debe generar thumbnail desde imagen extraída del PDF', () async {
      // Arrange
      when(() => mockPDFGenerator.copyPDF(any(), any()))
          .thenAnswer((_) async => testCopiedPDF);
      when(() => mockPDFGenerator.extractFirstPageAsImage(any(), any()))
          .thenAnswer((_) async => testExtractedImage);
      when(() => mockPDFGenerator.generateThumbnail(any(), any()))
          .thenAnswer((_) async => testThumbnail);
      when(() => mockClassifier.detectType(any())).thenReturn('documento');
      when(() => mockClassifier.generateDocumentName(any(), any(), any()))
          .thenReturn('documento_25_Ene_2026');
      when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => 1);

      // Act
      await useCase.call(testScannedPDF, '/test/output', 'es', currentDate: now);

      // Assert - debe llamar generateThumbnail con la imagen extraída
      verify(() => mockPDFGenerator.generateThumbnail(testExtractedImage, any())).called(1);
    });

    test('debe guardar documento con thumbnailPath válido', () async {
      // Arrange
      when(() => mockPDFGenerator.copyPDF(any(), any()))
          .thenAnswer((_) async => testCopiedPDF);
      when(() => mockPDFGenerator.extractFirstPageAsImage(any(), any()))
          .thenAnswer((_) async => testExtractedImage);
      when(() => mockPDFGenerator.generateThumbnail(any(), any()))
          .thenAnswer((_) async => testThumbnail);
      when(() => mockClassifier.detectType(any())).thenReturn('factura');
      when(() => mockClassifier.generateDocumentName(any(), any(), any()))
          .thenReturn('factura_25_Ene_2026');
      when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => 1);

      // Act
      final result = await useCase.call(testScannedPDF, '/test/output', 'es', currentDate: now);

      // Assert
      expect(result.thumbnailPath, isNotNull);
      expect(result.thumbnailPath, contains('.jpg'));
    });
  });
}
