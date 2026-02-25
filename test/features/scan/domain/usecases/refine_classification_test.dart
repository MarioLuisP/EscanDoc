import 'package:flutter_test/flutter_test.dart';
import 'package:escandoc/core/services/ocr_analysis.dart';
import 'package:escandoc/features/scan/domain/usecases/refine_classification.dart';

void main() {
  late RefineClassification useCase;

  setUp(() {
    useCase = RefineClassification();
  });

  // Helpers
  OcrAnalysis analysis({
    String text = '',
    int blockCount = 10,
    required double avgConf,
  }) =>
      OcrAnalysis(text: text, blockCount: blockCount, avgConfidence: avgConf);

  OcrAnalysis highConf({String text = '', int blockCount = 30}) =>
      analysis(text: text, blockCount: blockCount, avgConf: 0.88);

  OcrAnalysis lowConf({String text = '', int blockCount = 12}) =>
      analysis(text: text, blockCount: blockCount, avgConf: 0.38);

  OcrAnalysis invoiceAnalysis() => analysis(
        text: 'CUIT 20-12345678-9 Período Mayo 2026 Total a pagar \$4.500',
        blockCount: 120,
        avgConf: 0.82,
      );

  // ═══════════════════════════════════════
  // Tipos intocables
  // ═══════════════════════════════════════

  group('tipos intocables', () {
    for (final type in ['foto', 'folleto', 'recibo']) {
      test('$type queda como $type sin nota', () {
        final result = useCase.call(type, highConf());
        expect(result.refinedClass, type);
        expect(result.correctionNote, isNull);
        expect(result.wasReclassified, isFalse);
      });
    }
  });

  // ═══════════════════════════════════════
  // documento → manuscrito
  // ═══════════════════════════════════════

  group('documento con baja confianza', () {
    test('→ manuscrito', () {
      final result = useCase.call('documento', lowConf());
      expect(result.refinedClass, 'manuscrito');
    });

    test('genera nota con confianza', () {
      final result = useCase.call('documento', lowConf());
      expect(result.correctionNote, contains('documento → manuscrito'));
      expect(result.correctionNote, contains('2° paso'));
      expect(result.correctionNote, contains('0.38'));
    });

    test('wasReclassified es true', () {
      final result = useCase.call('documento', lowConf());
      expect(result.wasReclassified, isTrue);
    });
  });

  // ═══════════════════════════════════════
  // documento → documento (sin cambio)
  // ═══════════════════════════════════════

  group('documento con alta confianza sin keywords', () {
    test('→ documento sin nota', () {
      final result = useCase.call('documento', highConf(text: 'Informe médico'));
      expect(result.refinedClass, 'documento');
      expect(result.correctionNote, isNull);
      expect(result.wasReclassified, isFalse);
    });
  });

  // ═══════════════════════════════════════
  // documento → factura
  // ═══════════════════════════════════════

  group('documento con alta confianza + keywords + bloques > 80', () {
    test('→ factura', () {
      final result = useCase.call('documento', invoiceAnalysis());
      expect(result.refinedClass, 'factura');
    });

    test('genera nota con bloques y keyword', () {
      final result = useCase.call('documento', invoiceAnalysis());
      expect(result.correctionNote, contains('documento → factura'));
      expect(result.correctionNote, contains('2° paso'));
      expect(result.correctionNote, contains('120 bloques'));
    });
  });

  group('documento con keywords pero bloques <= 80', () {
    test('→ documento sin nota (no suficientes bloques)', () {
      final a = analysis(
        text: 'CUIT 20-12345678-9 Total a pagar \$1.000',
        blockCount: 50,
        avgConf: 0.85,
      );
      final result = useCase.call('documento', a);
      expect(result.refinedClass, 'documento');
      expect(result.correctionNote, isNull);
    });
  });

  // ═══════════════════════════════════════
  // manuscrito → documento
  // ═══════════════════════════════════════

  group('manuscrito con alta confianza', () {
    test('→ documento', () {
      final result = useCase.call('manuscrito', highConf());
      expect(result.refinedClass, 'documento');
    });

    test('genera nota con confianza', () {
      final result = useCase.call('manuscrito', highConf());
      expect(result.correctionNote, contains('manuscrito → documento'));
      expect(result.correctionNote, contains('2° paso'));
      expect(result.correctionNote, contains('0.88'));
    });
  });

  // ═══════════════════════════════════════
  // manuscrito → factura
  // ═══════════════════════════════════════

  group('manuscrito con alta confianza + keywords + bloques > 80', () {
    test('→ factura', () {
      final a = OcrAnalysis(
        text: 'CUIT 20-12345678-9 Período Junio Monto a pagar \$3.200',
        blockCount: 110,
        avgConfidence: 0.80,
      );
      final result = useCase.call('manuscrito', a);
      expect(result.refinedClass, 'factura');
    });

    test('nota menciona la cadena manuscrito → factura', () {
      final a = OcrAnalysis(
        text: 'CUIT 20-12345678-9 Período Junio Monto a pagar \$3.200',
        blockCount: 110,
        avgConfidence: 0.80,
      );
      final result = useCase.call('manuscrito', a);
      expect(result.correctionNote, contains('manuscrito → factura'));
    });
  });

  group('manuscrito con baja confianza', () {
    test('→ manuscrito sin nota', () {
      final result = useCase.call('manuscrito', lowConf());
      expect(result.refinedClass, 'manuscrito');
      expect(result.correctionNote, isNull);
      expect(result.wasReclassified, isFalse);
    });
  });

  // ═══════════════════════════════════════
  // Keywords
  // ═══════════════════════════════════════

  group('keywords en español', () {
    const keywords = [
      'factura',
      'cuit',
      'iva',
      'vencimiento',
      'abono',
      'mora',
    ];

    for (final kw in keywords) {
      test('detecta "$kw"', () {
        final a = analysis(
          text: 'Documento con $kw en el texto',
          blockCount: 100,
          avgConf: 0.85,
        );
        final result = useCase.call('documento', a);
        expect(result.refinedClass, 'factura',
            reason: 'keyword "$kw" debería detectar factura');
      });
    }
  });

  group('keywords en inglés', () {
    const keywords = [
      'invoice',
      'amount due',
      'billing period',
      'kwh',
      'remittance',
      'balance due',
    ];

    for (final kw in keywords) {
      test('detecta "$kw"', () {
        final a = analysis(
          text: 'Document with $kw in text',
          blockCount: 100,
          avgConf: 0.85,
        );
        final result = useCase.call('documento', a);
        expect(result.refinedClass, 'factura',
            reason: 'keyword "$kw" debería detectar factura');
      });
    }
  });

  // ═══════════════════════════════════════
  // Umbrales límite
  // ═══════════════════════════════════════

  group('umbrales exactos', () {
    test('avgConf = 0.72 → documento (límite superior del manuscrito)', () {
      final result = useCase.call('documento', analysis(avgConf: 0.72));
      expect(result.refinedClass, 'documento');
    });

    test('avgConf = 0.719 → manuscrito (límite inferior)', () {
      final result = useCase.call('documento', analysis(avgConf: 0.719));
      expect(result.refinedClass, 'manuscrito');
    });

    test('receta mixta (0.657) → manuscrito', () {
      final result = useCase.call('manuscrito', analysis(avgConf: 0.657));
      expect(result.refinedClass, 'manuscrito');
    });

    test('blockCount = 81 + keywords → factura (justo sobre el umbral)', () {
      final a = analysis(
        text: 'cuit 20-12345678-9 total a pagar',
        blockCount: 81,
        avgConf: 0.85,
      );
      final result = useCase.call('documento', a);
      expect(result.refinedClass, 'factura');
    });

    test('blockCount = 80 + keywords → documento (justo en el umbral)', () {
      final a = analysis(
        text: 'cuit 20-12345678-9 total a pagar',
        blockCount: 80,
        avgConf: 0.85,
      );
      final result = useCase.call('documento', a);
      expect(result.refinedClass, 'documento');
    });
  });
}
