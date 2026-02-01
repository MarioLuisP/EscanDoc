import 'dart:io';
import 'package:escandoc/core/services/document_scanner_service.dart';

/// UseCase para escanear documento usando scanner nativo
///
/// Orquesta:
/// - Llamar a flutter_doc_scanner (UI nativa)
/// - Manejar cancelación de usuario
/// - Manejar errores de permisos
///
/// Retorna:
/// - File con imagen escaneada si exitoso
/// - null si usuario cancela o hay error
class ScanDocument {
  final DocumentScannerService _scannerService;

  ScanDocument(this._scannerService);

  /// Ejecuta scan y retorna imagen o null
  Future<File?> call() async {
    try {
      final scannedFile = await _scannerService.scanDocument();
      return scannedFile;
    } catch (e) {
      // Error de permisos, cancelación, o cualquier otro error
      return null;
    }
  }
}
