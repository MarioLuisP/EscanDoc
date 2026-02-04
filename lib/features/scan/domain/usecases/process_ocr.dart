import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:escandoc/core/services/ocr_service.dart';
import 'package:escandoc/core/services/document_classifier.dart';
import 'package:escandoc/core/services/pdf_converter_service.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';
import 'package:path/path.dart' as path;

/// UseCase para procesar OCR en documento escaneado (Épica 6: OCR-first)
///
/// FLUJO NUEVO (OCR-first):
/// 1. Obtener documento de BD (filePath apunta al JPG normalizado)
/// 2. Extraer texto con OCR desde JPG
/// 3. Re-clasificar tipo basado en texto real
/// 4. Extraer fecha de vencimiento si existe
/// 5. Actualizar documento en BD con texto OCR
/// 6. Convertir JPG → PDF (función separada)
/// 7. Actualizar filePath con PDF en BD
/// 8. Eliminar JPG (o dejarlo para próximo scan)
///
/// Se ejecuta en background después de SaveScannedDocument
class ProcessOCR {
  final OCRService _ocrService;
  final DocumentClassifier _classifier;
  final DocumentRepository _repository;
  final PdfConverterService _pdfConverter;
  final String _outputDirectory;

  ProcessOCR(
    this._ocrService,
    this._classifier,
    this._repository,
    this._pdfConverter,
    this._outputDirectory,
  );

  /// Procesa OCR para documento y retorna documento actualizado
  ///
  /// ÉPICA 6: OCR-first
  /// - OCR desde JPG normalizado
  /// - JPG → PDF
  /// - Actualizar filePath con PDF
  /// - Eliminar JPG
  ///
  /// Lanza Exception si documento no existe
  Future<DocumentModel> call(int documentId) async {
    try {
      debugPrint('[ProcessOCR] Iniciando procesamiento OCR para documento $documentId');

      // 1. Obtener documento (filePath apunta al JPG normalizado)
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

      // 2. OCR desde JPG normalizado
      debugPrint('[ProcessOCR] Extrayendo texto con OCR...');
      final extractedText = await _ocrService.extractText(jpgFile);
      debugPrint('[ProcessOCR] Texto extraído: ${extractedText.length} caracteres');

      // 3. Re-clasificar tipo basado en texto real
      final detectedType = _classifier.detectType(extractedText);
      debugPrint('[ProcessOCR] Tipo detectado: $detectedType');

      // 4. Extraer fecha de vencimiento si existe
      final extractedDate = _classifier.extractDueDate(extractedText);
      debugPrint('[ProcessOCR] Fecha extraída: $extractedDate');

      // 5. Actualizar documento con texto OCR
      var updatedDocument = document.copyWith(
        ocrText: extractedText,
        docType: detectedType,
        extractedDate: extractedDate,
      );

      debugPrint('[ProcessOCR] Guardando texto OCR en BD...');
      await _repository.updateDocument(updatedDocument);
      debugPrint('[ProcessOCR] Texto OCR guardado');

      // 6. Convertir JPG → PDF (función separada)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final pdfPath = path.join(_outputDirectory, 'pdf_$timestamp.pdf');

      debugPrint('[ProcessOCR] Convirtiendo JPG a PDF...');
      final pdfFile = await _pdfConverter.convertJpgToPdf(jpgPath, pdfPath);
      debugPrint('[ProcessOCR] PDF generado: ${pdfFile.path}');

      // 7. Actualizar filePath con PDF en BD
      updatedDocument = updatedDocument.copyWith(filePath: pdfFile.path);

      debugPrint('[ProcessOCR] Actualizando filePath en BD con PDF...');
      await _repository.updateDocument(updatedDocument);
      debugPrint('[ProcessOCR] filePath actualizado con PDF');

      // 8. Eliminar JPG (ya no se necesita)
      debugPrint('[ProcessOCR] Eliminando JPG temporal...');
      if (jpgFile.existsSync()) {
        await jpgFile.delete();
        debugPrint('[ProcessOCR] JPG eliminado');
      }

      debugPrint('[ProcessOCR] Procesamiento completo para documento $documentId');
      return updatedDocument;
    } catch (e, stackTrace) {
      debugPrint('[ProcessOCR] ERROR: $e');
      debugPrint('[ProcessOCR] StackTrace: $stackTrace');
      rethrow;
    }
  }
}
