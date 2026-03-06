/// Tipos de documentos del dominio de EscanDoc.
///
/// 5 tipos base del modelo TFLite (en español, orden alfabético):
/// - 0: documento → Documentos generales
/// - 1: folleto   → Folletos con mucho texto/color
/// - 2: foto      → Fotografías
/// - 3: manuscrito → Documentos manuscritos
/// - 4: recibo    → Tickets/recibos largos
///
/// 1 tipo derivado del refinamiento OCR:
/// - factura → Documento con keywords de factura (subclase de documento)
enum DocumentType {
  documento,
  folleto,
  foto,
  manuscrito,
  recibo,
  factura;

  /// Clave de persistencia en BD — igual al name del enum (español).
  String get dbKey => name;

  /// Construye desde el label del TFLite o clave de BD.
  ///
  /// Si el label no reconocido, retorna [documento] como fallback.
  static DocumentType fromLabel(String label) =>
      values.firstWhere((e) => e.name == label, orElse: () => documento);

  /// Nombre visible en la UI según idioma.
  ///
  /// [locale]: código de idioma ('es', 'en').
  String displayName(String locale) {
    if (locale == 'en') {
      return switch (this) {
        DocumentType.factura    => 'Invoice',
        DocumentType.recibo     => 'Receipt',
        DocumentType.manuscrito => 'Note',
        DocumentType.folleto    => 'Brochure',
        DocumentType.foto       => 'Photo',
        DocumentType.documento  => 'Document',
      };
    }
    return switch (this) {
      DocumentType.factura    => 'Factura',
      DocumentType.recibo     => 'Recibo',
      DocumentType.manuscrito => 'Nota',
      DocumentType.folleto    => 'Folleto',
      DocumentType.foto       => 'Foto',
      DocumentType.documento  => 'Documento',
    };
  }
}

/// Resultado de la clasificación de una imagen.
class ClassificationResult {
  /// Tipo de documento detectado
  final DocumentType type;

  /// Nivel de confianza de la clasificación (0.0 = baja, 1.0 = alta)
  final double confidence;

  /// Metadata del análisis (varía según el tipo)
  ///
  /// - 'method': String - Método usado ('tflite_keras')
  /// - 'label': String - Label español del TFLite
  /// - 'probabilities': Map<String, double> - Probabilidades por clase
  /// - 'preprocessDurationMs', 'inferenceDurationMs', 'totalDurationMs': int
  final Map<String, dynamic> metadata;

  ClassificationResult({
    required this.type,
    required this.confidence,
    this.metadata = const {},
  });

  bool get isHighConfidence => confidence >= 0.7;
  bool get isMediumConfidence => confidence >= 0.4 && confidence < 0.7;
  bool get isLowConfidence => confidence < 0.4;

  @override
  String toString() =>
      'ClassificationResult(type: $type, confidence: ${(confidence * 100).toStringAsFixed(1)}%, metadata: $metadata)';
}
