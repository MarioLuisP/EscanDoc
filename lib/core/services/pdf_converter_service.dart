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
      final startConvert = DateTime.now();
      debugPrint('[PdfConverter] 🟢 START: Conversión JPG→PDF - ${startConvert.millisecondsSinceEpoch}');
      debugPrint('[PdfConverter] Input: $jpgPath');
      debugPrint('[PdfConverter] Output: $outputPdfPath');

      // 1. Cargar imagen JPG
      final jpgFile = File(jpgPath);
      if (!jpgFile.existsSync()) {
        throw Exception('JPG file not found: $jpgPath');
      }

      final startRead = DateTime.now();
      final jpgBytes = await jpgFile.readAsBytes();
      final endRead = DateTime.now();
      debugPrint('[PdfConverter]   → readAsBytes: ${endRead.difference(startRead).inMilliseconds}ms');

      // OPTIMIZACIÓN: Insertar JPG directamente (sin decodificar/convertir a PNG)
      final startCreateImage = DateTime.now();
      final pdfImage = pw.MemoryImage(jpgBytes);
      final endCreateImage = DateTime.now();
      debugPrint('[PdfConverter]   → MemoryImage (JPG directo): ${endCreateImage.difference(startCreateImage).inMilliseconds}ms');

      // Leer SOLO las dimensiones del JPG sin decodificar la imagen completa
      final startGetInfo = DateTime.now();
      final decoder = img.JpegDecoder();
      final imageInfo = decoder.startDecode(jpgBytes);
      final endGetInfo = DateTime.now();
      debugPrint('[PdfConverter]   → JpegDecoder.startDecode (solo headers): ${endGetInfo.difference(startGetInfo).inMilliseconds}ms');

      if (imageInfo == null) {
        throw Exception('Failed to read JPG headers: $jpgPath');
      }

      debugPrint('[PdfConverter] JPG dimensiones: ${imageInfo.width}x${imageInfo.height}');

      // 2. Crear PDF con la imagen JPG directa
      final pdf = pw.Document();

      // Crear página del mismo tamaño que la imagen (sin márgenes)
      final pageFormat = PdfPageFormat(
        imageInfo.width.toDouble(),
        imageInfo.height.toDouble(),
        marginAll: 0,
      );

      final startAddPage = DateTime.now();
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context context) {
            return pw.Image(pdfImage, fit: pw.BoxFit.fill);
          },
        ),
      );
      final endAddPage = DateTime.now();
      debugPrint('[PdfConverter]   → addPage: ${endAddPage.difference(startAddPage).inMilliseconds}ms');

      // 3. Guardar PDF
      final startSave = DateTime.now();
      final pdfBytes = await pdf.save();
      final endSave = DateTime.now();
      debugPrint('[PdfConverter]   → pdf.save(): ${endSave.difference(startSave).inMilliseconds}ms');

      final startWrite = DateTime.now();
      final pdfFile = File(outputPdfPath);
      await pdfFile.writeAsBytes(pdfBytes);
      final endWrite = DateTime.now();
      debugPrint('[PdfConverter]   → writeAsBytes: ${endWrite.difference(startWrite).inMilliseconds}ms');

      debugPrint('[PdfConverter] Tamaño PDF: ${(pdfFile.lengthSync() / 1024).toStringAsFixed(2)} KB');

      final endConvert = DateTime.now();
      final totalDuration = endConvert.difference(startConvert).inMilliseconds;
      debugPrint('[PdfConverter] 🔴 END: Conversión JPG→PDF - Duración TOTAL: ${totalDuration}ms');

      return pdfFile;
    } catch (e, stackTrace) {
      debugPrint('[PdfConverter] ERROR: $e');
      debugPrint('[PdfConverter] StackTrace: $stackTrace');
      rethrow;
    }
  }
}
