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

  /// Convierte archivo a JPG (sin resize ni compresión).
  ///
  /// **OPTIMIZACIÓN (16 Feb 2026):** Eliminado resize A4 previo.
  /// El clasificador TFLite hace su propio resize a 224×224, no necesita A4.
  /// Resize A4 se hace DESPUÉS si usuario acepta (ahorro ~1.5s si cancela foto).
  ///
  /// FLUJO:
  /// 1. Convertir a JPG (formato)
  /// 2. Retorna JPG original listo para clasificación
  ///
  /// Parámetros:
  /// - [importedFile]: Archivo importado (cualquier formato soportado)
  ///
  /// Retorna: File JPG (sin resize, sin comprimir)
  ///
  /// Lanza:
  /// - [UnsupportedImageFormatException] si el formato no es soportado
  /// - [ImageConversionException] si la conversión falla
  Future<File> convertOnly(File importedFile) async {
    try {
      debugPrint('[ImportDocument] 🟢 Convertir a JPG (sin resize)');
      debugPrint('[ImportDocument] Archivo: ${importedFile.path}');

      // Verificar que existe
      if (!importedFile.existsSync()) {
        throw Exception('Imported file does not exist: ${importedFile.path}');
      }

      // 1. Convertir a JPG (solo formato, NO resize)
      final jpgPath = await _formatConverter.convertToJpg(importedFile.path);

      return File(jpgPath);
    } catch (e) {
      debugPrint('[ImportDocument] ERROR en convertOnly: $e');
      rethrow;
    }
  }

  /// Normaliza un archivo JPG: Resize A4 + Compress <850 KB.
  ///
  /// **OPTIMIZACIÓN (16 Feb 2026):** Ahora hace resize A4 + compress.
  /// Antes solo comprimía (resize A4 se hacía en convertOnly).
  /// Ahora resize A4 solo cuando usuario acepta (ahorro si cancela).
  ///
  /// Parámetros:
  /// - [jpgFile]: Archivo JPG original (sin resize)
  ///
  /// Retorna: File JPG normalizado (A4 + <850 KB)
  Future<File> normalize(File jpgFile) async {
    try {
      debugPrint('[ImportDocument] 🟢 Normalizar JPG (Resize A4 + Compress)');

      // 1. Resize A4 si excede (incluido en normalizeImage.execute)
      // 2. Compress a <850 KB
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
