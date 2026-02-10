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

  /// Redimensiona imagen a A4 (2480×3508) si excede esas dimensiones.
  ///
  /// Operación rápida (~100-300ms) que solo ajusta geometría, NO comprime.
  /// Ideal para ejecutar ANTES de clasificación Laplacian para:
  /// - Reducir tiempo de procesamiento (menos píxeles)
  /// - Reducir consumo de memoria
  /// - Mantener calidad suficiente para clasificación (8.7 MP)
  ///
  /// Si la imagen ya es <= A4, retorna el mismo path sin modificar.
  /// Retorna el path de la imagen redimensionada (o la original).
  Future<String> resizeToA4IfNeeded(String imagePath);
}
