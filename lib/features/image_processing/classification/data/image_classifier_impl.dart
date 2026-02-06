import 'package:flutter/foundation.dart';
import 'package:escandoc/core/services/text_detector_service.dart';
import 'package:escandoc/features/image_processing/classification/domain/image_classifier.dart';
import 'package:escandoc/features/image_processing/classification/domain/classification_result.dart';

/// Implementación del clasificador de imágenes usando OpenCV Laplacian variance.
///
/// **ESTRATEGIA (2026-02-06 - Etapa 1):**
/// - Clasificación binaria simple: FOTO vs DOCUMENTO
/// - Método: OpenCV Laplacian variance
/// - Threshold 600: varianza > 600 → DOCUMENTO, < 600 → FOTO
///
/// **Performance:**
/// - ~1s fijo y predecible
/// - 50-100x más rápido que OCR completo
/// - Probado con imágenes reales y calibrado
///
/// **FUTURO (Etapa 2+):**
/// - Barcode detection (para feature separada, no cascade)
/// - Clasificación avanzada: folleto, manuscrito, formulario
class ImageClassifierImpl implements ImageClassifier {
  final TextDetectorService _textDetector;

  /// Umbral de varianza Laplaciana para clasificación.
  ///
  /// Valores REALES medidos (2026-02-06):
  /// - Fotos sin texto: 168-406 (rostros, objetos simples)
  /// - Documentos con texto: 668-4806
  /// - Threshold ajustado: 600 (punto de corte óptimo)
  ///
  /// Casos límite:
  /// - Césped/texturas extremas: ~3680 (falso positivo esperado)
  static const double threshold = 600.0;

  ImageClassifierImpl({
    required TextDetectorService textDetector,
  }) : _textDetector = textDetector;

  @override
  Future<ClassificationResult> classify(String imagePath) async {
    try {
      final startTime = DateTime.now();
      debugPrint('[ImageClassifier] 🟢 START: Clasificación OpenCV - ${startTime.millisecondsSinceEpoch}');
      debugPrint('[ImageClassifier] Imagen: $imagePath');

      // ⚡ OPTIMIZADO: Una sola llamada nativa que retorna ambos valores
      final detection = await _textDetector.detect(imagePath, threshold: threshold);

      final variance = detection['variance'] as double;
      final hasText = detection['hasText'] as bool;

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;

      debugPrint('[ImageClassifier] Varianza Laplaciana: ${variance.toStringAsFixed(2)}');
      debugPrint('[ImageClassifier] Threshold: $threshold');
      debugPrint('[ImageClassifier] Tiene texto: $hasText');
      debugPrint('[ImageClassifier] 🔴 END: Clasificación completa - Duración TOTAL: ${duration}ms');

      // Clasificar según resultado
      final type = hasText ? DocumentType.document : DocumentType.photo;

      // Calcular confianza basada en qué tan lejos está del threshold
      final confidence = _calculateConfidence(variance, threshold, hasText);

      debugPrint('[ImageClassifier] ✅ Clasificado como: ${type.name.toUpperCase()} (confianza: ${(confidence * 100).toStringAsFixed(1)}%)');

      return ClassificationResult(
        type: type,
        confidence: confidence,
        metadata: {
          'method': 'opencv_laplacian',
          'variance': variance,
          'threshold': threshold,
          'hasText': hasText,
          'durationMs': duration,
        },
      );
    } catch (e, stackTrace) {
      debugPrint('[ImageClassifier] ERROR: $e');
      debugPrint('[ImageClassifier] StackTrace: $stackTrace');

      // Fallback: clasificar como DOCUMENTO (más seguro)
      return ClassificationResult(
        type: DocumentType.document,
        confidence: 0.5,
        metadata: {
          'method': 'opencv_laplacian',
          'error': e.toString(),
        },
      );
    }
  }

  /// Calcula confianza basada en distancia al threshold.
  ///
  /// Cuanto más lejos del threshold, mayor confianza.
  double _calculateConfidence(double? variance, double threshold, bool hasText) {
    if (variance == null) {
      return 0.5; // Confianza baja si no hay varianza
    }

    final distance = (variance - threshold).abs();

    if (hasText) {
      // Documento: confianza aumenta con varianza alta
      // variance = 200, threshold = 120 → distance = 80 → confidence ~ 0.85
      final confidence = 0.6 + (distance / 200).clamp(0.0, 0.4);
      return confidence.clamp(0.5, 1.0);
    } else {
      // Foto: confianza aumenta con varianza baja
      // variance = 50, threshold = 120 → distance = 70 → confidence ~ 0.85
      final confidence = 0.6 + (distance / 150).clamp(0.0, 0.4);
      return confidence.clamp(0.5, 1.0);
    }
  }
}
