import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:escandoc/features/scan/domain/usecases/scan_document.dart';
import 'package:escandoc/features/scan/domain/usecases/save_scanned_document.dart';
import 'package:escandoc/features/scan/domain/usecases/process_ocr.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';

/// Provider para manejar el flujo de escaneo de documentos
///
/// Estados:
/// - isScanning: Scanner nativo abierto
/// - isSaving: Guardando PDF/thumbnail
/// - isProcessingOCR: Ejecutando OCR en background
/// - error: Mensaje de error si falla
class ScanProvider with ChangeNotifier {
  final ScanDocument _scanDocument;
  final SaveScannedDocument _saveDocument;
  final ProcessOCR _processOCR;

  ScanProvider({
    required ScanDocument scanDocument,
    required SaveScannedDocument saveDocument,
    required ProcessOCR processOCR,
  })  : _scanDocument = scanDocument,
        _saveDocument = saveDocument,
        _processOCR = processOCR;

  // Estado
  bool _isScanning = false;
  bool _isSaving = false;
  bool _isProcessingOCR = false;
  String? _error;
  DocumentModel? _lastScannedDocument;

  // Getters
  bool get isScanning => _isScanning;
  bool get isSaving => _isSaving;
  bool get isProcessingOCR => _isProcessingOCR;
  bool get isBusy => _isScanning || _isSaving || _isProcessingOCR;
  String? get error => _error;
  DocumentModel? get lastScannedDocument => _lastScannedDocument;

  /// Flujo completo de escaneo:
  /// 1. Abrir scanner nativo
  /// 2. Guardar PDF + thumbnail
  /// 3. Ejecutar OCR en background
  Future<DocumentModel?> scanAndSave(String locale) async {
    try {
      _error = null;
      debugPrint('[ScanProvider] Iniciando flujo de escaneo...');

      // 1. Escanear documento
      _isScanning = true;
      notifyListeners();

      debugPrint('[ScanProvider] Llamando a scanner nativo...');
      final scannedImage = await _scanDocument.call();

      _isScanning = false;
      notifyListeners();

      // Usuario canceló
      if (scannedImage == null) {
        debugPrint('[ScanProvider] Scanner retornó null (usuario canceló o error)');
        return null;
      }

      debugPrint('[ScanProvider] Imagen escaneada recibida: ${scannedImage.path}');

      // 2. Guardar documento
      _isSaving = true;
      notifyListeners();

      // Obtener directorio de storage
      final docsDir = await getApplicationDocumentsDirectory();
      debugPrint('[ScanProvider] Directorio de docs: ${docsDir.path}');

      debugPrint('[ScanProvider] Guardando documento...');
      final document = await _saveDocument.call(
        scannedImage,
        docsDir.path,
        locale,
      );

      _isSaving = false;
      _lastScannedDocument = document;
      notifyListeners();

      debugPrint('[ScanProvider] Documento guardado exitosamente. ID: ${document.id}');

      // 3. Procesar OCR en background (no bloquea UI)
      _processOCRInBackground(document.id!);

      return document;
    } catch (e, stackTrace) {
      _error = e.toString();
      _isScanning = false;
      _isSaving = false;
      notifyListeners();
      debugPrint('[ScanProvider] ERROR en scanAndSave: $e');
      debugPrint('[ScanProvider] StackTrace: $stackTrace');
      return null;
    }
  }

  /// Ejecuta OCR en background sin bloquear UI
  Future<void> _processOCRInBackground(int documentId) async {
    _isProcessingOCR = true;
    notifyListeners();

    try {
      await _processOCR.call(documentId);
    } catch (e) {
      // OCR falla silenciosamente en background
      debugPrint('OCR background error: $e');
    } finally {
      _isProcessingOCR = false;
      notifyListeners();
    }
  }

  /// Limpia estado de error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
