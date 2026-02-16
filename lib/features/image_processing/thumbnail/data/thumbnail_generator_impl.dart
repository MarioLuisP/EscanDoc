import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:escandoc/features/image_processing/thumbnail/domain/thumbnail_generator.dart';

/// Implementación del generador de thumbnails usando dart:ui nativo.
///
/// **Estrategia de optimización:**
/// 1. dart:ui decode + resize a targetWidth (nativo ~100ms)
/// 2. Extraer bytes RGBA (~10ms)
/// 3. flutter_image_compress para encodear JPG (~50-100ms)
///
/// **Total:** ~200ms vs 500-2000ms con Image.file de imagen completa
class ThumbnailGeneratorImpl implements ThumbnailGenerator {
  @override
  Future<File> generateThumbnail(
    String imagePath, {
    int maxWidth = 400,
  }) async {
    final startTime = DateTime.now();
    debugPrint('[ThumbnailGenerator] 🟢 Generando thumbnail: $imagePath');
    debugPrint('[ThumbnailGenerator] Target width: ${maxWidth}px');

    try {
      // 1. Leer bytes de la imagen original
      final bytes = await File(imagePath).readAsBytes();

      // 2. Decodificar + resize con dart:ui (nativo, rápido)
      // ui.instantiateImageCodec mantiene aspect ratio automáticamente con solo targetWidth
      final startDecode = DateTime.now();
      final resizedCodec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: maxWidth,
        // targetHeight omitido → aspect ratio se mantiene automáticamente
      );
      final resizedFrame = await resizedCodec.getNextFrame();
      final resizedImage = resizedFrame.image;
      final decodeDuration = DateTime.now().difference(startDecode).inMilliseconds;

      debugPrint('[ThumbnailGenerator] Original → Thumbnail: ${maxWidth}x${resizedImage.height}');
      debugPrint('[ThumbnailGenerator] ⏱️ Decode + resize: ${decodeDuration}ms');

      // 4. Encodear a PNG (intermedio para comprimir a JPG)
      final startEncode = DateTime.now();
      final pngBytes = await resizedImage.toByteData(format: ui.ImageByteFormat.png);

      // Liberar recurso
      resizedImage.dispose();

      if (pngBytes == null) {
        throw Exception('No se pudo encodear thumbnail a PNG');
      }

      // Crear path para thumbnail
      final directory = path.dirname(imagePath);
      final filename = path.basenameWithoutExtension(imagePath);
      final thumbnailPath = path.join(directory, '${filename}_thumb.jpg');

      // Comprimir PNG → JPG con calidad media (suficiente para preview)
      final jpgBytes = await FlutterImageCompress.compressWithList(
        pngBytes.buffer.asUint8List(),
        quality: 85,
        format: CompressFormat.jpeg,
      );

      // Guardar thumbnail
      await File(thumbnailPath).writeAsBytes(jpgBytes);

      final encodeDuration = DateTime.now().difference(startEncode).inMilliseconds;
      debugPrint('[ThumbnailGenerator] ⏱️ Encode a JPG: ${encodeDuration}ms');

      final totalDuration = DateTime.now().difference(startTime).inMilliseconds;
      final thumbnailSize = (jpgBytes.length / 1024).toStringAsFixed(1);
      debugPrint('[ThumbnailGenerator] ✅ Thumbnail generado: ${thumbnailSize} KB');
      debugPrint('[ThumbnailGenerator] ⏱️ TOTAL: ${totalDuration}ms');

      return File(thumbnailPath);
    } catch (e, stackTrace) {
      debugPrint('[ThumbnailGenerator] ❌ Error generando thumbnail: $e');
      debugPrint('[ThumbnailGenerator] StackTrace: $stackTrace');

      // Fallback: retornar imagen original
      debugPrint('[ThumbnailGenerator] Fallback: retornando imagen original');
      return File(imagePath);
    }
  }
}
