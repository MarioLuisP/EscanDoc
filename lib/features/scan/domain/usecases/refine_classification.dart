import 'package:escandoc/core/services/ocr_analysis.dart';

/// Resultado del refinamiento de clasificación
class RefinementResult {
  /// Clase final después del refinamiento
  final String refinedClass;

  /// Nota de corrección para agregar al documento.
  /// null si no hubo cambio respecto a [tfliteClass].
  final String? correctionNote;

  const RefinementResult({
    required this.refinedClass,
    this.correctionNote,
  });

  bool get wasReclassified => correctionNote != null;
}

/// Refina la clasificación inicial del TFLite usando métricas del OCR.
///
/// Se ejecuta en background después de que el OCR finaliza.
/// Solo ajusta 'documento' y 'manuscrito' — el resto queda intacto.
///
/// Lógica:
/// 1. avgConfidence < 0.55 → manuscrito (texto muy irregular)
/// 2. avgConfidence >= 0.55 → documento (texto legible)
/// 3. Si quedó como 'documento' + keywords + >80 bloques → factura
///
/// Umbrales basados en datos empíricos (Feb 2026):
/// - Manuscrito: avgConf ~0.35-0.40 (máx 0.56)
/// - Documento impreso: avgConf 0.85-0.93
/// - Factura: avgConf 0.79-0.84, bloques 118-144
/// - Recibo (no tocado): 13-46 bloques
class RefineClassification {
  static const double _avgConfidenceThreshold = 0.72;
  static const int _minBlocksForInvoice = 80;

  /// Keywords en español que identifican facturas de servicio
  static const List<String> _invoiceKeywordsEs = [
    'factura',
    'facturación',
    'vencimiento',
    'total a pagar',
    'importe a pagar',
    'liquidación',
    'período',
    'cuit',
    'iva',
    'consumo',
    'prestación',
    'abono',
    'fecha de vencimiento',
    'próximo vencimiento',
    'monto a pagar',
    'n° de cliente',
    'número de cliente',
    'tarifa',
    'deuda',
    'mora',
    'talón',
    'cupón de pago',
  ];

  /// Keywords en inglés que identifican facturas y estados de cuenta
  static const List<String> _invoiceKeywordsEn = [
    'invoice',
    'bill',
    'statement',
    'amount due',
    'total due',
    'due date',
    'billing period',
    'billing cycle',
    'account number',
    'balance due',
    'past due',
    'payment due',
    'current charges',
    'remittance',
    'kwh',
    'meter reading',
    'usage',
    'subscription',
    'account summary',
    'previous balance',
    'minimum payment',
    'payment stub',
    'tear here',
  ];

  /// Refina [tfliteClass] usando las métricas de [analysis].
  ///
  /// Tipos intocables: 'foto', 'folleto', 'recibo'
  RefinementResult call(String tfliteClass, OcrAnalysis analysis) {
    // Tipos que no refinamos
    if (!_isRefineable(tfliteClass)) {
      return RefinementResult(refinedClass: tfliteClass);
    }

    final isHandwritten = analysis.avgConfidence < _avgConfidenceThreshold;

    if (isHandwritten) {
      // Texto muy irregular → manuscrito
      if (tfliteClass == 'documento') {
        final conf = analysis.avgConfidence.toStringAsFixed(2);
        return RefinementResult(
          refinedClass: 'manuscrito',
          correctionNote:
              'documento → manuscrito (2° paso: confianza promedio baja: $conf)',
        );
      }
      // Manuscrito → sigue siendo manuscrito, sin cambio
      return RefinementResult(refinedClass: 'manuscrito');
    }

    // Texto legible → documento
    String refined = 'documento';
    String? note;

    if (tfliteClass == 'manuscrito') {
      final conf = analysis.avgConfidence.toStringAsFixed(2);
      note = 'manuscrito → documento (2° paso: confianza promedio alta: $conf)';
    }

    // Verificar si es factura
    if (_hasInvoiceKeyword(analysis.text) &&
        analysis.blockCount > _minBlocksForInvoice) {
      if (note != null) {
        // Cadena completa: manuscrito → factura
        note = note.replaceFirst('→ documento', '→ factura');
      } else {
        note =
            'documento → factura (2° paso: keywords + ${analysis.blockCount} bloques)';
      }
      refined = 'factura';
    }

    return RefinementResult(refinedClass: refined, correctionNote: note);
  }

  bool _isRefineable(String type) =>
      type == 'documento' || type == 'manuscrito';

  bool _hasInvoiceKeyword(String text) {
    final lower = text.toLowerCase();
    return [
      ..._invoiceKeywordsEs,
      ..._invoiceKeywordsEn,
    ].any((keyword) => lower.contains(keyword));
  }
}
