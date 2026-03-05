import 'package:flutter_test/flutter_test.dart';
import 'package:escandoc/core/services/a4_normalizer_service.dart';

void main() {
  group('A4NormalizerService.calculateA4Fit', () {
    const a4W = 2480.0;
    const a4H = 3508.0;

    test('imagen portrait (3000x4000) llena el ancho, bandas arriba/abajo', () {
      final fit = A4NormalizerService.calculateA4Fit(3000, 4000);

      expect(fit.scaledW, closeTo(a4W, 1));
      expect(fit.scaledH, lessThanOrEqualTo(a4H));
      expect(fit.dx, closeTo(0, 1));
      expect(fit.dy, greaterThan(0));
    });

    test('imagen landscape (4000x3000) llena el ancho, bandas arriba/abajo', () {
      final fit = A4NormalizerService.calculateA4Fit(4000, 3000);

      expect(fit.scaledW, closeTo(a4W, 1));
      expect(fit.scaledH, lessThanOrEqualTo(a4H));
      expect(fit.dx, closeTo(0, 1));
      expect(fit.dy, greaterThan(0));
    });

    test('imagen alta y angosta (800x4000) llena el alto, bandas izq/der', () {
      final fit = A4NormalizerService.calculateA4Fit(800, 4000);

      expect(fit.scaledH, closeTo(a4H, 1));
      expect(fit.scaledW, lessThanOrEqualTo(a4W));
      expect(fit.dy, closeTo(0, 1));
      expect(fit.dx, greaterThan(0));
    });

    test('imagen ya es A4 exacto → scale 1.0, sin bandas', () {
      final fit = A4NormalizerService.calculateA4Fit(2480, 3508);

      expect(fit.scale, closeTo(1.0, 0.001));
      expect(fit.dx, closeTo(0, 1));
      expect(fit.dy, closeTo(0, 1));
      expect(fit.scaledW, 2480);
      expect(fit.scaledH, 3508);
    });

    test('imagen cuadrada (2000x2000) llena el ancho, bandas arriba/abajo', () {
      final fit = A4NormalizerService.calculateA4Fit(2000, 2000);

      expect(fit.scaledW, closeTo(a4W, 1));
      expect(fit.scaledH, lessThan(a4H));
      expect(fit.dx, closeTo(0, 1));
      expect(fit.dy, greaterThan(0));
    });

    test('el resultado siempre cabe dentro del A4', () {
      final sizes = [
        (100, 200),
        (800, 600),
        (1200, 1200),
        (500, 3000),
        (3000, 500),
        (4032, 3024), // foto típica de celular landscape
        (3024, 4032), // foto típica de celular portrait
      ];

      for (final (w, h) in sizes) {
        final fit = A4NormalizerService.calculateA4Fit(w, h);
        expect(fit.scaledW, lessThanOrEqualTo(a4W + 1),
            reason: 'scaledW excede A4 para ${w}x$h');
        expect(fit.scaledH, lessThanOrEqualTo(a4H + 1),
            reason: 'scaledH excede A4 para ${w}x$h');
        expect(fit.dx, greaterThanOrEqualTo(0),
            reason: 'dx negativo para ${w}x$h');
        expect(fit.dy, greaterThanOrEqualTo(0),
            reason: 'dy negativo para ${w}x$h');
      }
    });

    test('siempre al menos un borde toca el limite del A4', () {
      final sizes = [
        (100, 200),
        (800, 600),
        (3024, 4032),
        (4032, 3024),
      ];

      for (final (w, h) in sizes) {
        final fit = A4NormalizerService.calculateA4Fit(w, h);
        final fillsWidth = (fit.scaledW - a4W).abs() < 1;
        final fillsHeight = (fit.scaledH - a4H).abs() < 1;
        expect(fillsWidth || fillsHeight, isTrue,
            reason: 'ningún borde toca el limite del A4 para ${w}x$h');
      }
    });

    test('las bandas son simétricas (imagen centrada)', () {
      // Imagen portrait: bandas arriba/abajo iguales
      final portrait = A4NormalizerService.calculateA4Fit(3000, 4000);
      expect(portrait.dx, closeTo(0, 1)); // sin banda horizontal
      expect(portrait.dy, greaterThan(0)); // banda vertical centrada

      // Imagen tall narrow: bandas izq/der iguales
      final narrow = A4NormalizerService.calculateA4Fit(800, 4000);
      expect(narrow.dx, greaterThan(0)); // banda horizontal centrada
      expect(narrow.dy, closeTo(0, 1)); // sin banda vertical
    });
  });
}
