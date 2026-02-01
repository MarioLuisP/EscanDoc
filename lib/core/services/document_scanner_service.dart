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
/// para detección automática de bordes
class DocumentScannerServiceImpl implements DocumentScannerService {
  final FlutterDocScanner _scanner = FlutterDocScanner();

  /// Abre scanner nativo y retorna imagen escaneada
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

      // 2. Abrir scanner nativo
      final scannedResult = await _scanner.getScanDocuments();

      debugPrint('[DocumentScanner] Scanner cerrado. Resultado: $scannedResult');

      if (scannedResult == null) {
        debugPrint('[DocumentScanner] scannedResult es null (usuario canceló o error)');
        return null;
      }

      // flutter_doc_scanner puede retornar List<String> o Map dependiendo de la versión
      String? filePath;

      if (scannedResult is List) {
        // API antigua: Lista de paths
        if (scannedResult.isEmpty) {
          debugPrint('[DocumentScanner] Lista vacía');
          return null;
        }
        filePath = scannedResult.first.toString();
        debugPrint('[DocumentScanner] Path desde lista: $filePath');
      } else if (scannedResult is Map) {
        // API nueva: Map con pdfUri y pageCount
        filePath = scannedResult['pdfUri']?.toString();
        debugPrint('[DocumentScanner] Path desde map (pdfUri): $filePath');
        debugPrint('[DocumentScanner] pageCount: ${scannedResult['pageCount']}');
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

      return file;
    } catch (e, stackTrace) {
      // Error de permisos, cancelación, o cualquier otro error
      debugPrint('[DocumentScanner] ERROR: $e');
      debugPrint('[DocumentScanner] StackTrace: $stackTrace');
      return null;
    }
  }
}
