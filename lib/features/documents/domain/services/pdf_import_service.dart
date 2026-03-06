import 'dart:io';

/// Servicio para importar PDFs como imágenes.
///
/// Responsabilidades:
/// - Contar páginas de un PDF
/// - Renderizar páginas como JPG para el pipeline de importación
///
/// NOTA: La detección de PDF editable (texto nativo) se agrega en una
/// iteración futura. Por ahora, todos los PDFs se tratan como imágenes.
abstract class PdfImportService {
  /// Retorna el número total de páginas del PDF.
  ///
  /// Lanza [PdfImportException] si el archivo no es un PDF válido.
  Future<int> getPageCount(String pdfPath);

  /// Renderiza las primeras [maxPages] páginas a JPG en [outputDir].
  ///
  /// Retorna la lista de archivos JPG generados, en orden de página.
  /// Si el PDF tiene menos páginas que [maxPages], retorna todas.
  ///
  /// Lanza [PdfImportException] si la renderización falla.
  Future<List<File>> renderPagesToJpg(
    String pdfPath,
    String outputDir, {
    int maxPages = 10,
  });

  /// Renderiza una única página (0-indexada) a JPG en [outputDir].
  ///
  /// Lanza [PdfImportException] si falla.
  Future<File> renderPageToJpg(String pdfPath, int pageIndex, String outputDir);
}

/// Excepción para errores de importación de PDF.
class PdfImportException implements Exception {
  final String message;
  final String pdfPath;
  final Object? originalError;

  PdfImportException(this.message, this.pdfPath, [this.originalError]);

  @override
  String toString() =>
      'PdfImportException: $message (file: $pdfPath)'
      '${originalError != null ? '\nOriginal: $originalError' : ''}';
}
