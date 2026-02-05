/// Servicio abstracto para convertir diferentes formatos de imagen a JPG.
///
/// Soporta:
/// - PNG → JPG
/// - WebP → JPG
/// - PDF (primera página) → JPG
/// - HEIC (iOS) → JPG
/// - JPG/JPEG → pass-through (sin conversión)
///
/// IMPORTANTE: Este servicio solo convierte formatos.
/// La normalización/compresión se hace después con ImageNormalizerService.
abstract class ImageFormatConverter {
  /// Convierte un archivo de cualquier formato soportado a JPG.
  ///
  /// Si el archivo ya es JPG, retorna el path original sin conversión.
  /// Si es otro formato (PNG, WebP, PDF, etc.), lo convierte y retorna nuevo path.
  ///
  /// Lanza [UnsupportedImageFormatException] si el formato no es soportado.
  /// Lanza [ImageConversionException] si la conversión falla.
  Future<String> convertToJpg(String filePath);

  /// Detecta el formato de imagen basado en la extensión del archivo.
  ///
  /// Retorna: 'jpg', 'png', 'webp', 'pdf', 'heic', o 'unknown'
  String detectFormat(String filePath);

  /// Verifica si el formato es soportado para conversión.
  bool isSupportedFormat(String filePath);
}

/// Excepción lanzada cuando el formato de imagen no es soportado.
class UnsupportedImageFormatException implements Exception {
  final String format;
  final String filePath;

  UnsupportedImageFormatException(this.format, this.filePath);

  @override
  String toString() =>
      'UnsupportedImageFormatException: Format "$format" is not supported (file: $filePath)';
}

/// Excepción lanzada cuando la conversión de imagen falla.
class ImageConversionException implements Exception {
  final String message;
  final String filePath;
  final Object? originalError;

  ImageConversionException(this.message, this.filePath, [this.originalError]);

  @override
  String toString() =>
      'ImageConversionException: $message (file: $filePath)${originalError != null ? '\nOriginal error: $originalError' : ''}';
}
