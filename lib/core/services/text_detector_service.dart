import 'package:flutter/services.dart';

/// Servicio para detectar presencia de texto en imágenes usando OpenCV nativo.
///
/// Usa Laplacian variance para detección ultra-rápida (10-50ms) sin OCR completo.
///
/// Estrategia:
/// - Varianza alta (>threshold) → Tiene texto (bordes finos y estructurados)
/// - Varianza baja (<threshold) → Sin texto (fondo uniforme, foto lisa)
abstract class TextDetectorService {
  /// Detecta texto en una imagen y retorna resultado completo.
  ///
  /// **OPTIMIZADO:** Una sola llamada nativa que retorna ambos valores.
  ///
  /// Parámetros:
  /// - [imagePath]: Ruta absoluta de la imagen a analizar
  /// - [threshold]: Umbral de varianza (default: 600.0)
  ///
  /// Retorna mapa con:
  /// - `variance`: Varianza Laplaciana calculada
  /// - `hasText`: true si variance > threshold
  ///
  /// Performance: ~1.5s en imágenes grandes (12 MP)
  Future<Map<String, dynamic>> detect(String imagePath, {double threshold = 600.0});

  /// [DEPRECATED] Usar detect() en su lugar.
  @Deprecated('Use detect() for better performance')
  Future<bool> hasText(String imagePath, {double threshold = 120.0});

  /// [DEPRECATED] Usar detect() en su lugar.
  @Deprecated('Use detect() for better performance')
  Future<double?> getVariance(String imagePath);
}

/// Implementación nativa del detector de texto usando platform channel.
class TextDetectorServiceImpl implements TextDetectorService {
  static const _platform = MethodChannel('escandoc/text_detector');

  @override
  Future<Map<String, dynamic>> detect(String imagePath, {double threshold = 600.0}) async {
    try {
      final result = await _platform.invokeMethod<Map>('detect', {
        'imagePath': imagePath,
        'threshold': threshold,
      });

      if (result == null) {
        return {'variance': 0.0, 'hasText': false, 'error': 'null_result'};
      }

      return {
        'variance': result['variance'] as double,
        'hasText': result['hasText'] as bool,
      };
    } on PlatformException catch (e) {
      // Error nativo: log y retornar fallback seguro
      // ignore: avoid_print
      print('[TextDetector] Platform error: ${e.message}');
      return {'variance': 0.0, 'hasText': false, 'error': e.message};
    } catch (e) {
      // Error inesperado: fallback seguro
      // ignore: avoid_print
      print('[TextDetector] Unexpected error: $e');
      return {'variance': 0.0, 'hasText': false, 'error': e.toString()};
    }
  }

  @override
  @Deprecated('Use detect() for better performance')
  Future<bool> hasText(String imagePath, {double threshold = 120.0}) async {
    final result = await detect(imagePath, threshold: threshold);
    return result['hasText'] as bool;
  }

  @override
  @Deprecated('Use detect() for better performance')
  Future<double?> getVariance(String imagePath) async {
    final result = await detect(imagePath);
    return result['variance'] as double?;
  }
}
