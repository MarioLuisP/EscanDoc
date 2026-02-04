import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:escandoc/features/image_processing/normalize_image/domain/normalize_image_use_case.dart';

/// Interface para servicio de escaneo de documentos
abstract class DocumentScannerService {
  Future<File?> scanDocument();
}

/// Implementación usando flutter_doc_scanner
///
/// Usa scanner nativo (ML Kit en Android, VisionKit en iOS)
/// para detección automática de bordes y normalización OCR-first
class DocumentScannerServiceImpl implements DocumentScannerService {
  final FlutterDocScanner _scanner = FlutterDocScanner();
  final NormalizeImageUseCase _normalizeImage;

  DocumentScannerServiceImpl(this._normalizeImage);

  /// Abre scanner nativo y retorna imagen JPG normalizada (850 KB)
  ///
  /// Retorna null si:
  /// - Usuario cancela el scan
  /// - Hay error de permisos
  /// - Ocurre cualquier otro error
  @override
  Future<File?> scanDocument() async {
    try {
      // 1. Solicitar permisos de cámara
      debugPrint('[DocumentScanner] Solicitando permisos de cámara...');
      final status = await Permission.camera.request();

      if (!status.isGranted) {
        debugPrint('[DocumentScanner] Permiso de cámara denegado: $status');
        return null;
      }

      debugPrint('[DocumentScanner] Permiso de cámara otorgado, abriendo scanner...');

      // 2. Abrir scanner nativo (OCR-first: retorna JPG, no PDF)
      final scannedResult = await _scanner.getScannedDocumentAsImages();

      debugPrint('[DocumentScanner] Scanner cerrado. Resultado: $scannedResult');

      if (scannedResult == null) {
        debugPrint('[DocumentScanner] scannedResult es null (usuario canceló o error)');
        return null;
      }

      // getScannedDocumentAsImages() retorna Map con: images, count, Uri, Count
      String? filePath;

      if (scannedResult is Map) {
        // Extraer path del JPG (Android: JPG, iOS: PNG)
        final images = scannedResult['images'] as List?;
        if (images == null || images.isEmpty) {
          debugPrint('[DocumentScanner] ERROR: images está vacío o null');
          return null;
        }

        filePath = images.first.toString();
        debugPrint('[DocumentScanner] Path JPG desde map (images): $filePath');
        debugPrint('[DocumentScanner] count: ${scannedResult['count']}');
      } else {
        debugPrint('[DocumentScanner] ERROR: Tipo de resultado desconocido: ${scannedResult.runtimeType}');
        return null;
      }

      if (filePath == null || filePath.isEmpty) {
        debugPrint('[DocumentScanner] ERROR: No se pudo extraer el path del resultado');
        return null;
      }

      // Limpiar el URI si tiene prefijo file://
      if (filePath.startsWith('file://')) {
        filePath = filePath.substring(7);
      }

      debugPrint('[DocumentScanner] Path limpio: $filePath');

      final file = File(filePath);
      final exists = await file.exists();
      debugPrint('[DocumentScanner] ¿Archivo existe? $exists');

      if (!exists) {
        debugPrint('[DocumentScanner] ERROR: El archivo escaneado no existe en el path');
        return null;
      }

      // 3. Normalizar imagen (OCR-first: reducir a 850 KB)
      debugPrint('[DocumentScanner] Normalizando imagen a 850 KB...');
      final normalizedPath = await _normalizeImage.execute(filePath);
      debugPrint('[DocumentScanner] Imagen normalizada: $normalizedPath');

      final normalizedFile = File(normalizedPath);
      if (!normalizedFile.existsSync()) {
        debugPrint('[DocumentScanner] ERROR: Imagen normalizada no existe');
        return null;
      }

      final normalizedSize = normalizedFile.lengthSync();
      debugPrint('[DocumentScanner] Tamaño normalizado: ${(normalizedSize / 1024).toStringAsFixed(2)} KB');

      return normalizedFile;
    } catch (e, stackTrace) {
      // Error de permisos, cancelación, o cualquier otro error
      debugPrint('[DocumentScanner] ERROR: $e');
      debugPrint('[DocumentScanner] StackTrace: $stackTrace');
      return null;
    }
  }
}
