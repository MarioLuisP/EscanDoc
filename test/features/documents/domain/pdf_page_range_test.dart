import 'package:flutter_test/flutter_test.dart';
import 'package:escandoc/features/documents/domain/pdf_page_range.dart';

void main() {
  group('PdfPageRange.all', () {
    test('todas las páginas: 1..total', () {
      final range = PdfPageRange.all(30);
      expect(range.from, 1);
      expect(range.to, 30);
      expect(range.count, 30);
    });

    test('total inválido (0) se corrige a 1 página', () {
      final range = PdfPageRange.all(0);
      expect(range.from, 1);
      expect(range.to, 1);
      expect(range.count, 1);
    });
  });

  group('PdfPageRange.clamp', () {
    test('rango normal dentro de límites', () {
      final range = PdfPageRange.clamp(3, 5, 30);
      expect(range.from, 3);
      expect(range.to, 5);
      expect(range.count, 3);
    });

    test('una sola página (desde == hasta)', () {
      final range = PdfPageRange.clamp(2, 2, 2);
      expect(range.from, 2);
      expect(range.to, 2);
      expect(range.count, 1);
      expect(range.isSingle, true);
    });

    test('caso portada: PDF de 2 páginas, traer solo la 2', () {
      final range = PdfPageRange.clamp(2, 2, 2);
      expect(range.pageIndices, [1]); // índice 0-based de la página 2
    });

    test('desde > hasta se intercambia', () {
      final range = PdfPageRange.clamp(5, 3, 30);
      expect(range.from, 3);
      expect(range.to, 5);
    });

    test('valores fuera de rango se ajustan a [1, total]', () {
      final range = PdfPageRange.clamp(0, 100, 30);
      expect(range.from, 1);
      expect(range.to, 30);
    });

    test('hasta mayor al total se recorta al total', () {
      final range = PdfPageRange.clamp(2, 100, 2);
      expect(range.from, 2);
      expect(range.to, 2);
      expect(range.count, 1);
    });

    test('pageIndices devuelve índices 0-based del tramo', () {
      final range = PdfPageRange.clamp(3, 5, 30);
      expect(range.pageIndices, [2, 3, 4]);
    });
  });

  group('igualdad', () {
    test('dos rangos con mismos límites son iguales', () {
      expect(PdfPageRange.clamp(2, 5, 30), PdfPageRange.clamp(2, 5, 30));
    });

    test('rangos distintos no son iguales', () {
      expect(PdfPageRange.clamp(2, 5, 30) == PdfPageRange.clamp(2, 6, 30), false);
    });
  });
}
