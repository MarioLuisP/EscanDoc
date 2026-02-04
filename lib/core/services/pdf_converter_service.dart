import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;

/// Servicio para convertir JPG a PDF.
///
/// NOTA: Esta es una función separada y encapsulada.
/// En el futuro, cuando cambiemos la estrategia de guardado
/// (ej: guardar JPG directo en DB), solo modificamos este servicio.
abstract class PdfConverterService {
  /// Convierte una imagen JPG a PDF.
  ///
  /// Retorna el File del PDF generado.
  Future<File> convertJpgToPdf(String jpgPath, String outputPdfPath);
}

/// Implementación del servicio de conversión JPG→PDF.
class PdfConverterServiceImpl implements PdfConverterService {
  @override
  Future<File> convertJpgToPdf(String jpgPath, String outputPdfPath) async {
    try {
      debugPrint('[PdfConverter] Convirtiendo JPG a PDF...');
      debugPrint('[PdfConverter] Input: $jpgPath');
      debugPrint('[PdfConverter] Output: $outputPdfPath');

      // 1. Cargar imagen JPG
      final jpgFile = File(jpgPath);
      if (!jpgFile.existsSync()) {
        throw Exception('JPG file not found: $jpgPath');
      }

      final jpgBytes = await jpgFile.readAsBytes();
      final image = img.decodeImage(jpgBytes);

      if (image == null) {
        throw Exception('Failed to decode JPG: $jpgPath');
      }

      debugPrint('[PdfConverter] JPG decodificado: ${image.width}x${image.height}');

      // 2. Crear PDF con la imagen
      final pdf = pw.Document();

      // Convertir imagen a formato PNG para PDF
      final pngBytes = img.encodePng(image);
      final pdfImage = pw.MemoryImage(pngBytes);

      // Crear página del mismo tamaño que la imagen (sin márgenes)
      final pageFormat = PdfPageFormat(
        image.width.toDouble(),
        image.height.toDouble(),
        marginAll: 0,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context context) {
            return pw.Image(pdfImage, fit: pw.BoxFit.fill);
          },
        ),
      );

      debugPrint('[PdfConverter] PDF creado con 1 página (${image.width}x${image.height}, sin márgenes)');

      // 3. Guardar PDF
      final pdfFile = File(outputPdfPath);
      await pdfFile.writeAsBytes(await pdf.save());

      debugPrint('[PdfConverter] PDF guardado: ${pdfFile.path}');
      debugPrint('[PdfConverter] Tamaño PDF: ${(pdfFile.lengthSync() / 1024).toStringAsFixed(2)} KB');

      return pdfFile;
    } catch (e, stackTrace) {
      debugPrint('[PdfConverter] ERROR: $e');
      debugPrint('[PdfConverter] StackTrace: $stackTrace');
      rethrow;
    }
  }
}
