import 'package:flutter_test/flutter_test.dart';
import 'package:escandoc/core/services/ocr_analysis.dart';
import 'package:escandoc/features/image_processing/classification/domain/classification_result.dart';
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
    for (final kind in [DocumentType.foto]) {
      test('${kind.dbKey} queda como ${kind.dbKey} sin nota', () {
        final result = useCase.call(kind, highConf());
        expect(result.refinedKind, kind);
        expect(result.correctionNote, isNull);
        expect(result.wasReclassified, isFalse);
      });
    }
  });

  // ═══════════════════════════════════════
  // recibo → factura
  // ═══════════════════════════════════════

  group('recibo con keywords + bloques > 80', () {
    test('→ factura', () {
      final result = useCase.call(DocumentType.recibo, invoiceAnalysis());
      expect(result.refinedKind, DocumentType.factura);
    });

    test('genera nota recibo → factura', () {
      final result = useCase.call(DocumentType.recibo, invoiceAnalysis());
      expect(result.correctionNote, contains('recibo → factura'));
      expect(result.correctionNote, contains('2° paso'));
    });

    test('sin keywords → queda como recibo sin nota', () {
      final result = useCase.call(DocumentType.recibo, highConf(blockCount: 120));
      expect(result.refinedKind, DocumentType.recibo);
      expect(result.correctionNote, isNull);
    });

    test('con keywords pero bloques <= 80 → queda como recibo', () {
      final a = analysis(
        text: 'cuit 20-12345678-9 total a pagar',
        blockCount: 80,
        avgConf: 0.85,
      );
      final result = useCase.call(DocumentType.recibo, a);
      expect(result.refinedKind, DocumentType.recibo);
    });
  });

  // ═══════════════════════════════════════
  // folleto → factura
  // ═══════════════════════════════════════

  group('folleto con keywords + bloques > 80', () {
    test('→ factura', () {
      final result = useCase.call(DocumentType.folleto, invoiceAnalysis());
      expect(result.refinedKind, DocumentType.factura);
    });

    test('genera nota folleto → factura', () {
      final result = useCase.call(DocumentType.folleto, invoiceAnalysis());
      expect(result.correctionNote, contains('folleto → factura'));
      expect(result.correctionNote, contains('2° paso'));
    });

    test('sin keywords → queda como folleto sin nota', () {
      final result = useCase.call(DocumentType.folleto, highConf(blockCount: 120));
      expect(result.refinedKind, DocumentType.folleto);
      expect(result.correctionNote, isNull);
    });

    test('aspectRatio > 2.0 → recibo', () {
      final a = OcrAnalysis(
        text: 'texto sin keywords',
        blockCount: 20,
        avgConfidence: 0.82,
        imageAspectRatio: 2.5,
      );
      final result = useCase.call(DocumentType.folleto, a);
      expect(result.refinedKind, DocumentType.recibo);
      expect(result.correctionNote, contains('folleto → recibo'));
    });

    test('aspectRatio > 2.0 + keywords + bloques > 80 → factura tiene prioridad', () {
      final a = OcrAnalysis(
        text: 'factura cuit 20-12345678-9 total a pagar',
        blockCount: 90,
        avgConfidence: 0.82,
        imageAspectRatio: 2.5,
      );
      final result = useCase.call(DocumentType.folleto, a);
      expect(result.refinedKind, DocumentType.factura);
    });
  });

  // ═══════════════════════════════════════
  // documento → manuscrito
  // ═══════════════════════════════════════

  group('documento con baja confianza', () {
    test('→ manuscrito', () {
      final result = useCase.call(DocumentType.documento, lowConf());
      expect(result.refinedKind, DocumentType.manuscrito);
    });

    test('genera nota con confianza', () {
      final result = useCase.call(DocumentType.documento, lowConf());
      expect(result.correctionNote, contains('documento → manuscrito'));
      expect(result.correctionNote, contains('2° paso'));
      expect(result.correctionNote, contains('0.38'));
    });

    test('wasReclassified es true', () {
      final result = useCase.call(DocumentType.documento, lowConf());
      expect(result.wasReclassified, isTrue);
    });
  });

  // ═══════════════════════════════════════
  // documento → documento (sin cambio)
  // ═══════════════════════════════════════

  group('documento con alta confianza sin keywords', () {
    test('→ documento sin nota', () {
      final result = useCase.call(DocumentType.documento, highConf(text: 'Informe médico'));
      expect(result.refinedKind, DocumentType.documento);
      expect(result.correctionNote, isNull);
      expect(result.wasReclassified, isFalse);
    });
  });

  // ═══════════════════════════════════════
  // documento → factura
  // ═══════════════════════════════════════

  group('documento con alta confianza + keywords + bloques > 80', () {
    test('→ factura', () {
      final result = useCase.call(DocumentType.documento, invoiceAnalysis());
      expect(result.refinedKind, DocumentType.factura);
    });

    test('genera nota con bloques y keyword', () {
      final result = useCase.call(DocumentType.documento, invoiceAnalysis());
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
      final result = useCase.call(DocumentType.documento, a);
      expect(result.refinedKind, DocumentType.documento);
      expect(result.correctionNote, isNull);
    });
  });

  // ═══════════════════════════════════════
  // manuscrito → documento
  // ═══════════════════════════════════════

  group('manuscrito con alta confianza', () {
    test('→ documento', () {
      final result = useCase.call(DocumentType.manuscrito, highConf());
      expect(result.refinedKind, DocumentType.documento);
    });

    test('genera nota con confianza', () {
      final result = useCase.call(DocumentType.manuscrito, highConf());
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
      final result = useCase.call(DocumentType.manuscrito, a);
      expect(result.refinedKind, DocumentType.factura);
    });

    test('nota menciona la cadena manuscrito → factura', () {
      final a = OcrAnalysis(
        text: 'CUIT 20-12345678-9 Período Junio Monto a pagar \$3.200',
        blockCount: 110,
        avgConfidence: 0.80,
      );
      final result = useCase.call(DocumentType.manuscrito, a);
      expect(result.correctionNote, contains('manuscrito → factura'));
    });
  });

  group('manuscrito con baja confianza', () {
    test('→ manuscrito sin nota', () {
      final result = useCase.call(DocumentType.manuscrito, lowConf());
      expect(result.refinedKind, DocumentType.manuscrito);
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
        final result = useCase.call(DocumentType.documento, a);
        expect(result.refinedKind, DocumentType.factura,
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
        final result = useCase.call(DocumentType.documento, a);
        expect(result.refinedKind, DocumentType.factura,
            reason: 'keyword "$kw" debería detectar factura');
      });
    }
  });

  // ═══════════════════════════════════════
  // Formato ticket (aspectRatio alto → recibo)
  // ═══════════════════════════════════════

  group('documento con aspectRatio alto → recibo', () {
    OcrAnalysis ticketAnalysis({double aspectRatio = 2.5, int blockCount = 42}) =>
        OcrAnalysis(
          text: 'total subtotal iva consumidor final',
          blockCount: blockCount,
          avgConfidence: 0.60,
          imageAspectRatio: aspectRatio,
        );

    test('documento con aspectRatio > 2.0 → recibo', () {
      final result = useCase.call(DocumentType.documento, ticketAnalysis());
      expect(result.refinedKind, DocumentType.recibo);
    });

    test('manuscrito con aspectRatio > 2.0 → recibo', () {
      final result = useCase.call(DocumentType.manuscrito, ticketAnalysis());
      expect(result.refinedKind, DocumentType.recibo);
    });

    test('genera nota con aspectRatio', () {
      final result = useCase.call(DocumentType.documento, ticketAnalysis());
      expect(result.correctionNote, contains('→ recibo'));
      expect(result.correctionNote, contains('aspectRatio'));
    });

    test('límite: aspectRatio = 2.0 → NO es recibo (umbral estricto)', () {
      final result = useCase.call(DocumentType.documento, ticketAnalysis(aspectRatio: 2.0));
      expect(result.refinedKind, isNot(DocumentType.recibo));
    });

    test('límite: aspectRatio = 2.01 → recibo', () {
      final result = useCase.call(DocumentType.documento, ticketAnalysis(aspectRatio: 2.01));
      expect(result.refinedKind, DocumentType.recibo);
    });

    test('aspectRatio alto + keywords + bloques > 80 → factura tiene prioridad', () {
      final a = OcrAnalysis(
        text: 'factura cuit 20-12345678-9 total a pagar ${'x' * 50}',
        blockCount: 90,
        avgConfidence: 0.82,
        imageAspectRatio: 3.0,
      );
      final result = useCase.call(DocumentType.documento, a);
      expect(result.refinedKind, DocumentType.factura);
    });
  });

  // ═══════════════════════════════════════
  // Impreso de mala calidad (baja conf pero muchos chars/bloques)
  // ═══════════════════════════════════════

  group('impreso de mala calidad (baja conf + charCount alto)', () {
    test('manuscrito con baja conf + charCount > 250 → documento', () {
      final a = analysis(
        text: 'a' * 400,
        blockCount: 12,
        avgConf: 0.55,
      );
      final result = useCase.call(DocumentType.manuscrito, a);
      expect(result.refinedKind, DocumentType.documento);
      expect(result.correctionNote, contains('manuscrito → documento'));
    });

    test('documento con baja conf + charCount > 250 → documento (no se convierte a manuscrito)', () {
      final a = analysis(
        text: 'a' * 400,
        blockCount: 12,
        avgConf: 0.55,
      );
      final result = useCase.call(DocumentType.documento, a);
      expect(result.refinedKind, DocumentType.documento);
    });

    test('manuscrito con baja conf + blockCount > 15 → documento', () {
      final a = analysis(
        text: 'texto corto',
        blockCount: 20,
        avgConf: 0.55,
      );
      final result = useCase.call(DocumentType.manuscrito, a);
      expect(result.refinedKind, DocumentType.documento);
    });

    test('manuscrito con baja conf + charCount > 250 + keywords + bloques > 80 → factura', () {
      final a = analysis(
        text: 'factura cuit 20-12345678-9 total a pagar ${'x' * 300}',
        blockCount: 90,
        avgConf: 0.55,
      );
      final result = useCase.call(DocumentType.manuscrito, a);
      expect(result.refinedKind, DocumentType.factura);
    });

    test('límite: charCount = 250 y blockCount = 15 → manuscrito (en umbral)', () {
      final a = analysis(
        text: 'a' * 250,
        blockCount: 15,
        avgConf: 0.55,
      );
      final result = useCase.call(DocumentType.manuscrito, a);
      expect(result.refinedKind, DocumentType.manuscrito);
    });

    test('límite: charCount = 251 → documento (sobre umbral de chars)', () {
      final a = analysis(
        text: 'a' * 251,
        blockCount: 15,
        avgConf: 0.55,
      );
      final result = useCase.call(DocumentType.manuscrito, a);
      expect(result.refinedKind, DocumentType.documento);
    });

    test('límite: blockCount = 16 → documento (sobre umbral de bloques)', () {
      final a = analysis(
        text: 'texto corto',
        blockCount: 16,
        avgConf: 0.55,
      );
      final result = useCase.call(DocumentType.manuscrito, a);
      expect(result.refinedKind, DocumentType.documento);
    });
  });

  // ═══════════════════════════════════════
  // Umbrales límite
  // ═══════════════════════════════════════

  group('umbrales exactos', () {
    test('avgConf = 0.72 → documento (límite superior del manuscrito)', () {
      final result = useCase.call(DocumentType.documento, analysis(avgConf: 0.72));
      expect(result.refinedKind, DocumentType.documento);
    });

    test('avgConf = 0.719 → manuscrito (límite inferior)', () {
      final result = useCase.call(DocumentType.documento, analysis(avgConf: 0.719));
      expect(result.refinedKind, DocumentType.manuscrito);
    });

    test('receta mixta (0.657) → manuscrito', () {
      final result = useCase.call(DocumentType.manuscrito, analysis(avgConf: 0.657));
      expect(result.refinedKind, DocumentType.manuscrito);
    });

    test('blockCount = 81 + keywords → factura (justo sobre el umbral)', () {
      final a = analysis(
        text: 'cuit 20-12345678-9 total a pagar',
        blockCount: 81,
        avgConf: 0.85,
      );
      final result = useCase.call(DocumentType.documento, a);
      expect(result.refinedKind, DocumentType.factura);
    });

    test('blockCount = 80 + keywords → documento (justo en el umbral)', () {
      final a = analysis(
        text: 'cuit 20-12345678-9 total a pagar',
        blockCount: 80,
        avgConf: 0.85,
      );
      final result = useCase.call(DocumentType.documento, a);
      expect(result.refinedKind, DocumentType.documento);
    });
  });
}
