import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:escandoc/features/image_processing/classification/domain/image_classifier.dart';
import 'package:escandoc/features/image_processing/classification/domain/classification_result.dart';

/// Implementación del clasificador de imágenes usando análisis de colores.
///
/// FASE 1 - Detección de FOTO:
/// - Colores únicos > 12,000
/// - Cobertura top 10 < 25%
///
/// Optimización: Muestreo de píxeles (1 de cada N) para acelerar análisis.
class ImageClassifierImpl implements ImageClassifier {
  /// Umbral de colores únicos para detectar FOTO
  static const int photoUniqueColorsThreshold = 12000;

  /// Umbral de cobertura top 10 para detectar FOTO (%)
  static const double photoTopTenCoverageThreshold = 0.25;

  /// Sampling: analizar 1 de cada N píxeles (para performance)
  /// 4 = analiza 25% de los píxeles (suficiente precisión, 4x más rápido)
  static const int pixelSampling = 4;

  /// Tamaño máximo para análisis (redimensionar antes de analizar)
  /// Reduce tiempo de análisis sin perder precisión en clasificación
  static const int maxAnalysisSize = 800;

  /// Umbral reducido de colores únicos para selfies/retratos
  static const int photoUniqueColorsLowThreshold = 6000;

  /// Umbral de diferencia de color para transiciones suaves
  /// Valores < 15 indican gradientes naturales (piel, cielo, sombras)
  static const int smoothTransitionThreshold = 15;

  /// Porcentaje mínimo de transiciones suaves para detectar foto
  /// Fotos tienen >70% transiciones suaves vs documentos con texto definido
  static const double smoothGradientsRatio = 0.70;

  @override
  Future<ClassificationResult> classify(String imagePath) async {
    String? tempPath;
    try {
      final startAnalysis = DateTime.now();
      debugPrint('[ImageClassifier] 🟢 START: Análisis de imagen - ${startAnalysis.millisecondsSinceEpoch}');
      debugPrint('[ImageClassifier] Imagen: $imagePath');

      // 1. Verificar que existe
      final imageFile = File(imagePath);
      if (!imageFile.existsSync()) {
        throw Exception('Image file not found: $imagePath');
      }

      // 2. Crear versión redimensionada con compresión nativa (MUY RÁPIDO)
      final startResize = DateTime.now();
      tempPath = await _createTemporaryResizedImage(imagePath);
      final endResize = DateTime.now();
      final resizeDuration = endResize.difference(startResize).inMilliseconds;
      debugPrint('[ImageClassifier] Redimensión nativa: ${resizeDuration}ms');

      // 3. Decodificar imagen temporal (pequeña, rápido)
      final imageBytes = await File(tempPath).readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Failed to decode image: $tempPath');
      }

      debugPrint('[ImageClassifier] Dimensiones análisis: ${image.width}x${image.height}');

      // 4. Analizar colores
      final colorAnalysis = _analyzeColors(image);

      // 5. Analizar gradientes (para detectar selfies/retratos)
      final startGradients = DateTime.now();
      final hasSmoothGradients = _hasSmoothGradients(image);
      final endGradients = DateTime.now();
      final gradientsDuration = endGradients.difference(startGradients).inMilliseconds;
      debugPrint('[ImageClassifier] Análisis de gradientes: ${gradientsDuration}ms');
      debugPrint('[ImageClassifier] Tiene gradientes suaves: $hasSmoothGradients');

      // Agregar a metadata
      colorAnalysis['hasSmoothGradients'] = hasSmoothGradients;

      final endAnalysis = DateTime.now();
      final analysisDuration = endAnalysis.difference(startAnalysis).inMilliseconds;
      debugPrint('[ImageClassifier] 🔴 END: Análisis completo - Duración: ${analysisDuration}ms');

      // 6. Clasificar basado en análisis
      return _classifyFromColorAnalysis(colorAnalysis);
    } catch (e, stackTrace) {
      debugPrint('[ImageClassifier] ERROR: $e');
      debugPrint('[ImageClassifier] StackTrace: $stackTrace');
      rethrow;
    } finally {
      // 7. Limpiar archivo temporal
      if (tempPath != null) {
        try {
          await File(tempPath).delete();
        } catch (e) {
          debugPrint('[ImageClassifier] Warning: Failed to delete temp file: $e');
        }
      }
    }
  }

  /// Crea una versión redimensionada temporal usando compresión nativa.
  ///
  /// Usa flutter_image_compress (nativo) en lugar de image package (dart puro).
  /// MUCHO más rápido para imágenes grandes (12 MP).
  ///
  /// La imagen temporal se borra en el finally del classify().
  Future<String> _createTemporaryResizedImage(String imagePath) async {
    final dir = path.dirname(imagePath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempPath = path.join(dir, 'temp_analysis_$timestamp.jpg');

    final resizedBytes = await FlutterImageCompress.compressWithFile(
      imagePath,
      minWidth: maxAnalysisSize,
      minHeight: maxAnalysisSize,
      quality: 75,
      format: CompressFormat.jpeg,
    );

    if (resizedBytes == null) {
      throw Exception('Failed to resize image for analysis: $imagePath');
    }

    await File(tempPath).writeAsBytes(resizedBytes);
    return tempPath;
  }

  /// Analiza gradientes de la imagen para detectar transiciones suaves.
  ///
  /// Fotos (selfies, retratos, paisajes) tienen gradientes suaves y continuos.
  /// Documentos tienen transiciones abruptas (texto, bordes, cajas).
  ///
  /// Retorna true si >70% de las transiciones son suaves (diferencia < 15).
  bool _hasSmoothGradients(img.Image image) {
    int smoothTransitions = 0;
    int totalComparisons = 0;

    // Recorrer imagen con sampling, dejando margen para vecinos
    for (int y = 1; y < image.height - 1; y += pixelSampling) {
      for (int x = 1; x < image.width - 1; x += pixelSampling) {
        final pixel = image.getPixel(x, y);

        // Comparar con 4 vecinos (arriba, abajo, izquierda, derecha)
        final neighbors = [
          image.getPixel(x, y - 1), // arriba
          image.getPixel(x, y + 1), // abajo
          image.getPixel(x - 1, y), // izquierda
          image.getPixel(x + 1, y), // derecha
        ];

        for (final neighbor in neighbors) {
          final diff = _colorDifference(pixel, neighbor);
          if (diff < smoothTransitionThreshold) {
            smoothTransitions++;
          }
          totalComparisons++;
        }
      }
    }

    final smoothRatio = totalComparisons > 0
        ? smoothTransitions / totalComparisons
        : 0.0;

    return smoothRatio >= smoothGradientsRatio;
  }

  /// Calcula la diferencia de color entre dos píxeles (promedio RGB).
  int _colorDifference(img.Pixel p1, img.Pixel p2) {
    final dr = (p1.r.toInt() - p2.r.toInt()).abs();
    final dg = (p1.g.toInt() - p2.g.toInt()).abs();
    final db = (p1.b.toInt() - p2.b.toInt()).abs();
    return (dr + dg + db) ~/ 3; // Promedio de diferencias
  }

  /// Analiza los colores de la imagen con muestreo para optimizar performance.
  Map<String, dynamic> _analyzeColors(img.Image image) {
    final startColorAnalysis = DateTime.now();

    // Map de color (RGB combinado) → frecuencia
    final Map<int, int> colorFrequency = {};
    int totalSampledPixels = 0;

    // Recorrer imagen con sampling (1 de cada N píxeles)
    for (int y = 0; y < image.height; y += pixelSampling) {
      for (int x = 0; x < image.width; x += pixelSampling) {
        final pixel = image.getPixel(x, y);

        // Combinar RGB en un solo int (ignorar alpha)
        // RGB: 24 bits (8R + 8G + 8B)
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final colorKey = (r << 16) | (g << 8) | b;

        colorFrequency[colorKey] = (colorFrequency[colorKey] ?? 0) + 1;
        totalSampledPixels++;
      }
    }

    final uniqueColors = colorFrequency.length;

    // Calcular cobertura de top 10 colores más frecuentes
    final sortedFrequencies = colorFrequency.values.toList()
      ..sort((a, b) => b.compareTo(a));

    final top10Count = sortedFrequencies
        .take(10)
        .fold<int>(0, (sum, count) => sum + count);

    final topTenCoverage = totalSampledPixels > 0
        ? top10Count / totalSampledPixels
        : 0.0;

    final endColorAnalysis = DateTime.now();
    final colorAnalysisDuration = endColorAnalysis.difference(startColorAnalysis).inMilliseconds;

    debugPrint('[ImageClassifier] Análisis de colores: ${colorAnalysisDuration}ms');
    debugPrint('[ImageClassifier] Píxeles analizados: $totalSampledPixels (sampling: 1/$pixelSampling)');
    debugPrint('[ImageClassifier] Colores únicos: $uniqueColors');
    debugPrint('[ImageClassifier] Cobertura top 10: ${(topTenCoverage * 100).toStringAsFixed(2)}%');

    return {
      'uniqueColors': uniqueColors,
      'topTenCoverage': topTenCoverage,
      'totalPixels': totalSampledPixels,
      'imageWidth': image.width,
      'imageHeight': image.height,
    };
  }

  /// Clasifica la imagen basado en el análisis de colores y gradientes.
  ClassificationResult _classifyFromColorAnalysis(Map<String, dynamic> analysis) {
    final uniqueColors = analysis['uniqueColors'] as int;
    final topTenCoverage = analysis['topTenCoverage'] as double;
    final hasSmoothGradients = analysis['hasSmoothGradients'] as bool;

    // FASE 1: Detección de FOTO
    // Criterio 1 (fotos coloridas): >12K colores únicos Y <25% cobertura top 10
    // Criterio 2 (selfies/retratos): >6K colores únicos Y <25% cobertura Y gradientes suaves
    final isColorfulPhoto = uniqueColors > photoUniqueColorsThreshold &&
        topTenCoverage < photoTopTenCoverageThreshold;

    final isSelfiePortrait = uniqueColors > photoUniqueColorsLowThreshold &&
        topTenCoverage < photoTopTenCoverageThreshold &&
        hasSmoothGradients;

    final isPhoto = isColorfulPhoto || isSelfiePortrait;

    if (isPhoto) {
      // Calcular confianza basada en qué criterio cumplió
      double confidence;
      String detectionReason;

      if (isColorfulPhoto) {
        // Foto colorida: alta confianza
        final colorConfidence = (uniqueColors - photoUniqueColorsThreshold) / 20000.0;
        final coverageConfidence = (photoTopTenCoverageThreshold - topTenCoverage) / photoTopTenCoverageThreshold;
        confidence = ((colorConfidence + coverageConfidence) / 2).clamp(0.0, 1.0);
        detectionReason = 'foto colorida';
      } else {
        // Selfie/retrato: confianza media-alta
        final colorConfidence = (uniqueColors - photoUniqueColorsLowThreshold) / 10000.0;
        final coverageConfidence = (photoTopTenCoverageThreshold - topTenCoverage) / photoTopTenCoverageThreshold;
        confidence = ((colorConfidence + coverageConfidence) / 2).clamp(0.5, 0.9);
        detectionReason = 'selfie/retrato (gradientes suaves)';
      }

      debugPrint('[ImageClassifier] ✅ FOTO detectada: $detectionReason (confianza: ${(confidence * 100).toStringAsFixed(1)}%)');

      return ClassificationResult(
        type: DocumentType.photo,
        confidence: confidence,
        metadata: analysis,
      );
    }

    // Default: DOCUMENTO
    debugPrint('[ImageClassifier] ✅ DOCUMENTO detectado');

    return ClassificationResult(
      type: DocumentType.document,
      confidence: 0.8, // Alta confianza para documento (es el caso más común)
      metadata: analysis,
    );
  }
}
