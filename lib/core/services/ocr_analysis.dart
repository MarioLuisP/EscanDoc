/// Resultado estructurado de OCR con métricas de calidad.
///
/// Modelo de dominio puro (sin dependencias Flutter/ML Kit).
/// Usado por [RefineClassification] para ajustar la clasificación
/// inicial del TFLite con datos reales del texto extraído.
class OcrAnalysis {
  /// Texto plano extraído (concatenación de todos los bloques)
  final String text;

  /// Cantidad de bloques detectados por ML Kit
  ///
  /// Referencia empírica:
  /// - Documentos impresos: ~32 bloques
  /// - Facturas de servicio: 100-144 bloques
  /// - Manuscritos: 9-15 bloques
  final int blockCount;

  /// Promedio de confianza de todas las líneas (0.0 - 1.0)
  ///
  /// Referencia empírica:
  /// - Documentos impresos: 0.85-0.93
  /// - Facturas: 0.79-0.84
  /// - Manuscritos: 0.17-0.56 (máx nunca supera 0.65)
  final double avgConfidence;

  /// Las top-5 líneas con mayor confianza, unidas con espacio.
  ///
  /// Útil para generar notas de extracto:
  /// - Documentos impresos: saldrán las líneas más limpias
  /// - Manuscritos: saldrán las palabras más reconocibles
  final String topConfidenceText;

  /// Grados de corrección de orientación detectados (0, 90, 180 o 270).
  ///
  /// Calculado a partir de la mediana de ángulos de todas las líneas de texto.
  /// 0 = imagen ya orientada correctamente.
  /// Distinto de 0 = [ProcessOCR] debe rotar el archivo y re-procesar.
  final int detectedRotationDegrees;

  const OcrAnalysis({
    required this.text,
    required this.blockCount,
    required this.avgConfidence,
    this.topConfidenceText = '',
    this.detectedRotationDegrees = 0,
  });

  /// Resultado vacío cuando OCR falla o la imagen es inválida
  static const OcrAnalysis empty = OcrAnalysis(
    text: '',
    blockCount: 0,
    avgConfidence: 0.0,
    topConfidenceText: '',
    detectedRotationDegrees: 0,
  );
}
