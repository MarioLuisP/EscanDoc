import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:escandoc/features/scan/domain/usecases/scan_document.dart';
import 'package:escandoc/features/scan/domain/usecases/save_scanned_document.dart';
import 'package:escandoc/features/scan/domain/usecases/process_ocr.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/domain/usecases/import_document.dart';
import 'package:escandoc/features/image_processing/classification/domain/image_classifier.dart';
import 'package:escandoc/features/image_processing/classification/domain/classification_result.dart';

/// Resultado de la preparación de escaneo.
///
/// Contiene la imagen procesada y su clasificación.
/// - Fotos: convertidas JPG + redimensionadas A4 (sin comprimir) para ahorrar tiempo
/// - Documentos: convertidas JPG + redimensionadas A4 + comprimidas <850KB
///
/// El UI puede decidir si continuar o cancelar basado en la clasificación.
class ScanPreparationResult {
  final File processedFile;
  final ClassificationResult classification;
  final bool isNormalized;

  ScanPreparationResult({
    required this.processedFile,
    required this.classification,
    required this.isNormalized,
  });
}

/// Provider para manejar el flujo de escaneo de documentos
///
/// Flujo optimizado dividido en 2 fases:
/// 1. PREPARACIÓN: Scanner + Convertir JPG + Resize A4 + Clasificar (+ Comprimir solo si es documento)
/// 2. GUARDADO: Comprimir si es foto + Guardar en BD + OCR background
///
/// Ahorro de tiempo: Si usuario cancela una foto, evitamos normalización (~6s)
///
/// Estados:
/// - isScanning: Scanner nativo abierto o procesando imagen
/// - isSaving: Guardando en BD
/// - isProcessingOCR: Ejecutando OCR en background
/// - error: Mensaje de error si falla
class ScanProvider with ChangeNotifier {
  final ScanDocument _scanDocument;
  final ImportDocument _importDocument;
  final ImageClassifier _imageClassifier;
  final SaveScannedDocument _saveDocument;
  final ProcessOCR _processOCR;

  ScanProvider({
    required ScanDocument scanDocument,
    required ImportDocument importDocument,
    required ImageClassifier imageClassifier,
    required SaveScannedDocument saveDocument,
    required ProcessOCR processOCR,
  })  : _scanDocument = scanDocument,
        _importDocument = importDocument,
        _imageClassifier = imageClassifier,
        _saveDocument = saveDocument,
        _processOCR = processOCR;

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

  /// FASE 1: Prepara documento escaneado (scanner + convierte JPG + resize A4 + clasifica + comprime si es documento).
  ///
  /// OPTIMIZACIÓN: Resize A4 ANTES de clasificar (más rápido). Solo comprime si es DOCUMENTO.
  /// Las fotos se comprimen en FASE 2 solo si el usuario confirma (ahorro ~6s si cancela).
  ///
  /// NO guarda en BD todavía. Retorna resultado con clasificación
  /// para que el UI pueda decidir si continuar o cancelar.
  ///
  /// Retorna:
  /// - [ScanPreparationResult] con imagen procesada y clasificación
  /// - null si falla o usuario cancela
  Future<ScanPreparationResult?> prepareScan() async {
    try {
      _error = null;
      _isScanning = true;
      notifyListeners();

      final startTotal = DateTime.now();
      debugPrint('[ScanProvider] 🟢 START: Preparación de escaneo - ${startTotal.millisecondsSinceEpoch}');

      // 1. Abrir scanner nativo (retorna JPG en Android, PNG en iOS)
      final startScan = DateTime.now();
      debugPrint('[ScanProvider] 🟢 START: Scanner nativo - ${startScan.millisecondsSinceEpoch}');
      final scannedFile = await _scanDocument.call();
      final endScan = DateTime.now();
      final scanDuration = endScan.difference(startScan).inMilliseconds;
      debugPrint('[ScanProvider] 🔴 END: Scanner nativo - Duración: ${scanDuration}ms');

      // Usuario canceló
      if (scannedFile == null) {
        debugPrint('[ScanProvider] Scanner retornó null (usuario canceló o error)');
        _isScanning = false;
        notifyListeners();
        return null;
      }

      debugPrint('[ScanProvider] Archivo escaneado: ${scannedFile.path}');

      // 2. Convertir a JPG + Redimensionar A4 (geometría, sin comprimir)
      final startConvert = DateTime.now();
      debugPrint('[ScanProvider] 🟢 START: Convertir JPG + Resize A4 - ${startConvert.millisecondsSinceEpoch}');
      final jpgFile = await _importDocument.convertOnly(scannedFile);
      final endConvert = DateTime.now();
      final convertDuration = endConvert.difference(startConvert).inMilliseconds;
      debugPrint('[ScanProvider] 🔴 END: Convertir JPG + Resize A4 - Duración: ${convertDuration}ms');

      // 3. Clasificar Laplacian (sobre imagen A4, más rápido)
      final startClassify = DateTime.now();
      debugPrint('[ScanProvider] 🟢 START: Clasificar imagen - ${startClassify.millisecondsSinceEpoch}');
      final classification = await _imageClassifier.classify(jpgFile.path);
      final endClassify = DateTime.now();
      final classifyDuration = endClassify.difference(startClassify).inMilliseconds;
      debugPrint('[ScanProvider] 🔴 END: Clasificar imagen - Duración: ${classifyDuration}ms');
      debugPrint('[ScanProvider] Clasificación: $classification');

      _lastClassification = classification;

      File processedFile;
      bool isNormalized;

      // 4. Comprimir solo si es DOCUMENTO (ya está redimensionado a A4)
      if (classification.type == DocumentType.document) {
        debugPrint('[ScanProvider] Es documento → comprimiendo a <850KB ahora');
        final startCompress = DateTime.now();
        processedFile = await _importDocument.normalize(jpgFile);
        final endCompress = DateTime.now();
        final compressDuration = endCompress.difference(startCompress).inMilliseconds;
        debugPrint('[ScanProvider] Comprimido en ${compressDuration}ms');
        isNormalized = true;
      } else {
        debugPrint('[ScanProvider] Es foto → saltando compresión (se hará si usuario acepta)');
        processedFile = jpgFile;
        isNormalized = false;
      }

      _isScanning = false;
      notifyListeners();

      final endTotal = DateTime.now();
      final totalDuration = endTotal.difference(startTotal).inMilliseconds;
      debugPrint('[ScanProvider] 🔴 END: Preparación completa - Duración TOTAL: ${totalDuration}ms');

      return ScanPreparationResult(
        processedFile: processedFile,
        classification: classification,
        isNormalized: isNormalized,
      );
    } catch (e, stackTrace) {
      _error = e.toString();
      _isScanning = false;
      notifyListeners();
      debugPrint('[ScanProvider] ERROR en prepareScan: $e');
      debugPrint('[ScanProvider] StackTrace: $stackTrace');
      return null;
    }
  }

  /// FASE 2: Completa el escaneo (comprime si es foto + guarda en BD + OCR background).
  ///
  /// Debe llamarse después de prepareScan() y confirmación del usuario.
  ///
  /// Si es foto (no comprimida), comprime ahora. Si es documento, ya está comprimido.
  ///
  /// Parámetros:
  /// - [preparation]: Resultado de prepareScan con imagen procesada
  /// - [locale]: Idioma para nombrar documento
  ///
  /// Retorna:
  /// - [DocumentModel] guardado con ID
  /// - null si falla
  Future<DocumentModel?> completeScan(
    ScanPreparationResult preparation,
    String locale,
  ) async {
    try {
      _error = null;
      _isSaving = true;
      notifyListeners();

      final startTotal = DateTime.now();
      debugPrint('[ScanProvider] 🟢 START: Completar escaneo - ${startTotal.millisecondsSinceEpoch}');

      File finalFile = preparation.processedFile;

      // Comprimir si es foto (no comprimida en FASE 1, pero ya redimensionada a A4)
      if (!preparation.isNormalized) {
        debugPrint('[ScanProvider] Foto confirmada → comprimiendo a <850KB ahora');
        final startCompress = DateTime.now();
        finalFile = await _importDocument.normalize(preparation.processedFile);
        final endCompress = DateTime.now();
        final compressDuration = endCompress.difference(startCompress).inMilliseconds;
        debugPrint('[ScanProvider] Comprimido en ${compressDuration}ms');
      }

      // Obtener directorio de storage
      final docsDir = await getApplicationDocumentsDirectory();
      debugPrint('[ScanProvider] Directorio de docs: ${docsDir.path}');

      // Guardar documento
      final startSave = DateTime.now();
      debugPrint('[ScanProvider] 🟢 START: Guardar documento - ${startSave.millisecondsSinceEpoch}');
      final document = await _saveDocument.call(
        finalFile,
        docsDir.path,
        locale,
      );
      final endSave = DateTime.now();
      final saveDuration = endSave.difference(startSave).inMilliseconds;
      debugPrint('[ScanProvider] 🔴 END: Guardar documento - Duración: ${saveDuration}ms');

      _isSaving = false;
      _lastScannedDocument = document;
      notifyListeners();

      debugPrint('[ScanProvider] Documento guardado exitosamente. ID: ${document.id}');

      final endTotal = DateTime.now();
      final totalDuration = endTotal.difference(startTotal).inMilliseconds;
      debugPrint('[ScanProvider] 🔴 END: Completar escaneo - Duración TOTAL: ${totalDuration}ms');

      // Procesar OCR en background (no bloquea UI)
      _processOCRInBackground(document.id!);

      return document;
    } catch (e, stackTrace) {
      _error = e.toString();
      _isSaving = false;
      notifyListeners();
      debugPrint('[ScanProvider] ERROR en completeScan: $e');
      debugPrint('[ScanProvider] StackTrace: $stackTrace');
      return null;
    }
  }

  /// MÉTODO LEGACY: Flujo completo sin clasificación (para compatibilidad).
  ///
  /// Usa prepareScan() + completeScan() internamente.
  /// Para el flujo nuevo con clasificación, usar prepareScan() seguido de
  /// completeScan() desde el UI.
  @Deprecated('Use prepareScan() + completeScan() for classification support')
  Future<DocumentModel?> scanAndSave(String locale) async {
    final preparation = await prepareScan();
    if (preparation == null) return null;

    return await completeScan(preparation, locale);
  }

  /// Ejecuta OCR en background sin bloquear UI
  Future<void> _processOCRInBackground(int documentId) async {
    _isProcessingOCR = true;
    notifyListeners();

    final startBackground = DateTime.now();
    debugPrint('[ScanProvider] 🟢 START: Procesamiento OCR background - ${startBackground.millisecondsSinceEpoch}');

    try {
      await _processOCR.call(documentId);
      final endBackground = DateTime.now();
      final backgroundDuration = endBackground.difference(startBackground).inMilliseconds;
      debugPrint('[ScanProvider] 🔴 END: Procesamiento OCR background - Duración: ${backgroundDuration}ms');
    } catch (e) {
      // OCR falla silenciosamente en background
      debugPrint('[ScanProvider] ❌ OCR background error: $e');
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
