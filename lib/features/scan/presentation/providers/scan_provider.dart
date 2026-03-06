import 'package:flutter/foundation.dart';
import 'package:escandoc/features/scan/domain/usecases/scan_document.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/image_processing/classification/domain/classification_result.dart';
import 'package:escandoc/core/services/document_pipeline.dart';

export 'package:escandoc/core/services/document_pipeline.dart' show PreparationResult;

/// Provider para manejar el flujo de escaneo de documentos.
///
/// Flujo optimizado en 2 fases:
/// 1. PREPARACIÓN: Scanner nativo → pipeline.prepare() (convert + classify + thumbnail)
/// 2. GUARDADO: pipeline.complete() (comprimir si foto + guardar BD) + OCR background
///
/// Si el usuario cancela en la pantalla de clasificación, se evita el guardado.
class ScanProvider with ChangeNotifier {
  final ScanDocument _scanDocument;
  final DocumentPipeline _pipeline;

  ScanProvider({
    required ScanDocument scanDocument,
    required DocumentPipeline pipeline,
  })  : _scanDocument = scanDocument,
        _pipeline = pipeline;

  // Estado
  bool _isScanning = false;
  bool _isSaving = false;
  bool _isProcessingOCR = false;
  String? _error;
  DocumentModel? _lastScannedDocument;
  ClassificationResult? _lastClassification;

  // Getters
  bool get isScanning => _isScanning;
  bool get isSaving => _isSaving;
  bool get isProcessingOCR => _isProcessingOCR;
  bool get isBusy => _isScanning || _isSaving || _isProcessingOCR;
  String? get error => _error;
  DocumentModel? get lastScannedDocument => _lastScannedDocument;
  ClassificationResult? get lastClassification => _lastClassification;

  /// FASE 1: Abre el scanner nativo y prepara el documento (convert + classify + thumbnail).
  ///
  /// NO guarda en BD. Retorna resultado con clasificación para que la UI
  /// pueda decidir si continuar o cancelar.
  ///
  /// Retorna null si el usuario cancela o si hay un error.
  Future<PreparationResult?> prepareScan() async {
    try {
      _error = null;
      _isScanning = true;
      notifyListeners();

      final startTotal = DateTime.now();
      debugPrint('[ScanProvider] 🟢 START: Preparación - ${startTotal.millisecondsSinceEpoch}');

      final scannedFile = await _scanDocument.call();
      if (scannedFile == null) {
        debugPrint('[ScanProvider] Scanner retornó null (usuario canceló)');
        _isScanning = false;
        notifyListeners();
        return null;
      }

      final result = await _pipeline.prepare(scannedFile);
      _lastClassification = result.classification;

      _isScanning = false;
      notifyListeners();

      debugPrint('[ScanProvider] 🔴 END: Preparación TOTAL - ${DateTime.now().difference(startTotal).inMilliseconds}ms');
      return result;
    } catch (e, stackTrace) {
      _error = e.toString();
      _isScanning = false;
      notifyListeners();
      debugPrint('[ScanProvider] ERROR en prepareScan: $e\n$stackTrace');
      return null;
    }
  }

  /// FASE 2: Guarda el documento en BD y lanza OCR en background.
  ///
  /// Debe llamarse después de prepareScan() y confirmación del usuario.
  ///
  /// Retorna el [DocumentModel] guardado, o null si hay un error.
  Future<DocumentModel?> completeScan(
    PreparationResult preparation,
    String locale,
  ) async {
    try {
      _error = null;
      _isSaving = true;
      notifyListeners();

      final startTotal = DateTime.now();
      debugPrint('[ScanProvider] 🟢 START: Completar - ${startTotal.millisecondsSinceEpoch}');

      final document = await _pipeline.complete(preparation, locale);
      _isSaving = false;
      _lastScannedDocument = document;
      notifyListeners();

      debugPrint('[ScanProvider] 🔴 END: Completar TOTAL - ${DateTime.now().difference(startTotal).inMilliseconds}ms');
      debugPrint('[ScanProvider] Documento guardado. ID: ${document.id}');

      _processOCRInBackground(document.id!, preparation.classification.type, locale);

      return document;
    } catch (e, stackTrace) {
      _error = e.toString();
      _isSaving = false;
      notifyListeners();
      debugPrint('[ScanProvider] ERROR en completeScan: $e\n$stackTrace');
      return null;
    }
  }

  Future<void> _processOCRInBackground(
      int documentId, DocumentType tfliteKind, String locale) async {
    _isProcessingOCR = true;
    notifyListeners();
    await _pipeline.processOCRBackground(documentId, tfliteKind, locale);
    _isProcessingOCR = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
