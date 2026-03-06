import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/scan/domain/usecases/save_scanned_document.dart';
import 'package:escandoc/core/services/document_classifier.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';
import 'package:escandoc/features/image_processing/classification/domain/classification_result.dart';

// Mocks
class MockDocumentClassifier extends Mock implements DocumentClassifier {}
class MockDocumentRepository extends Mock implements DocumentRepository {}

// Fakes para registerFallbackValue
class FakeDocumentModel extends Fake implements DocumentModel {}

void main() {
  late SaveScannedDocument useCase;
  late MockDocumentClassifier mockClassifier;
  late MockDocumentRepository mockRepository;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(FakeDocumentModel());
  });

  setUp(() {
    mockClassifier = MockDocumentClassifier();
    mockRepository = MockDocumentRepository();

    useCase = SaveScannedDocument(
      mockClassifier,
      mockRepository,
    );
  });

  // Helper para stubs mínimos en cada test
  void stubDefaults({
    DocumentType tfliteKind = DocumentType.documento,
    String locale = 'es',
    String displayName = 'Documento',
    int todayCount = 0,
    String generatedName = 'Documento 1 del 25/1',
    int insertedId = 1,
  }) {
    when(() => mockClassifier.getTypeDisplayName(tfliteKind, locale))
        .thenReturn(displayName);
    when(() => mockRepository.countByTypePrefix(displayName, any()))
        .thenAnswer((_) async => todayCount);
    when(() => mockClassifier.generateDocumentName(tfliteKind, any(), locale, todayCount + 1))
        .thenReturn(generatedName);
    when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => insertedId);
  }

  group('SaveScannedDocument - Guardado JPG', () {
    final testImage = File('scanned_image.jpg');
    final now = DateTime(2026, 1, 25);

    test('debe guardar JPG directamente como filePath', () async {
      stubDefaults();

      final result = await useCase.call(testImage, '/test/output', 'es', currentDate: now);

      expect(result.filePath, testImage.path);
      expect(result.filePath, endsWith('.jpg'));
    });

    test('nombre usa el tipo TFLite y número secuencial', () async {
      stubDefaults(
        tfliteKind: DocumentType.factura,
        displayName: 'Factura',
        todayCount: 0,
        generatedName: 'Factura 1 del 25/1',
      );

      final result = await useCase.call(
        testImage, '/test/output', 'es',
        currentDate: now,
        tfliteKind: DocumentType.factura,
      );

      expect(result.title, 'Factura 1 del 25/1');
    });

    test('si ya hay 2 facturas hoy → nuevo es Factura 3', () async {
      stubDefaults(
        tfliteKind: DocumentType.factura,
        displayName: 'Factura',
        todayCount: 2,
        generatedName: 'Factura 3 del 25/1',
      );

      final result = await useCase.call(
        testImage, '/test/output', 'es',
        currentDate: now,
        tfliteKind: DocumentType.factura,
      );

      expect(result.title, 'Factura 3 del 25/1');
      verify(() => mockClassifier.generateDocumentName(DocumentType.factura, any(), 'es', 3)).called(1);
    });

    test('manuscrito → nombre es "Nota N del D/M"', () async {
      stubDefaults(
        tfliteKind: DocumentType.manuscrito,
        displayName: 'Nota',
        generatedName: 'Nota 1 del 25/1',
      );

      final result = await useCase.call(
        testImage, '/test/output', 'es',
        currentDate: now,
        tfliteKind: DocumentType.manuscrito,
      );

      expect(result.title, 'Nota 1 del 25/1');
    });

    test('debe retornar documento con ID de BD', () async {
      stubDefaults(insertedId: 123);

      final result = await useCase.call(testImage, '/test/output', 'es', currentDate: now);

      expect(result.id, 123);
    });

    test('debe guardar en BD', () async {
      stubDefaults();

      await useCase.call(testImage, '/test/output', 'es', currentDate: now);

      verify(() => mockRepository.insertDocument(any())).called(1);
    });

    test('filePath del documento insertado apunta al JPG', () async {
      stubDefaults();

      await useCase.call(testImage, '/test/output', 'es', currentDate: now);

      final captured = verify(() => mockRepository.insertDocument(captureAny()))
          .captured.first as DocumentModel;
      expect(captured.filePath, testImage.path);
    });
  });

}
