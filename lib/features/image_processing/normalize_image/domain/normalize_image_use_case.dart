import 'package:escandoc/features/image_processing/normalize_image/domain/image_normalizer_service.dart';

/// Use case para normalizar imágenes a un tamaño objetivo.
///
/// **Objetivo:** Reducir tamaño de imágenes a máximo 850 KB para prevenir
/// OutOfMemoryError en dispositivos antiguos (target: personas mayores).
///
/// **Estrategia:**
/// 1. Si imagen <= 850 KB → retornar sin cambios
/// 2. Si imagen > 850 KB → comprimir iterativamente
/// 3. Si es PNG (iOS) → convertir a JPG primero
///
/// **Compresión iterativa:**
/// - Calidades: [90, 85, 80, 75, 70]
/// - Fallback: Redimensionar 80% + calidad 85
class NormalizeImageUseCase {
  final ImageNormalizerService _service;

  /// Tamaño objetivo en bytes: 1.2 MB
  static const int targetSizeBytes = 1200 * 1024;

  NormalizeImageUseCase(this._service);

  /// Ejecuta la normalización de la imagen.
  ///
  /// Retorna el path de la imagen normalizada.
  /// Si la imagen ya cumple el objetivo, retorna el mismo path.
  Future<String> execute(String imagePath) async {
    // 1. Verificar si es PNG (iOS) y convertir a JPG
    String workingPath = imagePath;
    if (imagePath.toLowerCase().endsWith('.png')) {
      workingPath = await _service.convertToJpg(imagePath);
    }

    // 2. Verificar tamaño actual
    final currentSize = _service.getFileSize(workingPath);

    // 3. Si ya cumple el objetivo, retornar sin cambios
    if (currentSize <= targetSizeBytes) {
      return workingPath;
    }

    // 4. Normalizar (comprimir iterativamente)
    final normalizedPath =
        await _service.normalizeImage(workingPath, targetSizeBytes);

    return normalizedPath;
  }

  /// Redimensiona imagen a A4 (2480×3508) si excede.
  ///
  /// Operación rápida (~100-300ms) ideal para ejecutar ANTES de clasificación.
  /// Solo ajusta geometría, NO comprime (eso lo hace execute()).
  ///
  /// Retorna el path de la imagen redimensionada (o la original si no excede A4).
  Future<String> resizeToA4IfNeeded(String imagePath) async {
    return await _service.resizeToA4IfNeeded(imagePath);
  }
}
