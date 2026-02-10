/// Tipos de documentos detectables por clasificación de imagen.
enum DocumentType {
  /// Fotografía real (personas, lugares, objetos)
  /// Criterios actuales:
  /// - Varianza Laplaciana < 600 (OpenCV)
  photo,

  /// Documento escaneado (facturas, contratos, recibos, etc.)
  /// Es el tipo por defecto si no cumple otros criterios.
  document,

  // FUTURO: Descomentar cuando se implementen
  // /// Folleto o documento con mucho texto
  // /// Criterios: > 50 palabras detectadas por OCR
  // folleto,
  //
  // /// Documento manuscrito
  // /// Criterios: Detección de escritura manual
  // manuscrito,
  //
  // /// Documento con código de barras (facturas, recibos, productos)
  // /// Criterios: Barcode o QR code detectado (usar BarcodeDetectorService)
  // /// NOTA: ML Kit es lento (2-4s), no usar en cascade de clasificación
  // barcode,
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
