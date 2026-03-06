import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:escandoc/features/documents/domain/usecases/import_document.dart';
import 'package:escandoc/features/image_processing/classification/domain/image_classifier.dart';
import 'package:escandoc/features/image_processing/classification/domain/classification_result.dart';
import 'package:escandoc/features/scan/domain/usecases/save_scanned_document.dart';
import 'package:escandoc/features/scan/domain/usecases/process_ocr.dart';
import 'package:escandoc/features/image_processing/thumbnail/domain/thumbnail_generator.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';

/// Resultado unificado de la preparación de un documento (escaneo o importación).
class PreparationResult {
  final File processedFile;
  final ClassificationResult classification;
  final bool isNormalized;
  final File? thumbnailFile;

  PreparationResult({
    required this.processedFile,
    required this.classification,
    required this.isNormalized,
    this.thumbnailFile,
  });
}

/// Pipeline compartido de procesamiento de documentos.
///
/// Encapsula la lógica común entre ScanProvider e ImportProvider:
/// convertir JPG → clasificar → comprimir/thumbnail → guardar → OCR background.
///
/// Es una clase pura (no extiende ChangeNotifier). Cada provider maneja
/// su propio estado y delega la lógica de negocio a esta clase.
class DocumentPipeline {
  final ImportDocument _importDocument;
  final ImageClassifier _imageClassifier;
  final SaveScannedDocument _saveDocument;
  final ProcessOCR _processOCR;
  final ThumbnailGenerator _thumbnailGenerator;

  DocumentPipeline({
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

  /// FASE 1: Convierte a JPG + clasifica + comprime si es documento + thumbnail si es foto.
  ///
  /// [onStatus] se llama con claves de localización en cada paso para actualizar la UI.
  Future<PreparationResult> prepare(File file, {void Function(String)? onStatus}) async {
    const tag = 'DocumentPipeline';

    // 1. Convertir a JPG
    onStatus?.call('status_preparing');
    final startConvert = DateTime.now();
    debugPrint('[$tag] 🟢 START: Convertir JPG - ${startConvert.millisecondsSinceEpoch}');
    final jpgFile = await _importDocument.convertOnly(file);
    debugPrint('[$tag] 🔴 END: Convertir JPG - ${DateTime.now().difference(startConvert).inMilliseconds}ms');

    // 2. Clasificar con TFLite
    onStatus?.call('status_analyzing');
    final startClassify = DateTime.now();
    debugPrint('[$tag] 🟢 START: Clasificar - ${startClassify.millisecondsSinceEpoch}');
    final classification = await _imageClassifier.classify(jpgFile.path);
    debugPrint('[$tag] 🔴 END: Clasificar - ${DateTime.now().difference(startClassify).inMilliseconds}ms');
    debugPrint('[$tag] Clasificación: $classification');

    File processedFile;
    bool isNormalized;
    File? thumbnailFile;

    if (classification.type == DocumentType.document) {
      // 3a. Documento: comprimir a <850KB ahora
      onStatus?.call('status_optimizing');
      debugPrint('[$tag] Es documento → comprimiendo a <850KB');
      final startCompress = DateTime.now();
      processedFile = await _importDocument.normalize(jpgFile);
      debugPrint('[$tag] Comprimido en ${DateTime.now().difference(startCompress).inMilliseconds}ms');
      isNormalized = true;
    } else {
      // 3b. Foto: thumbnail para preview; comprimir solo si el usuario confirma
      debugPrint('[$tag] Es foto → thumbnail preview (compresión diferida)');
      processedFile = jpgFile;
      isNormalized = false;
      final startThumb = DateTime.now();
      thumbnailFile = await _thumbnailGenerator.generateThumbnail(
        processedFile.path,
        maxWidth: 200,
      );
      debugPrint('[$tag] Thumbnail en ${DateTime.now().difference(startThumb).inMilliseconds}ms');
    }

    return PreparationResult(
      processedFile: processedFile,
      classification: classification,
      isNormalized: isNormalized,
      thumbnailFile: thumbnailFile,
    );
  }

  /// FASE 2: Comprime si es foto + guarda en BD. Retorna el documento guardado.
  ///
  /// [onStatus] se llama con claves de localización durante el proceso.
  /// [currentDate] permite asignar fecha personalizada (usado en importación de PDFs).
  Future<DocumentModel> complete(
    PreparationResult prep,
    String locale, {
    void Function(String)? onStatus,
    DateTime? currentDate,
  }) async {
    const tag = 'DocumentPipeline';

    File finalFile = prep.processedFile;
    if (!prep.isNormalized) {
      onStatus?.call('status_optimizing');
      debugPrint('[$tag] Foto confirmada → comprimiendo');
      final startCompress = DateTime.now();
      finalFile = await _importDocument.normalize(prep.processedFile);
      debugPrint('[$tag] Comprimido en ${DateTime.now().difference(startCompress).inMilliseconds}ms');
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final label = prep.classification.metadata['label'] as String? ?? 'desconocido';

    onStatus?.call('status_saving');
    final startSave = DateTime.now();
    debugPrint('[$tag] 🟢 START: Guardar - ${startSave.millisecondsSinceEpoch}');
    final document = await _saveDocument.call(
      finalFile,
      docsDir.path,
      locale,
      tfliteClass: label,
      currentDate: currentDate,
    );
    debugPrint('[$tag] 🔴 END: Guardar - ${DateTime.now().difference(startSave).inMilliseconds}ms');

    return document;
  }

  /// Ejecuta OCR en background. Los errores se capturan silenciosamente.
  ///
  /// [onStatus] se llama con claves de localización durante el proceso OCR.
  Future<void> processOCRBackground(
    int documentId,
    String tfliteClass,
    String locale, {
    void Function(String)? onStatus,
  }) async {
    const tag = 'DocumentPipeline';
    final start = DateTime.now();
    debugPrint('[$tag] 🟢 START: OCR background - ${start.millisecondsSinceEpoch}');
    try {
      await _processOCR.call(
        documentId,
        tfliteClass: tfliteClass,
        locale: locale,
        onStatus: onStatus,
      );
      debugPrint('[$tag] 🔴 END: OCR background - ${DateTime.now().difference(start).inMilliseconds}ms');
    } catch (e) {
      debugPrint('[$tag] ❌ OCR background error: $e');
    }
  }
}
