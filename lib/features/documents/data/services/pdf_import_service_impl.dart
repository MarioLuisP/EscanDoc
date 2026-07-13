import 'dart:io';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:pdf_image_renderer/pdf_image_renderer.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import 'package:path/path.dart' as path;
import 'package:escandoc/features/documents/domain/services/pdf_import_service.dart';

/// Implementación de PdfImportService.
///
/// Reemplaza a pdfrx (que entregaba pdfium vía "native assets" experimental y
/// dejaba la app en pantalla blanca según el entorno de build — ver .context/67).
///
/// Dos responsabilidades, dos librerías livianas y nativas del SO:
///   - Rasterizar PDF→JPG: `pdf_image_renderer` (PdfRenderer Android / PDFKit iOS)
///   - Extraer texto (PDF digital): `read_pdf_text` (PdfBox Android / PDFKit iOS)
///
/// La extracción de texto va aislada tras try/catch: si falla, degrada al camino
/// render → OCR (isEditablePdf devuelve false / extractPageText devuelve '').
class PdfImportServiceImpl implements PdfImportService {
  /// Escala de renderizado sobre el tamaño nativo de la página (en puntos).
  /// 2.5 ≈ 180 DPI (72 pt/pulgada × 2.5). PDF digital = bordes nítidos, sin ruido.
  static const double _renderScale = 2.5;
  static const int _jpgQuality = 90;

  @override
  Future<int> getPageCount(String pdfPath) async {
    final pdf = PdfImageRenderer(path: pdfPath);
    try {
      await pdf.open();
      return await pdf.getPageCount();
    } catch (e) {
      throw PdfImportException('No se pudo abrir el PDF', pdfPath, e);
    } finally {
      try {
        pdf.close();
      } catch (_) {/* handle ya inválido — ignorar */}
    }
  }

  @override
  Future<List<File>> renderPagesToJpg(
    String pdfPath,
    String outputDir, {
    int maxPages = 10,
  }) async {
    final pdf = PdfImageRenderer(path: pdfPath);
    var docOpened = false;
    try {
      await pdf.open();
      docOpened = true;
      final pageCount = await pdf.getPageCount();
      final pagesToRender = pageCount < maxPages ? pageCount : maxPages;
      final basename = path.basenameWithoutExtension(pdfPath);
      final results = <File>[];

      debugPrint('[PdfImportService] PDF: $pageCount páginas, renderizando $pagesToRender');

      for (var i = 0; i < pagesToRender; i++) {
        final jpgFile = await _renderPageToJpg(pdf, outputDir, basename, i);
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
      if (docOpened) {
        try {
          pdf.close();
        } catch (_) {/* handle ya inválido — ignorar */}
      }
    }
  }

  @override
  Future<File> renderPageToJpg(String pdfPath, int pageIndex, String outputDir) async {
    final pdf = PdfImageRenderer(path: pdfPath);
    var docOpened = false;
    try {
      await pdf.open();
      docOpened = true;
      final pageCount = await pdf.getPageCount();
      if (pageIndex >= pageCount) {
        throw PdfImportException('Página $pageIndex fuera de rango', pdfPath);
      }
      final basename = path.basenameWithoutExtension(pdfPath);
      return await _renderPageToJpg(pdf, outputDir, basename, pageIndex)
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      if (e is PdfImportException) rethrow;
      throw PdfImportException('Error al renderizar página $pageIndex', pdfPath, e);
    } finally {
      if (docOpened) {
        try {
          pdf.close();
        } catch (_) {/* handle ya inválido — ignorar */}
      }
    }
  }

  @override
  Future<bool> isEditablePdf(String pdfPath) async {
    final text = await extractPageText(pdfPath, 0);
    final meaningfulChars = text.replaceAll(RegExp(r'\s+'), '').length;
    final result = meaningfulChars > 50;
    debugPrint('[PdfImportService] isEditablePdf: $meaningfulChars chars → $result');
    return result;
  }

  @override
  Future<String> extractPageText(String pdfPath, int pageIndex) async {
    // read_pdf_text extrae todo el documento paginado. Aislado tras try/catch:
    // cualquier fallo (PDF sin capa de texto, plugin, etc.) degrada a '' → la app
    // sigue por el camino render → OCR sin romperse.
    try {
      final pages = await ReadPdfText.getPDFtextPaginated(pdfPath)
          .timeout(const Duration(seconds: 15));
      if (pageIndex < 0 || pageIndex >= pages.length) return '';
      return pages[pageIndex];
    } catch (e) {
      debugPrint('[PdfImportService] Error extrayendo texto página $pageIndex: $e');
      return '';
    }
  }

  /// Renderiza una página (sobre un documento ya abierto) → JPG en disco.
  ///
  /// pdf_image_renderer devuelve PNG bytes; se comprimen a JPG (nativo) y se
  /// escribe una sola vez. Abre y cierra la página puntual (no el documento).
  Future<File> _renderPageToJpg(
    PdfImageRenderer pdf,
    String outputDir,
    String basename,
    int pageIndex,
  ) async {
    var pageOpened = false;
    try {
      await pdf.openPage(pageIndex: pageIndex);
      pageOpened = true;
      final size = await pdf.getPageSize(pageIndex: pageIndex);

      // 1. Renderizar página completa como PNG bytes (tamaño nativo × escala)
      final pngBytes = await pdf.renderPage(
        pageIndex: pageIndex,
        x: 0,
        y: 0,
        width: size.width,
        height: size.height,
        scale: _renderScale,
        background: const Color(0xFFFFFFFF),
      );

      if (pngBytes == null) {
        throw PdfImportException(
          'Página ${pageIndex + 1} retornó null al renderizar',
          basename,
        );
      }

      // 2. PNG bytes → JPG bytes en memoria (flutter_image_compress nativo)
      final jpgBytes = await FlutterImageCompress.compressWithList(
        pngBytes,
        quality: _jpgQuality,
        format: CompressFormat.jpeg,
      );

      // 3. Escribir JPG una sola vez
      final jpgPath = path.join(outputDir, '${basename}_p${pageIndex + 1}.jpg');
      final jpgFile = File(jpgPath);
      await jpgFile.writeAsBytes(jpgBytes);
      return jpgFile;
    } finally {
      if (pageOpened) {
        try {
          await pdf.closePage(pageIndex: pageIndex);
        } catch (_) {/* handle ya inválido — ignorar */}
      }
    }
  }
}
