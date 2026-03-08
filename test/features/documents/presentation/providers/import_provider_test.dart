import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/core/services/document_pipeline.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/domain/services/pdf_import_service.dart';
import 'package:escandoc/features/image_processing/classification/domain/classification_result.dart';
import 'package:escandoc/features/documents/presentation/providers/import_provider.dart';

class MockDocumentPipeline extends Mock implements DocumentPipeline {}

class MockPdfImportService extends Mock implements PdfImportService {}

class MockFile extends Mock implements File {}

void main() {
  late MockDocumentPipeline mockPipeline;
  late ImportProvider provider;

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
    mockPipeline = MockDocumentPipeline();
    provider = ImportProvider(pipeline: mockPipeline);
  });

  group('prepareImport', () {
    test('retorna PreparationResult en éxito', () async {
      when(() => mockPipeline.prepare(any(), onStatus: any(named: 'onStatus')))
          .thenAnswer((_) async => testPreparation);

      final result = await provider.prepareImport(mockFile);

      expect(result, testPreparation);
      expect(provider.isImporting, false);
      expect(provider.lastClassification?.type, DocumentType.documento);
    });

    test('retorna null y sets error en excepción', () async {
      when(() => mockPipeline.prepare(any(), onStatus: any(named: 'onStatus')))
          .thenThrow(Exception('import error'));

      final result = await provider.prepareImport(mockFile);

      expect(result, isNull);
      expect(provider.error, isNotNull);
      expect(provider.isImporting, false);
    });
  });

  group('completeImport', () {
    test('retorna documento guardado y limpia isSaving', () async {
      when(() => mockPipeline.complete(
            any(),
            any(),
            onStatus: any(named: 'onStatus'),
          )).thenAnswer((_) async => testDocument);
      when(() => mockPipeline.processOCRBackground(
            any(),
            any(),
            any(),
            onStatus: any(named: 'onStatus'),
          )).thenAnswer((_) async {});

      final result = await provider.completeImport(testPreparation, 'es');

      expect(result, testDocument);
      expect(provider.isSaving, false);
      expect(provider.lastImportedDocument, testDocument);
    });

    test('retorna null y sets error en excepción', () async {
      when(() => mockPipeline.complete(
            any(),
            any(),
            onStatus: any(named: 'onStatus'),
          )).thenThrow(Exception('save error'));

      final result = await provider.completeImport(testPreparation, 'es');

      expect(result, isNull);
      expect(provider.error, isNotNull);
      expect(provider.isSaving, false);
    });
  });

  group('checkPdfPageCount', () {
    test('retorna 0 si no hay PdfImportService', () async {
      final result = await provider.checkPdfPageCount('/some.pdf');

      expect(result, 0);
    });

    test('retorna número de páginas con servicio', () async {
      final mockPdfService = MockPdfImportService();
      when(() => mockPdfService.getPageCount(any())).thenAnswer((_) async => 5);
      final providerWithPdf = ImportProvider(
        pipeline: mockPipeline,
        pdfImportService: mockPdfService,
      );

      final result = await providerWithPdf.checkPdfPageCount('/doc.pdf');

      expect(result, 5);
    });
  });

  group('processingOcrIds', () {
    test('está vacío al inicio', () {
      expect(provider.processingOcrIds, isEmpty);
    });
  });

  group('clearError', () {
    test('limpia error', () async {
      when(() => mockPipeline.prepare(any(), onStatus: any(named: 'onStatus')))
          .thenThrow(Exception('error'));
      await provider.prepareImport(mockFile);
      expect(provider.error, isNotNull);

      provider.clearError();

      expect(provider.error, isNull);
    });
  });
}
