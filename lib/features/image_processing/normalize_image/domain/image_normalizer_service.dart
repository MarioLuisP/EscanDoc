/// Servicio abstracto para normalización de imágenes.
///
/// Define las operaciones necesarias para normalizar imágenes
/// a un tamaño objetivo sin perder calidad excesiva.
abstract class ImageNormalizerService {
  /// Obtiene el tamaño en bytes de un archivo.
  int getFileSize(String imagePath);

  /// Normaliza una imagen al tamaño objetivo mediante compresión iterativa.
  ///
  /// Retorna el path de la imagen normalizada.
  Future<String> normalizeImage(String imagePath, int targetSizeBytes);

  /// Convierte una imagen PNG a JPG.
  ///
  /// Útil para iOS que retorna PNG del scanner nativo.
  /// Retorna el path de la imagen JPG resultante.
  Future<String> convertToJpg(String imagePath);
}
