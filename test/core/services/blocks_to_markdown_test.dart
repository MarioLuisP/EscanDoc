import 'package:flutter_test/flutter_test.dart';
import 'package:escandoc/core/services/blocks_to_markdown.dart';
import '../../helpers/fixture_loader.dart';

void main() {
  group('blocksToMarkdown — golden tests', () {
    test('documento_plano', () {
      final blocks = loadFixture('documento_plano');
      final result = blocksToMarkdown(blocks, DocumentType.documento, 0);
      expectMatchesGolden('documento_plano', result);
    });

    test('receta', () {
      final blocks = loadFixture('receta');
      final result = blocksToMarkdown(blocks, DocumentType.documento, 0);
      expectMatchesGolden('receta', result);
    });

    test('horario', () {
      final blocks = loadFixture('horario');
      final result = blocksToMarkdown(blocks, DocumentType.documento, 0);
      expectMatchesGolden('horario', result);
    });

    test('factura_luz', () {
      final blocks = loadFixture('factura_luz');
      final result = blocksToMarkdown(blocks, DocumentType.factura, 0);
      expectMatchesGolden('factura_luz', result);
    });

    test('factura_agua', () {
      final blocks = loadFixture('factura_agua');
      final result = blocksToMarkdown(blocks, DocumentType.factura, 0);
      expectMatchesGolden('factura_agua', result);
    });

    test('tiket', () {
      final blocks = loadFixture('tiket');
      final result = blocksToMarkdown(blocks, DocumentType.recibo, 0);
      expectMatchesGolden('tiket', result);
    });

    test('folleto', () {
      final blocks = loadFixture('folleto');
      final result = blocksToMarkdown(blocks, DocumentType.folleto, 0);
      expectMatchesGolden('folleto', result);
    });

    test('test_ocr', () {
      final blocks = loadFixture('test_ocr');
      final result = blocksToMarkdown(blocks, DocumentType.factura, 0);
      expectMatchesGolden('test_ocr', result);
    });
  });
}
