import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:escandoc/core/services/ocr_service.dart';
import 'package:escandoc/core/services/document_classifier.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';
import 'package:escandoc/features/notes/data/models/note_model.dart';
import 'package:escandoc/features/notes/data/repositories/note_repository.dart';
import 'package:escandoc/features/scan/domain/usecases/refine_classification.dart';

/// UseCase para procesar OCR en documento escaneado (SIMPLIFICADO - JPG only)
///
/// FLUJO:
/// 1. Obtener documento de BD (filePath apunta al JPG)
/// 2. Extraer análisis OCR (texto + blockCount + avgConfidence)
/// 3. Refinar clasificación TFLite con métricas OCR (2° paso)
/// 4. Si hubo reclasificación → guardar nota de corrección
/// 5. Extraer fecha de vencimiento si existe
/// 6. Actualizar documento en BD con texto OCR
///
/// Se ejecuta en background después de SaveScannedDocument
class ProcessOCR {
  final OCRService _ocrService;
  final DocumentClassifier _classifier;
  final DocumentRepository _repository;
  final NoteRepository _noteRepository;
  final RefineClassification _refinement;

  ProcessOCR(
    this._ocrService,
    this._classifier,
    this._repository,
    this._noteRepository,
    this._refinement,
  );

  /// Procesa OCR y refina clasificación para el documento dado.
  ///
  /// [tfliteClass]: clasificación inicial del TFLite (ej: 'documento', 'manuscrito').
  /// [locale]: idioma para regenerar el título si hay reclasificación (ej: 'es', 'en').
  Future<DocumentModel> call(
    int documentId, {
    String tfliteClass = 'documento',
    String locale = 'es',
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

      final jpgPath = document.filePath;
      debugPrint('[ProcessOCR] JPG path: $jpgPath');

      final jpgFile = File(jpgPath);
      if (!jpgFile.existsSync()) {
        throw Exception('JPG file not found: $jpgPath');
      }

      // 2. Extraer análisis OCR (texto + métricas)
      final startOCR = DateTime.now();
      debugPrint(
          '[ProcessOCR] 🟢 START: OCR extractAnalysis - ${startOCR.millisecondsSinceEpoch}');
      final ocrAnalysis = await _ocrService.extractAnalysis(jpgFile);
      final endOCR = DateTime.now();
      debugPrint(
          '[ProcessOCR] 🔴 END: OCR extractAnalysis - ${endOCR.difference(startOCR).inMilliseconds}ms'
          ' - ${ocrAnalysis.text.length} chars'
          ' - ${ocrAnalysis.blockCount} bloques'
          ' - avgConf: ${ocrAnalysis.avgConfidence.toStringAsFixed(3)}');

      final extractedText = ocrAnalysis.text;

      // 3. Refinar clasificación TFLite con métricas OCR (2° paso)
      final refinement = _refinement.call(tfliteClass, ocrAnalysis);
      debugPrint('[ProcessOCR] TFLite: $tfliteClass → Refinado: ${refinement.refinedClass}');

      // 4. Si hubo reclasificación → nota de corrección + actualizar título
      String updatedTitle = document.title;
      if (refinement.wasReclassified) {
        debugPrint('[ProcessOCR] 📝 Reclasificado: ${refinement.correctionNote}');
        final now = DateTime.now();
        await _noteRepository.createNote(
          NoteModel(
            content: refinement.correctionNote,
            createdAt: now,
            updatedAt: now,
          ),
          documentId,
        );

        // Regenerar título con el tipo correcto y número secuencial
        final newDisplayName =
            _classifier.getTypeDisplayName(refinement.refinedClass, locale);
        final countForNewType = await _repository.countByTypePrefix(
            newDisplayName, document.createdAt);
        updatedTitle = _classifier.generateDocumentName(
          refinement.refinedClass,
          document.createdAt,
          locale,
          countForNewType + 1,
        );
        debugPrint('[ProcessOCR] 🏷️  Título actualizado: ${document.title} → $updatedTitle');
      }

      // 5. Si es manuscrito → anteponer aviso en el texto OCR
      const _manuscritoDisclaimer =
          '⚠️ Texto manuscrito — el reconocimiento puede contener errores.\n\n';
      final ocrText = refinement.refinedClass == 'manuscrito'
          ? '$_manuscritoDisclaimer$extractedText'
          : extractedText;

      // 6. Extraer fecha de vencimiento si existe
      final extractedDate = _classifier.extractDueDate(ocrText);
      debugPrint('[ProcessOCR] Fecha extraída: $extractedDate');

      // 7. Actualizar documento con texto OCR (y título si hubo reclasificación)
      final updatedDocument = document.copyWith(
        title: updatedTitle,
        ocrText: ocrText,
        extractedDate: extractedDate,
      );

      final startDBUpdate = DateTime.now();
      debugPrint(
          '[ProcessOCR] 🟢 START: Update DB con OCR - ${startDBUpdate.millisecondsSinceEpoch}');
      await _repository.updateDocument(updatedDocument);
      debugPrint(
          '[ProcessOCR] 🔴 END: Update DB con OCR - ${DateTime.now().difference(startDBUpdate).inMilliseconds}ms');

      final totalDuration =
          DateTime.now().difference(startProcess).inMilliseconds;
      debugPrint(
          '[ProcessOCR] 🔴 END: OCR (JPG only) - Duración TOTAL: ${totalDuration}ms');

      return updatedDocument;
    } catch (e, stackTrace) {
      debugPrint('[ProcessOCR] ERROR: $e');
      debugPrint('[ProcessOCR] StackTrace: $stackTrace');
      rethrow;
    }
  }
}
