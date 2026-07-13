import 'dart:io';
import 'dart:typed_data';
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

  /// Convierte bytes de imagen (PNG/JPG) a PDF de tamaño A4.
  Future<File> convertImageBytesToPdfA4(
      Uint8List imageBytes, String outputPdfPath);

  /// Convierte texto libre a un PDF A4 **paginado** (el texto se reparte en
  /// tantas páginas como haga falta). Para compartir notas largas sin cortar.
  Future<File> convertTextToPdfA4(String text, String outputPdfPath);

  /// Convierte múltiples JPGs a un PDF multipágina.
  /// Cada JPG ocupa una página con sus dimensiones originales.
  Future<File> convertJpgsToPdf(
      List<String> jpgPaths, String outputPdfPath);
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

  @override
  Future<File> convertJpgsToPdf(
      List<String> jpgPaths, String outputPdfPath) async {
    debugPrint('[PdfConverter] convertJpgsToPdf → ${jpgPaths.length} páginas → $outputPdfPath');

    final pdf = pw.Document();

    for (final jpgPath in jpgPaths) {
      final jpgFile = File(jpgPath);
      if (!jpgFile.existsSync()) {
        debugPrint('[PdfConverter] Página no encontrada, saltando: $jpgPath');
        continue;
      }

      final jpgBytes = await jpgFile.readAsBytes();
      final pdfImage = pw.MemoryImage(jpgBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) =>
              pw.Center(child: pw.Image(pdfImage, fit: pw.BoxFit.contain)),
        ),
      );
    }

    final pdfBytes = await pdf.save();
    final pdfFile = File(outputPdfPath);
    await pdfFile.writeAsBytes(pdfBytes);
    debugPrint(
        '[PdfConverter] PDF multipágina: ${(pdfFile.lengthSync() / 1024).toStringAsFixed(2)} KB');
    return pdfFile;
  }

  @override
  Future<File> convertImageBytesToPdfA4(
      Uint8List imageBytes, String outputPdfPath) async {
    debugPrint('[PdfConverter] convertImageBytesToPdfA4 → $outputPdfPath');

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) => pw.Center(
          child: pw.Image(pw.MemoryImage(imageBytes), fit: pw.BoxFit.contain),
        ),
      ),
    );

    final file = File(outputPdfPath);
    await file.writeAsBytes(await pdf.save());
    debugPrint(
        '[PdfConverter] PDF A4 generado: ${(file.lengthSync() / 1024).toStringAsFixed(2)} KB');
    return file;
  }

  @override
  Future<File> convertTextToPdfA4(String text, String outputPdfPath) async {
    debugPrint('[PdfConverter] convertTextToPdfA4 → $outputPdfPath (${text.length} chars)');

    final pdf = pw.Document();
    // MultiPage reparte el contenido en varias páginas automáticamente. Cada
    // renglón del texto es un Paragraph → se preservan los saltos de línea y
    // cada uno puede fluir a la página siguiente. Línea vacía → espacio.
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return text.split('\n').map<pw.Widget>((line) {
            if (line.trim().isEmpty) {
              return pw.SizedBox(height: 10);
            }
            return pw.Paragraph(
              text: line,
              style: const pw.TextStyle(fontSize: 14, lineSpacing: 3),
              margin: const pw.EdgeInsets.only(bottom: 4),
            );
          }).toList();
        },
      ),
    );

    final file = File(outputPdfPath);
    await file.writeAsBytes(await pdf.save());
    debugPrint(
        '[PdfConverter] PDF texto paginado: ${(file.lengthSync() / 1024).toStringAsFixed(2)} KB');
    return file;
  }
}
