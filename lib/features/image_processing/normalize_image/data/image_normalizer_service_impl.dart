import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:escandoc/features/image_processing/normalize_image/domain/image_normalizer_service.dart';

/// Implementación concreta del servicio de normalización de imágenes.
///
/// Usa el package `image` para procesar y comprimir imágenes.
class ImageNormalizerServiceImpl implements ImageNormalizerService {
  /// Calidades de compresión a intentar (de mayor a menor).
  static const List<int> qualityLevels = [90, 85, 80, 75, 70];

  /// Porcentaje de redimensionamiento para fallback.
  static const double fallbackScalePercent = 0.8;

  /// Calidad usada después del redimensionamiento fallback.
  static const int fallbackQuality = 85;

  @override
  int getFileSize(String imagePath) {
    final file = File(imagePath);
    if (!file.existsSync()) {
      throw Exception('Image file not found: $imagePath');
    }
    return file.lengthSync();
  }

  @override
  Future<String> normalizeImage(String imagePath, int targetSizeBytes) async {
    // 1. Cargar imagen
    final imageBytes = await File(imagePath).readAsBytes();
    final image = img.decodeImage(imageBytes);

    if (image == null) {
      throw Exception('Failed to decode image: $imagePath');
    }

    // 2. Intentar con diferentes calidades
    for (final quality in qualityLevels) {
      final compressedPath = await _compressImage(
        image,
        imagePath,
        quality,
        suffix: '_q$quality',
      );

      final compressedSize = getFileSize(compressedPath);

      // Si cumple el objetivo, retornar
      if (compressedSize <= targetSizeBytes) {
        return compressedPath;
      }

      // Si no cumple, eliminar y continuar
      await File(compressedPath).delete();
    }

    // 3. Fallback: Redimensionar + comprimir
    return await _applyFallback(image, imagePath, targetSizeBytes);
  }

  @override
  Future<String> convertToJpg(String imagePath) async {
    // Si ya es JPG, retornar sin cambios
    if (imagePath.toLowerCase().endsWith('.jpg') ||
        imagePath.toLowerCase().endsWith('.jpeg')) {
      return imagePath;
    }

    // Cargar imagen
    final imageBytes = await File(imagePath).readAsBytes();
    final image = img.decodeImage(imageBytes);

    if (image == null) {
      throw Exception('Failed to decode image for conversion: $imagePath');
    }

    // Crear path JPG
    final directory = path.dirname(imagePath);
    final filename = path.basenameWithoutExtension(imagePath);
    final jpgPath = path.join(directory, '$filename.jpg');

    // Guardar como JPG con calidad 90 (conversión inicial)
    final jpgBytes = img.encodeJpg(image, quality: 90);
    await File(jpgPath).writeAsBytes(jpgBytes);

    return jpgPath;
  }

  /// Comprime una imagen con la calidad especificada.
  Future<String> _compressImage(
    img.Image image,
    String originalPath,
    int quality, {
    String suffix = '',
  }) async {
    final directory = path.dirname(originalPath);
    final filename = path.basenameWithoutExtension(originalPath);
    final newPath = path.join(directory, '$filename$suffix.jpg');

    final compressedBytes = img.encodeJpg(image, quality: quality);
    await File(newPath).writeAsBytes(compressedBytes);

    return newPath;
  }

  /// Aplica el fallback: redimensionar + comprimir.
  Future<String> _applyFallback(
    img.Image image,
    String originalPath,
    int targetSizeBytes,
  ) async {
    // Redimensionar a 80% del ancho original
    final newWidth = (image.width * fallbackScalePercent).round();
    final resized = img.copyResize(
      image,
      width: newWidth,
      interpolation: img.Interpolation.average,
    );

    // Comprimir con calidad 85
    final fallbackPath = await _compressImage(
      resized,
      originalPath,
      fallbackQuality,
      suffix: '_fallback',
    );

    // Verificar que cumple el objetivo
    final fallbackSize = getFileSize(fallbackPath);

    if (fallbackSize > targetSizeBytes) {
      // Log warning - aún así retornamos la imagen
      // En casos extremos puede seguir siendo más grande
      print(
        'Warning: Fallback image still exceeds target '
        '($fallbackSize > $targetSizeBytes bytes)',
      );
    }

    return fallbackPath;
  }
}
