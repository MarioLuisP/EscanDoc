import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

/// Interface para servicio de escaneo de documentos
abstract class DocumentScannerService {
  Future<File?> scanDocument();
}

/// Implementación usando flutter_doc_scanner
///
/// Usa scanner nativo (ML Kit en Android, VisionKit en iOS)
/// para detección automática de bordes.
///
/// IMPORTANTE: Retorna el File sin normalizar (JPG en Android, PNG en iOS).
/// La normalización se hace después del clasificador para optimizar el flujo.
class DocumentScannerServiceImpl implements DocumentScannerService {
  final FlutterDocScanner _scanner = FlutterDocScanner();

  DocumentScannerServiceImpl();

  /// Abre scanner nativo y retorna imagen sin procesar.
  ///
  /// Retorna File del scanner (JPG en Android, PNG en iOS) sin normalizar.
  /// La normalización se hace después del clasificador.
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

      // 2. Abrir scanner nativo (retorna JPG en Android, PNG en iOS)
      final scannedResult = await _scanner.getScannedDocumentAsImages();

      debugPrint('[DocumentScanner] Scanner cerrado. Resultado: $scannedResult');

      if (scannedResult == null) {
        debugPrint('[DocumentScanner] scannedResult es null (usuario canceló o error)');
        return null;
      }

      // getScannedDocumentAsImages() retorna ImageScanResult con: images, count
      final images = scannedResult.images;
      if (images.isEmpty) {
        debugPrint('[DocumentScanner] ERROR: images está vacío');
        return null;
      }

      String filePath = images.first;
      debugPrint('[DocumentScanner] Path: $filePath');
      debugPrint('[DocumentScanner] count: ${scannedResult.count}');

      if (filePath.isEmpty) {
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

      final originalSize = file.lengthSync();
      debugPrint('[DocumentScanner] Tamaño: ${(originalSize / 1024).toStringAsFixed(2)} KB');
      debugPrint('[DocumentScanner] ✅ Scanner retornó archivo sin procesar (será clasificado y normalizado después)');

      return file;
    } catch (e, stackTrace) {
      // Error de permisos, cancelación, o cualquier otro error
      debugPrint('[DocumentScanner] ERROR: $e');
      debugPrint('[DocumentScanner] StackTrace: $stackTrace');
      return null;
    }
  }
}
