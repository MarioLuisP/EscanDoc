import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:escandoc/core/services/ocr_service.dart';
import 'package:escandoc/core/services/document_classifier.dart';
import 'package:escandoc/core/services/document_orientation_service.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';
import 'package:escandoc/features/image_processing/classification/domain/classification_result.dart';
import 'package:escandoc/features/image_processing/classification/domain/image_classifier.dart';
import 'package:escandoc/features/scan/domain/usecases/refine_classification.dart';

/// UseCase para procesar OCR en documento escaneado (JPG only).
///
/// FLUJO:
/// 1. Obtener documento de BD (filePath apunta al JPG)
/// 2. Extraer análisis OCR (texto + blockCount + avgConfidence)
/// 3. Refinar clasificación TFLite con métricas OCR (2° paso)
/// 4. Si hubo reclasificación → actualizar título
/// 5. Extraer fecha de vencimiento si existe
/// 6. Guardar nota de extracto en note_content
/// 7. Actualizar documento en BD con texto OCR
///
/// Se ejecuta en background después de SaveScannedDocument.
class ProcessOCR {
  final OCRService _ocrService;
  final DocumentClassifier _classifier;
  final DocumentRepository _repository;
  final RefineClassification _refinement;
  final DocumentOrientationService? _orientationService;
  final ImageClassifier? _imageClassifier;

  ProcessOCR(
    this._ocrService,
    this._classifier,
    this._repository,
    this._refinement, {
    DocumentOrientationService? orientationService,
    ImageClassifier? imageClassifier,
  })  : _orientationService = orientationService,
        _imageClassifier = imageClassifier;

  /// Procesa OCR y refina clasificación para el documento dado.
  ///
  /// [tfliteKind]: clasificación inicial del TFLite.
  /// [locale]: idioma para regenerar el título si hay reclasificación.
  Future<DocumentModel> call(
    int documentId, {
    DocumentType tfliteKind = DocumentType.documento,
    String locale = 'es',
    void Function(String)? onStatus,
  }) async {
    try {
      final startProcess = DateTime.now();
      debugPrint(
          '[ProcessOCR] 🟢 START: OCR (JPG only) - ${startProcess.millisecondsSinceEpoch}');

      // 1. Obtener documento (filePath apunta al JPG)
      final document = await _repository.getDocumentById(documentId);
      if (document == null) {
        throw Exception('Document not found: $documentId');
      }

      final jpgFile = File(document.filePath);
      debugPrint('[ProcessOCR] JPG path: ${document.filePath}');

      if (!jpgFile.existsSync()) {
        throw Exception('JPG file not found: ${document.filePath}');
      }

      // 2. Extraer análisis OCR (texto + métricas)
      final startOCR = DateTime.now();
      debugPrint(
          '[ProcessOCR] 🟢 START: OCR extractAnalysis - ${startOCR.millisecondsSinceEpoch}');
      var ocrAnalysis = await _ocrService.extractAnalysis(jpgFile, docType: tfliteKind.dbKey);
      final endOCR = DateTime.now();
      debugPrint(
          '[ProcessOCR] 🔴 END: OCR extractAnalysis - ${endOCR.difference(startOCR).inMilliseconds}ms'
          ' - ${ocrAnalysis.text.length} chars'
          ' - ${ocrAnalysis.blockCount} bloques'
          ' - avgConf: ${ocrAnalysis.avgConfidence.toStringAsFixed(3)}');

      // 3. Corrección de orientación si OCR detectó rotación
      DocumentType activeKind = tfliteKind;
      if (ocrAnalysis.detectedRotationDegrees != 0 && _orientationService != null) {
        final degrees = ocrAnalysis.detectedRotationDegrees;
        debugPrint('[ProcessOCR] 🔄 Rotación detectada: ${degrees}° → rotando y re-procesando');

        onStatus?.call('status_fixing_orientation');
        final tRotate = DateTime.now();
        await _orientationService.rotateImage(jpgFile, degrees);
        debugPrint('[ProcessOCR] ⏱️ Rotar: ${DateTime.now().difference(tRotate).inMilliseconds}ms');

        if (_imageClassifier != null) {
          onStatus?.call('status_analyzing');
          final tClassify = DateTime.now();
          final newClassification = await _imageClassifier.classify(jpgFile.path);
          activeKind = newClassification.type;
          debugPrint(
              '[ProcessOCR] ⏱️ Re-clasificar: ${DateTime.now().difference(tClassify).inMilliseconds}ms'
              ' → ${activeKind.dbKey}');
        }

        onStatus?.call('status_extracting');
        final tReOcr = DateTime.now();
        ocrAnalysis = await _ocrService.extractAnalysis(jpgFile, docType: activeKind.dbKey);
        debugPrint(
            '[ProcessOCR] ⏱️ Re-OCR: ${DateTime.now().difference(tReOcr).inMilliseconds}ms'
            ' — ${ocrAnalysis.blockCount} bloques');
      }

      // 4. Refinar clasificación con métricas OCR (2° paso)
      final refinement = _refinement.call(activeKind, ocrAnalysis);
      debugPrint('[ProcessOCR] TFLite: ${tfliteKind.dbKey} → Refinado: ${refinement.refinedKind.dbKey}');

      // Si el tipo cambió, regenerar markdown con el tipo correcto (puede cambiar
      // el formato, ej: documento → recibo activa la tabla en blocksToMarkdown).
      final rebuilt = refinement.wasReclassified
          ? _ocrService.rebuildMarkdown(refinement.refinedKind.dbKey)
          : '';
      final extractedText = rebuilt.isNotEmpty ? rebuilt : ocrAnalysis.text;

      // DEBUG: volcar markdown completo a consola Flutter en chunks de 800 chars
      if (kDebugMode && extractedText.isNotEmpty) {
        debugPrint('[ProcessOCR] ── MD OUTPUT ──────────────────────────────');
        var offset = 0;
        while (offset < extractedText.length) {
          debugPrint(extractedText.substring(offset, (offset + 800).clamp(0, extractedText.length)));
          offset += 800;
        }
        debugPrint('[ProcessOCR] ── MD END ────────────────────────────────');
      }

      // 5. Si hubo reclasificación → actualizar título
      String updatedTitle = document.title;
      if (refinement.wasReclassified) {
        debugPrint('[ProcessOCR] 📝 Reclasificado: ${refinement.correctionNote}');

        final newDisplayName =
            _classifier.getTypeDisplayName(refinement.refinedKind, locale);
        final countForNewType = await _repository.countByTypePrefix(
            newDisplayName, document.createdAt);
        updatedTitle = _classifier.generateDocumentName(
          refinement.refinedKind,
          document.createdAt,
          locale,
          countForNewType + 1,
        );
        debugPrint('[ProcessOCR] 🏷️  Título actualizado: ${document.title} → $updatedTitle');
      }

      // 6. Si es manuscrito → anteponer aviso en el texto OCR
      final ocrText = refinement.refinedKind == DocumentType.manuscrito
          ? '${_manuscritoDisclaimer(locale)}$extractedText'
          : extractedText;

      // 7. Extraer fecha de vencimiento si existe
      final extractedDate = _classifier.extractDueDate(ocrText);
      debugPrint('[ProcessOCR] Fecha extraída: $extractedDate');

      // 8. Construir nota de extracto
      final noteContent = _buildExtractNote(
          refinement.refinedKind, extractedText, ocrAnalysis.topConfidenceText, locale);
      debugPrint('[ProcessOCR] 📝 Nota de extracto: ${noteContent.substring(0, noteContent.length.clamp(0, 60))}...');

      // 9. Actualizar documento con texto OCR, nota, título y tipo
      final updatedDocument = document.copyWith(
        title: updatedTitle,
        documentType: refinement.refinedKind.dbKey,
        ocrText: ocrText,
        extractedDate: extractedDate,
        noteContent: noteContent.isNotEmpty ? noteContent : null,
      );

      final startDBUpdate = DateTime.now();
      debugPrint(
          '[ProcessOCR] 🟢 START: Update DB con OCR - ${startDBUpdate.millisecondsSinceEpoch}');
      await _repository.updateDocument(updatedDocument);
      debugPrint(
          '[ProcessOCR] 🔴 END: Update DB con OCR - ${DateTime.now().difference(startDBUpdate).inMilliseconds}ms');

      debugPrint(
          '[ProcessOCR] 🔴 END: OCR (JPG only) - Duración TOTAL: ${DateTime.now().difference(startProcess).inMilliseconds}ms');

      return updatedDocument;
    } catch (e, stackTrace) {
      debugPrint('[ProcessOCR] ERROR: $e');
      debugPrint('[ProcessOCR] StackTrace: $stackTrace');
      rethrow;
    }
  }

  String _manuscritoDisclaimer(String locale) {
    return locale == 'en'
        ? '⚠️ Handwritten text — recognition may contain errors.\n\n'
        : '⚠️ Texto manuscrito — el reconocimiento puede contener errores.\n\n';
  }

  String _buildManuscritoNote(String topConfidenceText, String locale) {
    final label = locale == 'en' ? 'Handwritten note' : 'Nota manuscrita';
    if (topConfidenceText.trim().isEmpty) return label;
    final prefix = locale == 'en' ? 'Handwritten note of' : 'Nota manuscrita de';
    return '$prefix ${topConfidenceText.trim()}';
  }

  String _buildPrintedNote(String markdown) {
    if (markdown.isEmpty) return '';
    final stripped = markdown
        .replaceAll(RegExp(r'^#{1,3}\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^[-*]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'\|', multiLine: true), ' ')
        .replaceAll(RegExp(r'^---+$', multiLine: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return stripped.length > 70 ? stripped.substring(0, 70).trimRight() : stripped;
  }

  String _buildExtractNote(DocumentType refinedKind, String extractedText,
      String topConfidenceText, String locale) {
    if (refinedKind == DocumentType.manuscrito) {
      return _buildManuscritoNote(topConfidenceText, locale);
    }
    return _buildPrintedNote(extractedText);
  }
}
