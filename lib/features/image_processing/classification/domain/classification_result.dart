/// Tipos de documentos detectables por clasificación de imagen.
///
/// Clasificación con TFLite Keras (5 clases):
/// - 0: document → Documentos generales
/// - 1: brochure → Folletos con mucho texto/color
/// - 2: photo → Fotografías
/// - 3: handwritten → Documentos manuscritos
/// - 4: ticket → Tickets/recibos largos
enum DocumentType {
  /// Documento escaneado (facturas, contratos, recibos, etc.)
  /// Índice TFLite: 0
  document,

  /// Folleto o documento con mucho texto/color
  /// Índice TFLite: 1
  brochure,

  /// Fotografía real (personas, lugares, objetos)
  /// Índice TFLite: 2
  photo,

  /// Documento manuscrito (notas escritas a mano)
  /// Índice TFLite: 3
  handwritten,

  /// Ticket o recibo largo (supermercado, etc.)
  /// Índice TFLite: 4
  ticket,
}

/// Resultado de la clasificación de una imagen.
///
/// Contiene:
/// - [type]: Tipo de documento detectado
/// - [confidence]: Confianza de la clasificación (0.0 - 1.0)
/// - [metadata]: Datos adicionales del análisis (colores, palabras, etc.)
class ClassificationResult {
  /// Tipo de documento detectado
  final DocumentType type;

  /// Nivel de confianza de la clasificación (0.0 = baja, 1.0 = alta)
  final double confidence;

  /// Metadata del análisis (varía según el tipo)
  ///
  /// Para clasificación OpenCV (actual):
  /// - 'method': String - Método usado ('opencv_laplacian')
  /// - 'variance': double - Varianza Laplaciana calculada
  /// - 'threshold': double - Umbral usado para clasificación (600.0)
  /// - 'hasText': bool - Si detectó texto (variance > threshold)
  /// - 'durationMs': int - Tiempo de análisis en milisegundos
  ///
  /// Para clasificación futura:
  /// - 'wordCount': int - Cantidad de palabras detectadas (OCR)
  /// - Otros campos según necesidad
  final Map<String, dynamic> metadata;

  ClassificationResult({
    required this.type,
    required this.confidence,
    this.metadata = const {},
  });

  /// Retorna true si la clasificación es de alta confianza (>= 0.7)
  bool get isHighConfidence => confidence >= 0.7;

  /// Retorna true si la clasificación es de confianza media (0.4 - 0.7)
  bool get isMediumConfidence => confidence >= 0.4 && confidence < 0.7;

  /// Retorna true si la clasificación es de baja confianza (< 0.4)
  bool get isLowConfidence => confidence < 0.4;

  @override
  String toString() {
    return 'ClassificationResult(type: $type, confidence: ${(confidence * 100).toStringAsFixed(1)}%, metadata: $metadata)';
  }
}
