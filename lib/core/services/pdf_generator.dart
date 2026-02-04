import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';
import 'dart:typed_data';

/// Interface para generador de PDFs y thumbnails
abstract class PDFGenerator {
  Future<File> createPDF(File imageFile, String outputPath);
  Future<File> generateThumbnail(
    File imageFile,
    String outputPath, {
    int size = 200,
  });
  Future<File> extractFirstPageAsImage(File pdfFile, String outputPath);
  Future<File> extractFirstPageForOCR(File pdfFile, String outputPath);
  Future<File> copyPDF(File pdfFile, String outputPath);
}

/// Implementación de generador de PDFs y thumbnails
///
/// Usa:
/// - package:pdf para generar PDFs desde imágenes
/// - package:image para redimensionar thumbnails
class PDFGeneratorImpl implements PDFGenerator {
  /// Crea un PDF desde una imagen escaneada
  ///
  /// Lanza Exception si:
  /// - La imagen no existe
  /// - No se puede escribir en outputPath
  @override
  Future<File> createPDF(File imageFile, String outputPath) async {
    // Validar que la imagen existe
    if (!imageFile.existsSync()) {
      throw Exception('Image file does not exist: ${imageFile.path}');
    }

    // Leer imagen
    final imageBytes = await imageFile.readAsBytes();

    // Crear PDF
    final pdf = pw.Document();
    final image = pw.MemoryImage(imageBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          );
        },
      ),
    );

    // Guardar PDF
    final outputFile = File(outputPath);
    final pdfBytes = await pdf.save();
    await outputFile.writeAsBytes(pdfBytes);

    return outputFile;
  }

  /// Genera thumbnail redimensionado desde imagen
  ///
  /// Lanza Exception si:
  /// - La imagen no existe o es inválida
  /// - No se puede escribir en outputPath
  @override
  Future<File> generateThumbnail(
    File imageFile,
    String outputPath, {
    int size = 200,
  }) async {
    // Validar que la imagen existe
    if (!imageFile.existsSync()) {
      throw Exception('Image file does not exist: ${imageFile.path}');
    }

    // Decodificar imagen
    final imageBytes = await imageFile.readAsBytes();
    final image = img.decodeImage(imageBytes);

    if (image == null) {
      throw Exception('Failed to decode image: ${imageFile.path}');
    }

    // Redimensionar manteniendo aspect ratio
    final thumbnail = img.copyResize(
      image,
      width: size,
      height: size,
      interpolation: img.Interpolation.average,
    );

    // Guardar thumbnail
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(img.encodeJpg(thumbnail, quality: 85));

    return outputFile;
  }

  /// Extrae la primera página de un PDF como imagen
  ///
  /// Lanza Exception si:
  /// - El PDF no existe
  /// - No se puede renderizar el PDF
  /// - No se puede escribir en outputPath
  @override
  Future<File> extractFirstPageAsImage(File pdfFile, String outputPath) async {
    // Validar que el PDF existe
    if (!pdfFile.existsSync()) {
      throw Exception('PDF file does not exist: ${pdfFile.path}');
    }

    // Leer PDF
    final pdfBytes = await pdfFile.readAsBytes();

    // Renderizar primera página a imagen (300 DPI para buena calidad)
    final pageImage = await Printing.raster(
      Uint8List.fromList(pdfBytes),
      pages: [0], // Solo primera página
      dpi: 150, // Resolución suficiente para thumbnail
    );

    // Obtener primera página
    final firstPage = await pageImage.first;

    // Convertir a imagen PNG
    final pngBytes = await firstPage.toPng();

    // Guardar imagen
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(pngBytes);

    return outputFile;
  }

  /// Extrae la primera página de un PDF como imagen para OCR
  ///
  /// Usa 150 DPI y formato PNG (lossless) - balance entre calidad y memoria
  ///
  /// Lanza Exception si:
  /// - El PDF no existe
  /// - No se puede renderizar el PDF
  /// - No se puede escribir en outputPath
  @override
  Future<File> extractFirstPageForOCR(File pdfFile, String outputPath) async {
    // Validar que el PDF existe
    if (!pdfFile.existsSync()) {
      throw Exception('PDF file does not exist: ${pdfFile.path}');
    }

    // Leer PDF
    final pdfBytes = await pdfFile.readAsBytes();

    // Renderizar primera página a imagen (150 DPI óptimo para OCR sin OutOfMemory)
    final pageImage = await Printing.raster(
      Uint8List.fromList(pdfBytes),
      pages: [0], // Solo primera página
      dpi: 150, // Resolución óptima para ML Kit OCR (evita OutOfMemoryError)
    );

    // Obtener primera página
    final firstPage = await pageImage.first;

    // Convertir a PNG (lossless, máxima calidad para OCR)
    final pngBytes = await firstPage.toPng();

    // Guardar imagen
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(pngBytes);

    return outputFile;
  }

  /// Copia un archivo PDF a una nueva ubicación
  ///
  /// Lanza Exception si:
  /// - El PDF no existe
  /// - No se puede escribir en outputPath
  @override
  Future<File> copyPDF(File pdfFile, String outputPath) async {
    // Validar que el PDF existe
    if (!pdfFile.existsSync()) {
      throw Exception('PDF file does not exist: ${pdfFile.path}');
    }

    // Copiar PDF
    final copiedFile = await pdfFile.copy(outputPath);
    return copiedFile;
  }
}
