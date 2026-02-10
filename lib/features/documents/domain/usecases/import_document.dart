import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:escandoc/features/image_processing/format_converter/domain/image_format_converter.dart';
import 'package:escandoc/features/image_processing/normalize_image/domain/normalize_image_use_case.dart';

/// UseCase para importar documentos desde galería/archivos.
///
/// FLUJO:
/// 1. Recibe archivo importado (PNG, WebP, PDF, JPG, etc.)
/// 2. Convierte a JPG si es necesario (ImageFormatConverter)
/// 3. Normaliza a <850 KB (NormalizeImageUseCase)
/// 4. Retorna File JPG listo para SaveScannedDocument
///
/// IMPORTANTE: Este UseCase solo prepara la imagen.
/// El guardado en DB y OCR se hace con SaveScannedDocument + ProcessOCR.
class ImportDocument {
  final ImageFormatConverter _formatConverter;
  final NormalizeImageUseCase _normalizeImage;

  ImportDocument(
    this._formatConverter,
    this._normalizeImage,
  );

  /// Convierte archivo a JPG y redimensiona a A4 si excede (sin comprimir).
  ///
  /// FLUJO OPTIMIZADO:
  /// 1. Convertir a JPG (formato)
  /// 2. Redimensionar a A4 si excede (geometría - rápido)
  /// 3. Retorna listo para clasificación Laplacian
  ///
  /// NO comprime (eso se hace después de clasificar en `normalize()`).
  ///
  /// Parámetros:
  /// - [importedFile]: Archivo importado (cualquier formato soportado)
  ///
  /// Retorna: File JPG redimensionado a A4 (sin comprimir)
  ///
  /// Lanza:
  /// - [UnsupportedImageFormatException] si el formato no es soportado
  /// - [ImageConversionException] si la conversión falla
  Future<File> convertOnly(File importedFile) async {
    try {
      debugPrint('[ImportDocument] 🟢 Convertir a JPG y redimensionar A4');
      debugPrint('[ImportDocument] Archivo: ${importedFile.path}');

      // Verificar que existe
      if (!importedFile.existsSync()) {
        throw Exception('Imported file does not exist: ${importedFile.path}');
      }

      // 1. Convertir a JPG
      final jpgPath = await _formatConverter.convertToJpg(importedFile.path);

      // 2. Redimensionar a A4 si excede (rápido, antes de clasificar)
      final resizedPath = await _normalizeImage.resizeToA4IfNeeded(jpgPath);

      return File(resizedPath);
    } catch (e) {
      debugPrint('[ImportDocument] ERROR en convertOnly: $e');
      rethrow;
    }
  }

  /// Normaliza un archivo JPG a <850 KB.
  ///
  /// Parámetros:
  /// - [jpgFile]: Archivo JPG (ya convertido)
  ///
  /// Retorna: File JPG normalizado (<850 KB)
  Future<File> normalize(File jpgFile) async {
    try {
      debugPrint('[ImportDocument] 🟢 Normalizar JPG');
      final normalizedPath = await _normalizeImage.execute(jpgFile.path);
      return File(normalizedPath);
    } catch (e) {
      debugPrint('[ImportDocument] ERROR en normalize: $e');
      rethrow;
    }
  }

  /// Importa un documento desde archivo y lo prepara para guardar.
  ///
  /// Parámetros:
  /// - [importedFile]: Archivo importado (cualquier formato soportado)
  ///
  /// Retorna: File JPG normalizado (<850 KB) listo para SaveScannedDocument
  ///
  /// Lanza:
  /// - [UnsupportedImageFormatException] si el formato no es soportado
  /// - [ImageConversionException] si la conversión falla
  /// - [Exception] si la normalización falla
  Future<File> call(File importedFile) async {
    try {
      final startImport = DateTime.now();
      debugPrint('[ImportDocument] 🟢 START: Importar documento - ${startImport.millisecondsSinceEpoch}');
      debugPrint('[ImportDocument] Archivo importado: ${importedFile.path}');

      // 1. Verificar que el archivo existe
      if (!importedFile.existsSync()) {
        throw Exception('Imported file does not exist: ${importedFile.path}');
      }

      final originalSize = importedFile.lengthSync();
      debugPrint('[ImportDocument] Tamaño original: ${(originalSize / 1024).toStringAsFixed(2)} KB');

      // 2. Convertir a JPG si es necesario
      final startConversion = DateTime.now();
      debugPrint('[ImportDocument] 🟢 START: Convertir a JPG - ${startConversion.millisecondsSinceEpoch}');

      final jpgPath = await _formatConverter.convertToJpg(importedFile.path);

      final endConversion = DateTime.now();
      final conversionDuration = endConversion.difference(startConversion).inMilliseconds;
      debugPrint('[ImportDocument] 🔴 END: Convertir a JPG - Duración: ${conversionDuration}ms');

      // 3. Normalizar a <850 KB
      final startNormalize = DateTime.now();
      debugPrint('[ImportDocument] 🟢 START: Normalizar - ${startNormalize.millisecondsSinceEpoch}');

      final normalizedPath = await _normalizeImage.execute(jpgPath);

      final endNormalize = DateTime.now();
      final normalizeDuration = endNormalize.difference(startNormalize).inMilliseconds;
      debugPrint('[ImportDocument] 🔴 END: Normalizar - Duración: ${normalizeDuration}ms');

      final endImport = DateTime.now();
      final totalDuration = endImport.difference(startImport).inMilliseconds;
      debugPrint('[ImportDocument] 🔴 END: Importar documento - Duración TOTAL: ${totalDuration}ms');

      return File(normalizedPath);
    } catch (e, stackTrace) {
      debugPrint('[ImportDocument] ERROR: $e');
      debugPrint('[ImportDocument] StackTrace: $stackTrace');
      rethrow;
    }
  }
}
