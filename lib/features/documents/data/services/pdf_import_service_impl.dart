import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:path/path.dart' as path;
import 'package:escandoc/features/documents/domain/services/pdf_import_service.dart';

/// Implementación de PdfImportService usando pdfrx + dart:ui nativo.
///
/// Estrategia de renderizado (in-memory, sin archivos PNG temporales):
///   pdfrx.render() → PdfImage → dart:ui Image → PNG bytes en memoria
///   → FlutterImageCompress.compressWithList() → JPG bytes → escribir una vez
///
/// DPI: 150 (1240×1754 px para A4). Suficiente para OCR en texto vectorial
/// (PDF digital = sin ruido óptico, bordes nítidos a cualquier resolución).
class PdfImportServiceImpl implements PdfImportService {
  static const double _dpi = 150.0;
  static const double _pointsPerInch = 72.0;
  static const int _jpgQuality = 90;

  @override
  Future<int> getPageCount(String pdfPath) async {
    PdfDocument? document;
    try {
      document = await PdfDocument.openFile(pdfPath);
      return document.pages.length;
    } catch (e) {
      throw PdfImportException('No se pudo abrir el PDF', pdfPath, e);
    } finally {
      await document?.dispose();
    }
  }

  @override
  Future<List<File>> renderPagesToJpg(
    String pdfPath,
    String outputDir, {
    int maxPages = 10,
  }) async {
    PdfDocument? document;
    try {
      document = await PdfDocument.openFile(pdfPath);
      final pageCount = document.pages.length;
      final pagesToRender = pageCount < maxPages ? pageCount : maxPages;
      final basename = path.basenameWithoutExtension(pdfPath);
      final results = <File>[];

      debugPrint('[PdfImportService] PDF: $pageCount páginas, renderizando $pagesToRender');

      for (var i = 0; i < pagesToRender; i++) {
        final jpgFile = await _renderPageToJpg(
          document.pages[i],
          outputDir,
          basename,
          i,
        );
        results.add(jpgFile);
        debugPrint(
          '[PdfImportService] p${i + 1}/$pagesToRender → ${(jpgFile.lengthSync() / 1024).toStringAsFixed(0)} KB',
        );
      }

      return results;
    } catch (e) {
      if (e is PdfImportException) rethrow;
      throw PdfImportException('Error al renderizar páginas', pdfPath, e);
    } finally {
      await document?.dispose();
    }
  }

  Future<File> _renderPageToJpg(
    PdfPage page,
    String outputDir,
    String basename,
    int pageIndex,
  ) async {
    final scale = _dpi / _pointsPerInch;
    final width = (page.width * scale).round();
    final height = (page.height * scale).round();

    // 1. Renderizar con pdfrx
    final pdfImage = await page.render(
      fullWidth: width.toDouble(),
      fullHeight: height.toDouble(),
      backgroundColor: 0xFFFFFFFF,
    );

    if (pdfImage == null) {
      throw PdfImportException(
        'Página ${pageIndex + 1} retornó null al renderizar',
        basename,
      );
    }

    // 2. PdfImage → dart:ui Image → PNG bytes en memoria (sin tocar disco)
    final uiImage = await pdfImage.createImage();
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
    uiImage.dispose();
    pdfImage.dispose();

    if (byteData == null) {
      throw PdfImportException(
        'Error al encodear página ${pageIndex + 1}',
        basename,
      );
    }

    // 3. PNG bytes → JPG bytes en memoria (flutter_image_compress nativo)
    final jpgBytes = await FlutterImageCompress.compressWithList(
      byteData.buffer.asUint8List(),
      quality: _jpgQuality,
      format: CompressFormat.jpeg,
    );

    // 4. Escribir JPG una sola vez
    final jpgPath = path.join(outputDir, '${basename}_p${pageIndex + 1}.jpg');
    final jpgFile = File(jpgPath);
    await jpgFile.writeAsBytes(jpgBytes);
    return jpgFile;
  }
}
