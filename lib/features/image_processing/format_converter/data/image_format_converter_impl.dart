import 'dart:io';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:pdf_image_renderer/pdf_image_renderer.dart';
import 'package:path/path.dart' as path;
import 'package:escandoc/features/image_processing/format_converter/domain/image_format_converter.dart';

/// Implementación del conversor de formatos usando compresión nativa.
///
/// Estrategia de conversión:
/// - PNG/WebP/HEIC → JPG: flutter_image_compress (nativo)
/// - PDF → JPG: pdf_to_image_converter (renderiza primera página)
/// - JPG → JPG: pass-through (sin conversión)
class ImageFormatConverterImpl implements ImageFormatConverter {
  /// Calidad JPG para conversión inicial (alta calidad).
  /// La compresión/normalización se hace después con ImageNormalizerService.
  static const int conversionQuality = 90;

  @override
  Future<String> convertToJpg(String filePath) async {
    try {
      final format = detectFormat(filePath);

      // Verificar que el formato es soportado
      if (!isSupportedFormat(filePath)) {
        throw UnsupportedImageFormatException(format, filePath);
      }

      debugPrint('[FormatConverter] Converting $format to JPG: $filePath');

      // JPG/JPEG → pass-through (sin conversión)
      if (format == 'jpg' || format == 'jpeg') {
        debugPrint('[FormatConverter] Already JPG, skipping conversion');
        return filePath;
      }

      // PDF → extraer primera página
      if (format == 'pdf') {
        return await _convertPdfToJpg(filePath);
      }

      // PNG/WebP/HEIC → JPG con compresión nativa
      return await _convertImageToJpg(filePath, format);
    } catch (e) {
      if (e is UnsupportedImageFormatException ||
          e is ImageConversionException) {
        rethrow;
      }
      throw ImageConversionException(
        'Failed to convert image to JPG',
        filePath,
        e,
      );
    }
  }

  @override
  String detectFormat(String filePath) {
    final extension = path.extension(filePath).toLowerCase().replaceAll('.', '');

    // Normalizar variantes
    if (extension == 'jpeg') return 'jpg';

    return extension;
  }

  @override
  bool isSupportedFormat(String filePath) {
    final format = detectFormat(filePath);
    const supportedFormats = ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'heic'];
    return supportedFormats.contains(format);
  }

  /// Convierte PNG/WebP/HEIC a JPG usando compresión nativa.
  Future<String> _convertImageToJpg(String imagePath, String format) async {
    try {
      final directory = path.dirname(imagePath);
      final filename = path.basenameWithoutExtension(imagePath);
      final jpgPath = path.join(directory, '${filename}_converted.jpg');

      debugPrint('[FormatConverter] Converting $format → JPG with native compress');

      // Conversión nativa (automáticamente convierte formato)
      final result = await FlutterImageCompress.compressWithFile(
        imagePath,
        quality: conversionQuality,
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        throw ImageConversionException(
          'Native compression returned null',
          imagePath,
        );
      }

      // Guardar resultado
      await File(jpgPath).writeAsBytes(result);

      final jpgSize = File(jpgPath).lengthSync();
      debugPrint('[FormatConverter] Converted to JPG: ${(jpgSize / 1024).toStringAsFixed(2)} KB');

      return jpgPath;
    } catch (e) {
      throw ImageConversionException(
        'Failed to convert $format to JPG using native compress',
        imagePath,
        e,
      );
    }
  }

  /// Convierte PDF (primera página) a JPG usando pdf_image_renderer.
  ///
  /// Escala de renderizado: 2x sobre el tamaño nativo de la página (~144 DPI),
  /// suficiente para OCR. La normalización/compresión final ocurre después.
  static const double _pdfRenderScale = 2;

  Future<String> _convertPdfToJpg(String pdfPath) async {
    final pdf = PdfImageRenderer(path: pdfPath);
    try {
      final directory = path.dirname(pdfPath);
      final filename = path.basenameWithoutExtension(pdfPath);
      final jpgPath = path.join(directory, '${filename}_page1.jpg');

      debugPrint('[FormatConverter] Opening PDF: $pdfPath');

      // Abrir documento y primera página (0-indexed)
      await pdf.open();
      await pdf.openPage(pageIndex: 0);
      final size = await pdf.getPageSize(pageIndex: 0);

      debugPrint('[FormatConverter] Rendering PDF page 1');

      // Renderizar primera página completa como PNG
      final pngBytes = await pdf.renderPage(
        pageIndex: 0,
        x: 0,
        y: 0,
        width: size.width,
        height: size.height,
        scale: _pdfRenderScale,
        background: const Color(0xFFFFFFFF),
      );

      // Cerrar página y documento
      await pdf.closePage(pageIndex: 0);
      pdf.close();

      if (pngBytes == null) {
        throw ImageConversionException(
          'PDF page rendering returned null',
          pdfPath,
        );
      }

      debugPrint('[FormatConverter] PDF page rendered');

      // Guardar PNG temporal
      final pngPath = path.join(directory, '${filename}_temp.png');
      await File(pngPath).writeAsBytes(pngBytes);

      // Convertir PNG a JPG con compresión nativa
      final result = await FlutterImageCompress.compressWithFile(
        pngPath,
        quality: conversionQuality,
        format: CompressFormat.jpeg,
      );

      // Eliminar PNG temporal
      await File(pngPath).delete();

      if (result == null) {
        throw ImageConversionException(
          'Failed to convert PDF page to JPG',
          pdfPath,
        );
      }

      // Guardar JPG final
      await File(jpgPath).writeAsBytes(result);

      final jpgSize = File(jpgPath).lengthSync();
      debugPrint('[FormatConverter] PDF page extracted as JPG: ${(jpgSize / 1024).toStringAsFixed(2)} KB');

      return jpgPath;
    } catch (e) {
      if (e is ImageConversionException) rethrow;
      throw ImageConversionException(
        'Failed to convert PDF to JPG',
        pdfPath,
        e,
      );
    }
  }
}
