import 'package:escandoc/features/image_processing/classification/domain/classification_result.dart';

/// Servicio abstracto para clasificar tipos de imágenes/documentos.
///
/// Detecta si una imagen es:
/// - FOTO real (personas, lugares, objetos)
/// - DOCUMENTO escaneado (facturas, recibos, contratos)
/// - FOLLETO (documento con mucho texto) - futuro
/// - MANUSCRITO (escritura manual) - futuro
/// - etc.
///
/// Estrategia actual (FASE 1 - Solo FOTO):
/// - Análisis de colores únicos
/// - Cobertura de top 10 colores más frecuentes
///
/// Estrategia futura:
/// - Combinar con OCR word count
/// - Detección de escritura manual
/// - Detección de códigos de barras
abstract class ImageClassifier {
  /// Clasifica una imagen y retorna el tipo detectado.
  ///
  /// Parámetros:
  /// - [imagePath]: Ruta de la imagen a clasificar (debe ser JPG)
  ///
  /// Retorna:
  /// - [ClassificationResult] con tipo, confianza y metadata
  ///
  /// Lanza:
  /// - [Exception] si la imagen no existe o no puede ser analizada
  Future<ClassificationResult> classify(String imagePath);
}
