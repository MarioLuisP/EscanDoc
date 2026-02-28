import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/documents/domain/services/pdf_import_service.dart';

class MockPdfImportService extends Mock implements PdfImportService {}

void main() {
  late PdfImportService mockService;

  setUp(() {
    mockService = MockPdfImportService();
    registerFallbackValue(File(''));
  });

  group('PdfImportService — contrato', () {
    const pdfPath = '/storage/docs/contrato.pdf';
    const outputDir = '/storage/temp';

    test('getPageCount retorna número de páginas del PDF', () async {
      when(() => mockService.getPageCount(pdfPath))
          .thenAnswer((_) async => 5);

      final count = await mockService.getPageCount(pdfPath);

      expect(count, 5);
      verify(() => mockService.getPageCount(pdfPath)).called(1);
    });

    test('getPageCount retorna 1 para PDF de una página', () async {
      when(() => mockService.getPageCount(pdfPath))
          .thenAnswer((_) async => 1);

      final count = await mockService.getPageCount(pdfPath);

      expect(count, 1);
    });

    test('renderPagesToJpg retorna lista de Files JPG', () async {
      final expectedFiles = [
        File('/storage/temp/page_0.jpg'),
        File('/storage/temp/page_1.jpg'),
        File('/storage/temp/page_2.jpg'),
      ];

      when(() => mockService.renderPagesToJpg(pdfPath, outputDir))
          .thenAnswer((_) async => expectedFiles);

      final result = await mockService.renderPagesToJpg(pdfPath, outputDir);

      expect(result.length, 3);
      expect(result.first.path, endsWith('.jpg'));
      verify(() => mockService.renderPagesToJpg(pdfPath, outputDir)).called(1);
    });

    test('renderPagesToJpg respeta maxPages — PDF con 15 páginas, pide 10', () async {
      final tenFiles = List.generate(
        10,
        (i) => File('/storage/temp/page_$i.jpg'),
      );

      when(() => mockService.renderPagesToJpg(pdfPath, outputDir, maxPages: 10))
          .thenAnswer((_) async => tenFiles);

      final result = await mockService.renderPagesToJpg(
        pdfPath,
        outputDir,
        maxPages: 10,
      );

      expect(result.length, 10);
    });

    test('renderPagesToJpg con PDF de 3 páginas y maxPages 10 retorna 3', () async {
      final threeFiles = List.generate(
        3,
        (i) => File('/storage/temp/page_$i.jpg'),
      );

      when(() => mockService.renderPagesToJpg(pdfPath, outputDir, maxPages: 10))
          .thenAnswer((_) async => threeFiles);

      final result = await mockService.renderPagesToJpg(
        pdfPath,
        outputDir,
        maxPages: 10,
      );

      // Si el PDF tiene menos páginas que maxPages, retorna todas
      expect(result.length, 3);
    });

    test('getPageCount lanza PdfImportException para PDF inválido', () async {
      when(() => mockService.getPageCount(pdfPath))
          .thenThrow(PdfImportException('Invalid PDF', pdfPath));

      expect(
        () => mockService.getPageCount(pdfPath),
        throwsA(isA<PdfImportException>()),
      );
    });

    test('renderPagesToJpg lanza PdfImportException si renderización falla', () async {
      when(() => mockService.renderPagesToJpg(pdfPath, outputDir))
          .thenThrow(PdfImportException('Render failed', pdfPath));

      expect(
        () => mockService.renderPagesToJpg(pdfPath, outputDir),
        throwsA(isA<PdfImportException>()),
      );
    });

    test('PdfImportException incluye path y mensaje en toString', () {
      final e = PdfImportException('PDF corrupto', pdfPath);
      expect(e.toString(), contains('PDF corrupto'));
      expect(e.toString(), contains(pdfPath));
    });
  });
}
