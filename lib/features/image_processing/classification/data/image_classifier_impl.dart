import 'package:flutter/foundation.dart';
import 'package:escandoc/core/services/text_detector_service.dart';
import 'package:escandoc/features/image_processing/classification/domain/image_classifier.dart';
import 'package:escandoc/features/image_processing/classification/domain/classification_result.dart';

/// Implementación del clasificador de imágenes usando OpenCV (Multi-condición v2).
///
/// **ESTRATEGIA (2026-02-10 - Regla multi-condición):**
/// - Clasificación binaria robusta: FOTO vs DOCUMENTO
/// - Regla con 4 condiciones OR (cualquiera clasifica como DOCUMENTO):
///   1. variance > 850 → alta complejidad de bordes
///   2. whiteRatio > 0.68 && variance > 520 → fondo blanco + texto moderado
///   3. darkRatio > 0.45 && variance > 450 → fondo negro + texto blanco
///   4. contourCount > 30 && variance > 750 → muchos contornos estructurados
///
/// **Performance:**
/// - ~150-250ms por clasificación
/// - 50-100x más rápido que OCR completo
///
/// **Accuracy (20 casos empíricos):**
/// - Grupo A (DOCUMENT): ~80% (7-8 de 9)
/// - Grupo B (PHOTO): 90.9% (10 de 11)
/// - Global: ~85-90%
///
/// **Mejoras vs versión anterior (whiteRatio simple):**
/// - Detecta fotos de pantallas con texto (variance media + whiteRatio alto)
/// - Detecta texto blanco en fondo negro (darkRatio alto)
/// - Recupera facturas y documentos con iluminación variable
///
/// **FUTURO (Etapa 2+):**
/// - CLAHE para normalizar contraste (si hay problemas de iluminación)
/// - Clasificación avanzada: folleto, manuscrito, formulario
class ImageClassifierImpl implements ImageClassifier {
  final TextDetectorService _textDetector;

  /// Umbral de varianza Laplaciana (legacy, usado en fast reject).
  ///
  /// **Regla actual (2026-02-10 - Multi-condición v2):**
  /// La clasificación ya NO depende de un threshold simple, sino de 4 condiciones:
  /// - variance > 850 ||
  /// - (whiteRatio > 0.68 && variance > 520) ||
  /// - (darkRatio > 0.45 && variance > 450) ||
  /// - (contourCount > 30 && variance > 750)
  ///
  /// Este threshold (600) solo se mantiene para compatibilidad con detect()
  /// pero la lógica real está en Kotlin (TextDetectorPlugin.kt línea ~210).
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

      // ⚡ OPTIMIZADO: Detección avanzada con Laplacian + Contours
      final detection = await _textDetector.detect(imagePath, threshold: threshold);

      debugPrint('[ImageClassifier] 📦 Map recibido: $detection');

      final variance = detection['variance'] as double;
      final hasText = detection['hasText'] as bool;
      final whiteRatio = detection['whiteRatio'] as double? ?? 0.0;
      final darkRatio = detection['darkRatio'] as double? ?? 0.0;
      final contourCount = detection['contourCount'] as int? ?? 0;

      debugPrint('[ImageClassifier] 🔍 whiteRatio: ${whiteRatio.toStringAsFixed(4)} (${(whiteRatio * 100).toStringAsFixed(2)}%)');
      debugPrint('[ImageClassifier] 🔍 darkRatio: ${darkRatio.toStringAsFixed(4)} (${(darkRatio * 100).toStringAsFixed(2)}%)');

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;

      debugPrint('[ImageClassifier] Varianza Laplaciana: ${variance.toStringAsFixed(2)}');
      debugPrint('[ImageClassifier] Threshold: $threshold');
      debugPrint('[ImageClassifier] White Ratio: ${whiteRatio.toStringAsFixed(4)} (${(whiteRatio * 100).toStringAsFixed(2)}%)');
      debugPrint('[ImageClassifier] Dark Ratio: ${darkRatio.toStringAsFixed(4)} (${(darkRatio * 100).toStringAsFixed(2)}%)');
      debugPrint('[ImageClassifier] Contornos válidos: $contourCount');
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
          'method': 'opencv_multicondition_v2',
          'variance': variance,
          'threshold': threshold,
          'whiteRatio': whiteRatio,
          'darkRatio': darkRatio,
          'contourCount': contourCount,
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
