import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:escandoc/features/documents/domain/usecases/import_document.dart';
import 'package:escandoc/features/scan/domain/usecases/save_scanned_document.dart';
import 'package:escandoc/features/scan/domain/usecases/process_ocr.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/image_processing/classification/domain/image_classifier.dart';
import 'package:escandoc/features/image_processing/classification/domain/classification_result.dart';
import 'package:escandoc/features/image_processing/thumbnail/domain/thumbnail_generator.dart';

/// Resultado de la preparación de importación.
///
/// **OPTIMIZACIÓN (16 Feb 2026):** Eliminado resize A4 previo.
///
/// Contiene la imagen procesada y su clasificación.
/// - Fotos: convertidas JPG (original) + thumbnail preview (NO resize A4)
/// - Documentos: convertidas JPG + comprimidas <850KB (resize A4 + compress)
///
/// El UI puede decidir si continuar o cancelar basado en la clasificación.
class ImportPreparationResult {
  final File processedFile;
  final ClassificationResult classification;
  final bool isNormalized;
  final File? thumbnailFile; // Thumbnail optimizado para preview (solo si es foto)

  ImportPreparationResult({
    required this.processedFile,
    required this.classification,
    required this.isNormalized,
    this.thumbnailFile,
  });
}

/// Provider para manejar el flujo de importación de documentos.
///
/// **OPTIMIZACIÓN (16 Feb 2026):** Eliminado resize A4 previo.
///
/// Flujo optimizado dividido en 2 fases:
/// 1. PREPARACIÓN: Convertir JPG + Clasificar + Thumbnail (NO resize A4)
/// 2. GUARDADO: Resize A4 + Comprimir + Guardar en BD + OCR background
///
/// Ahorro de tiempo: Si usuario cancela foto, evitamos resize A4 + compress (~3.5s)
///
/// Estados:
/// - isImporting: Convirtiendo/normalizando imagen importada
/// - isSaving: Guardando en BD
/// - isProcessingOCR: Ejecutando OCR en background
/// - error: Mensaje de error si falla
class ImportProvider with ChangeNotifier {
  final ImportDocument _importDocument;
  final ImageClassifier _imageClassifier;
  final SaveScannedDocument _saveDocument;
  final ProcessOCR _processOCR;
  final ThumbnailGenerator _thumbnailGenerator;

  ImportProvider({
    required ImportDocument importDocument,
    required ImageClassifier imageClassifier,
    required SaveScannedDocument saveDocument,
    required ProcessOCR processOCR,
    required ThumbnailGenerator thumbnailGenerator,
  })  : _importDocument = importDocument,
        _imageClassifier = imageClassifier,
        _saveDocument = saveDocument,
        _processOCR = processOCR,
        _thumbnailGenerator = thumbnailGenerator;

  // Estado
  bool _isImporting = false;
  bool _isSaving = false;
  bool _isProcessingOCR = false;
  String? _error;
  DocumentModel? _lastImportedDocument;
  ClassificationResult? _lastClassification;

  // Getters
  bool get isImporting => _isImporting;
  bool get isSaving => _isSaving;
  bool get isProcessingOCR => _isProcessingOCR;
  bool get isBusy => _isImporting || _isSaving || _isProcessingOCR;
  String? get error => _error;
  DocumentModel? get lastImportedDocument => _lastImportedDocument;
  ClassificationResult? get lastClassification => _lastClassification;

  /// FASE 1: Prepara documento importado (convierte JPG + clasifica).
  ///
  /// **OPTIMIZACIÓN (16 Feb 2026):** NO hace resize A4 previo (TFLite hace resize a 224×224).
  /// Solo comprime si es DOCUMENTO. Las fotos se comprimen en FASE 2 solo si usuario confirma.
  ///
  /// NO guarda en BD todavía. Retorna resultado con clasificación
  /// para que el UI pueda decidir si continuar o cancelar.
  ///
  /// Parámetros:
  /// - [importedFile]: Archivo importado (cualquier formato soportado)
  ///
  /// Retorna:
  /// - [ImportPreparationResult] con imagen procesada y clasificación
  /// - null si falla
  Future<ImportPreparationResult?> prepareImport(File importedFile) async {
    try {
      _error = null;
      _isImporting = true;
      notifyListeners();

      final startTotal = DateTime.now();
      debugPrint('[ImportProvider] 🟢 START: Preparación de importación - ${startTotal.millisecondsSinceEpoch}');

      // 1. Convertir a JPG + Redimensionar A4 (geometría, sin comprimir)
      final startConvert = DateTime.now();
      debugPrint('[ImportProvider] 🟢 START: Convertir JPG (sin resize) - ${startConvert.millisecondsSinceEpoch}');
      final jpgFile = await _importDocument.convertOnly(importedFile);
      final endConvert = DateTime.now();
      final convertDuration = endConvert.difference(startConvert).inMilliseconds;
      debugPrint('[ImportProvider] 🔴 END: Convertir JPG (sin resize) - Duración: ${convertDuration}ms');

      // 2. Clasificar imagen con TFLite
      final startClassify = DateTime.now();
      debugPrint('[ImportProvider] 🟢 START: Clasificar imagen - ${startClassify.millisecondsSinceEpoch}');
      final classification = await _imageClassifier.classify(jpgFile.path);
      final endClassify = DateTime.now();
      final classifyDuration = endClassify.difference(startClassify).inMilliseconds;
      debugPrint('[ImportProvider] 🔴 END: Clasificar imagen - Duración: ${classifyDuration}ms');
      debugPrint('[ImportProvider] Clasificación: $classification');

      _lastClassification = classification;

      File processedFile;
      bool isNormalized;
      File? thumbnailFile;

      // 3. Comprimir solo si es DOCUMENTO (ya está redimensionado a A4)
      if (classification.type == DocumentType.document) {
        debugPrint('[ImportProvider] Es documento → comprimiendo a <850KB ahora');
        final startCompress = DateTime.now();
        processedFile = await _importDocument.normalize(jpgFile);
        final endCompress = DateTime.now();
        final compressDuration = endCompress.difference(startCompress).inMilliseconds;
        debugPrint('[ImportProvider] Comprimido en ${compressDuration}ms');
        isNormalized = true;
      } else {
        debugPrint('[ImportProvider] Es foto → saltando compresión (se hará si usuario acepta)');
        processedFile = jpgFile;
        isNormalized = false;

        // 4. Generar thumbnail para preview (solo si es foto)
        debugPrint('[ImportProvider] 🟢 START: Generar thumbnail para preview');
        final startThumb = DateTime.now();
        thumbnailFile = await _thumbnailGenerator.generateThumbnail(
          processedFile.path,
          maxWidth: 200, // Reducido de 400 → 200px (4x menos píxeles = ~4x más rápido)
        );
        final thumbDuration = DateTime.now().difference(startThumb).inMilliseconds;
        debugPrint('[ImportProvider] 🔴 END: Thumbnail generado en ${thumbDuration}ms');
      }

      _isImporting = false;
      notifyListeners();

      final endTotal = DateTime.now();
      final totalDuration = endTotal.difference(startTotal).inMilliseconds;
      debugPrint('[ImportProvider] 🔴 END: Preparación completa - Duración TOTAL: ${totalDuration}ms');

      return ImportPreparationResult(
        processedFile: processedFile,
        classification: classification,
        isNormalized: isNormalized,
        thumbnailFile: thumbnailFile,
      );
    } catch (e, stackTrace) {
      _error = e.toString();
      _isImporting = false;
      notifyListeners();
      debugPrint('[ImportProvider] ERROR en prepareImport: $e');
      debugPrint('[ImportProvider] StackTrace: $stackTrace');
      return null;
    }
  }

  /// FASE 2: Completa la importación (comprime si es foto + guarda en BD + OCR background).
  ///
  /// Debe llamarse después de prepareImport() y confirmación del usuario.
  ///
  /// Si es foto (no comprimida), comprime ahora. Si es documento, ya está comprimido.
  ///
  /// Parámetros:
  /// - [preparation]: Resultado de prepareImport con imagen procesada
  /// - [locale]: Idioma para nombrar documento
  ///
  /// Retorna:
  /// - [DocumentModel] guardado con ID
  /// - null si falla
  Future<DocumentModel?> completeImport(
    ImportPreparationResult preparation,
    String locale,
  ) async {
    try {
      _error = null;
      _isSaving = true;
      notifyListeners();

      final startTotal = DateTime.now();
      debugPrint('[ImportProvider] 🟢 START: Completar importación - ${startTotal.millisecondsSinceEpoch}');

      File finalFile = preparation.processedFile;

      // Comprimir si es foto (no comprimida en FASE 1, pero ya redimensionada a A4)
      if (!preparation.isNormalized) {
        debugPrint('[ImportProvider] Foto confirmada → comprimiendo a <850KB ahora');
        final startCompress = DateTime.now();
        finalFile = await _importDocument.normalize(preparation.processedFile);
        final endCompress = DateTime.now();
        final compressDuration = endCompress.difference(startCompress).inMilliseconds;
        debugPrint('[ImportProvider] Comprimido en ${compressDuration}ms');
      }

      // Obtener directorio de storage
      final docsDir = await getApplicationDocumentsDirectory();
      debugPrint('[ImportProvider] Directorio de docs: ${docsDir.path}');

      final label = preparation.classification.metadata['label'] as String? ?? 'desconocido';

      // Guardar documento
      final startSave = DateTime.now();
      debugPrint('[ImportProvider] 🟢 START: Guardar documento - ${startSave.millisecondsSinceEpoch}');
      final document = await _saveDocument.call(
        finalFile,
        docsDir.path,
        locale,
        tfliteClass: label,
      );
      final endSave = DateTime.now();
      final saveDuration = endSave.difference(startSave).inMilliseconds;
      debugPrint('[ImportProvider] 🔴 END: Guardar documento - Duración: ${saveDuration}ms');

      _isSaving = false;
      _lastImportedDocument = document;
      notifyListeners();

      debugPrint('[ImportProvider] Documento guardado exitosamente. ID: ${document.id}');

      final endTotal = DateTime.now();
      final totalDuration = endTotal.difference(startTotal).inMilliseconds;
      debugPrint('[ImportProvider] 🔴 END: Completar importación - Duración TOTAL: ${totalDuration}ms');

      // Procesar OCR en background (no bloquea UI)
      _processOCRInBackground(document.id!, label, locale);

      return document;
    } catch (e, stackTrace) {
      _error = e.toString();
      _isSaving = false;
      notifyListeners();
      debugPrint('[ImportProvider] ERROR en completeImport: $e');
      debugPrint('[ImportProvider] StackTrace: $stackTrace');
      return null;
    }
  }

  /// MÉTODO LEGACY: Flujo completo sin clasificación (para compatibilidad).
  ///
  /// Usa prepareImport() + completeImport() internamente.
  /// Para el flujo nuevo con clasificación, usar prepareImport() seguido de
  /// completeImport() desde el UI.
  @Deprecated('Use prepareImport() + completeImport() for classification support')
  Future<DocumentModel?> importAndSave(File importedFile, String locale) async {
    final preparation = await prepareImport(importedFile);
    if (preparation == null) return null;

    return await completeImport(preparation, locale);
  }

  /// Ejecuta OCR en background sin bloquear UI
  Future<void> _processOCRInBackground(
      int documentId, String tfliteClass, String locale) async {
    _isProcessingOCR = true;
    notifyListeners();

    final startBackground = DateTime.now();
    debugPrint('[ImportProvider] 🟢 START: Procesamiento OCR background - ${startBackground.millisecondsSinceEpoch}');

    try {
      await _processOCR.call(documentId, tfliteClass: tfliteClass, locale: locale);
      final endBackground = DateTime.now();
      final backgroundDuration = endBackground.difference(startBackground).inMilliseconds;
      debugPrint('[ImportProvider] 🔴 END: Procesamiento OCR background - Duración: ${backgroundDuration}ms');
    } catch (e) {
      // OCR falla silenciosamente en background
      debugPrint('[ImportProvider] ❌ OCR background error: $e');
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
