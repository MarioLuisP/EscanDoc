import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/core/services/document_pipeline.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/image_processing/classification/domain/classification_result.dart';
import 'package:escandoc/features/scan/domain/usecases/scan_document.dart';
import 'package:escandoc/features/scan/presentation/providers/scan_provider.dart';

class MockScanDocument extends Mock implements ScanDocument {}

class MockDocumentPipeline extends Mock implements DocumentPipeline {}

class MockFile extends Mock implements File {}

void main() {
  late MockScanDocument mockScanDocument;
  late MockDocumentPipeline mockPipeline;
  late ScanProvider provider;

  final mockFile = MockFile();
  final testDocument = DocumentModel(
    id: 1,
    title: 'Factura',
    filePath: '/docs/factura.jpg',
    createdAt: DateTime(2026, 1, 1),
  );
  final testPreparation = PreparationResult(
    processedFile: mockFile,
    classification: ClassificationResult(
      type: DocumentType.documento,
      confidence: 0.9,
    ),
    isNormalized: true,
  );

  setUpAll(() {
    registerFallbackValue(mockFile);
    registerFallbackValue(testPreparation);
    registerFallbackValue(DocumentType.documento);
  });

  setUp(() {
    mockScanDocument = MockScanDocument();
    mockPipeline = MockDocumentPipeline();
    provider = ScanProvider(
      scanDocument: mockScanDocument,
      pipeline: mockPipeline,
    );
  });

  group('prepareScan', () {
    test('retorna null cuando el usuario cancela', () async {
      when(() => mockScanDocument.call()).thenAnswer((_) async => null);

      final result = await provider.prepareScan();

      expect(result, isNull);
      expect(provider.isScanning, false);
      verifyNever(() => mockPipeline.prepare(any()));
    });

    test('retorna PreparationResult en éxito', () async {
      when(() => mockScanDocument.call()).thenAnswer((_) async => mockFile);
      when(() => mockPipeline.prepare(any()))
          .thenAnswer((_) async => testPreparation);

      final result = await provider.prepareScan();

      expect(result, testPreparation);
      expect(provider.isScanning, false);
      expect(provider.lastClassification?.type, DocumentType.documento);
    });

    test('sets error y retorna null en excepción', () async {
      when(() => mockScanDocument.call()).thenThrow(Exception('camera error'));

      final result = await provider.prepareScan();

      expect(result, isNull);
      expect(provider.error, isNotNull);
      expect(provider.isScanning, false);
    });
  });

  group('completeScan', () {
    test('retorna documento guardado y limpia isSaving', () async {
      when(() => mockPipeline.complete(any(), any()))
          .thenAnswer((_) async => testDocument);
      when(() => mockPipeline.processOCRBackground(any(), any(), any()))
          .thenAnswer((_) async {});

      final result = await provider.completeScan(testPreparation, 'es');

      expect(result, testDocument);
      expect(provider.isSaving, false);
      expect(provider.lastScannedDocument, testDocument);
    });

    test('sets error y retorna null en excepción', () async {
      when(() => mockPipeline.complete(any(), any()))
          .thenThrow(Exception('save error'));

      final result = await provider.completeScan(testPreparation, 'es');

      expect(result, isNull);
      expect(provider.error, isNotNull);
      expect(provider.isSaving, false);
    });
  });

  group('clearError', () {
    test('limpia error', () async {
      when(() => mockScanDocument.call()).thenThrow(Exception('error'));
      await provider.prepareScan();
      expect(provider.error, isNotNull);

      provider.clearError();

      expect(provider.error, isNull);
    });
  });
}
