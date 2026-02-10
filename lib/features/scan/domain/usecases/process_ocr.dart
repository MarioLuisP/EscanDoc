import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:escandoc/core/services/ocr_service.dart';
import 'package:escandoc/core/services/document_classifier.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';

/// UseCase para procesar OCR en documento escaneado (SIMPLIFICADO - JPG only)
///
/// FLUJO SIMPLIFICADO:
/// 1. Obtener documento de BD (filePath apunta al JPG)
/// 2. Extraer texto con OCR desde JPG
/// 3. Re-clasificar tipo basado en texto real
/// 4. Extraer fecha de vencimiento si existe
/// 5. Actualizar documento en BD con texto OCR
///
/// NOTA: Ya NO genera PDF. El JPG permanece como archivo maestro.
/// PDF se generará on-demand solo cuando se necesite compartir/imprimir.
///
/// Se ejecuta en background después de SaveScannedDocument
class ProcessOCR {
  final OCRService _ocrService;
  final DocumentClassifier _classifier;
  final DocumentRepository _repository;

  ProcessOCR(
    this._ocrService,
    this._classifier,
    this._repository,
  );

  /// Procesa OCR para documento y retorna documento actualizado
  ///
  /// SIMPLIFICADO: Solo OCR, sin conversión PDF
  /// - OCR desde JPG
  /// - Actualizar DB con texto OCR
  ///
  /// Lanza Exception si documento no existe
  Future<DocumentModel> call(int documentId) async {
    try {
      final startProcess = DateTime.now();
      debugPrint('[ProcessOCR] 🟢 START: OCR (JPG only) - ${startProcess.millisecondsSinceEpoch}');

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

      // 2. OCR desde JPG
      final startOCR = DateTime.now();
      debugPrint('[ProcessOCR] 🟢 START: OCR extractText - ${startOCR.millisecondsSinceEpoch}');
      final extractedText = await _ocrService.extractText(jpgFile);
      final endOCR = DateTime.now();
      final ocrDuration = endOCR.difference(startOCR).inMilliseconds;
      debugPrint('[ProcessOCR] 🔴 END: OCR extractText - Duración: ${ocrDuration}ms - ${extractedText.length} caracteres');

      // 3. Re-clasificar tipo basado en texto real
      final detectedType = _classifier.detectType(extractedText);
      debugPrint('[ProcessOCR] Tipo detectado: $detectedType');

      // 4. Extraer fecha de vencimiento si existe
      final extractedDate = _classifier.extractDueDate(extractedText);
      debugPrint('[ProcessOCR] Fecha extraída: $extractedDate');

      // 5. Actualizar documento con texto OCR
      final updatedDocument = document.copyWith(
        ocrText: extractedText,
        extractedDate: extractedDate,
      );

      final startDBUpdate = DateTime.now();
      debugPrint('[ProcessOCR] 🟢 START: Update DB con OCR - ${startDBUpdate.millisecondsSinceEpoch}');
      await _repository.updateDocument(updatedDocument);
      final endDBUpdate = DateTime.now();
      debugPrint('[ProcessOCR] 🔴 END: Update DB con OCR - Duración: ${endDBUpdate.difference(startDBUpdate).inMilliseconds}ms');

      final endProcess = DateTime.now();
      final totalDuration = endProcess.difference(startProcess).inMilliseconds;
      debugPrint('[ProcessOCR] 🔴 END: OCR (JPG only) - Duración TOTAL: ${totalDuration}ms');

      return updatedDocument;
    } catch (e, stackTrace) {
      debugPrint('[ProcessOCR] ERROR: $e');
      debugPrint('[ProcessOCR] StackTrace: $stackTrace');
      rethrow;
    }
  }
}
