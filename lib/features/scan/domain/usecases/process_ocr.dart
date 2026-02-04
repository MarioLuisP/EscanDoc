import 'dart:io';
import 'package:escandoc/core/services/ocr_service.dart';
import 'package:escandoc/core/services/document_classifier.dart';
import 'package:escandoc/core/services/pdf_generator.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';
import 'package:path/path.dart' as path;

/// UseCase para procesar OCR en documento escaneado
///
/// Orquesta:
/// 1. Obtener documento de BD
/// 2. Si es PDF, extraer temporalmente como imagen PNG (150 DPI)
/// 3. Extraer texto con OCR (ML Kit)
/// 4. Re-clasificar tipo basado en texto real
/// 5. Extraer fecha de vencimiento si existe
/// 6. Actualizar documento en BD
/// 7. Limpiar archivo temporal si se creó
///
/// Se ejecuta en background después de SaveScannedDocument
class ProcessOCR {
  final OCRService _ocrService;
  final DocumentClassifier _classifier;
  final DocumentRepository _repository;
  final PDFGenerator _pdfGenerator;
  final String _scratchpadPath;

  ProcessOCR(
    this._ocrService,
    this._classifier,
    this._repository,
    this._pdfGenerator,
    this._scratchpadPath,
  );

  /// Procesa OCR para documento y retorna documento actualizado
  ///
  /// Lanza Exception si documento no existe
  Future<DocumentModel> call(int documentId) async {
    File? tempImageFile;

    try {
      // 1. Obtener documento
      final document = await _repository.getDocumentById(documentId);
      if (document == null) {
        throw Exception('Document not found: $documentId');
      }

      // 2. Determinar archivo de imagen para OCR
      final isPDF = document.filePath.toLowerCase().endsWith('.pdf');

      File imageFileForOCR;

      if (isPDF) {
        // 2a. Crear directorio scratchpad si no existe
        final scratchpadDir = Directory(_scratchpadPath);
        if (!scratchpadDir.existsSync()) {
          scratchpadDir.createSync(recursive: true);
        }

        // 2b. Extraer temporalmente PDF como imagen PNG en scratchpad
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final tempImagePath = path.join(_scratchpadPath, 'ocr_temp_$timestamp.png');

        tempImageFile = await _pdfGenerator.extractFirstPageForOCR(
          File(document.filePath),
          tempImagePath,
        );

        imageFileForOCR = tempImageFile;
      } else {
        // 2b. Es una imagen directa
        imageFileForOCR = File(document.filePath);
      }

      // 3. Extraer texto con OCR
      final extractedText = await _ocrService.extractText(imageFileForOCR);

      // 4. Re-clasificar tipo basado en texto real
      final detectedType = _classifier.detectType(extractedText);

      // 5. Extraer fecha de vencimiento si existe
      final extractedDate = _classifier.extractDueDate(extractedText);

      // 6. Actualizar documento
      final updatedDocument = document.copyWith(
        ocrText: extractedText,
        docType: detectedType,
        extractedDate: extractedDate,
      );

      // 7. Guardar en BD
      await _repository.updateDocument(updatedDocument);

      // 8. Retornar documento actualizado
      return updatedDocument;
    } finally {
      // 9. Limpiar archivo temporal si se creó
      if (tempImageFile != null && tempImageFile.existsSync()) {
        await tempImageFile.delete();
      }
    }
  }
}
