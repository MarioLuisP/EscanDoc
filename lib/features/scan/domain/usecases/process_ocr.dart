import 'dart:io';
import 'package:escandoc/core/services/ocr_service.dart';
import 'package:escandoc/core/services/document_classifier.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';

/// UseCase para procesar OCR en documento escaneado
///
/// Orquesta:
/// 1. Obtener documento de BD
/// 2. Extraer texto con OCR (ML Kit)
/// 3. Re-clasificar tipo basado en texto real
/// 4. Extraer fecha de vencimiento si existe
/// 5. Actualizar documento en BD
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
  /// Lanza Exception si documento no existe
  Future<DocumentModel> call(int documentId) async {
    // 1. Obtener documento
    final document = await _repository.getDocumentById(documentId);
    if (document == null) {
      throw Exception('Document not found: $documentId');
    }

    // 2. Extraer texto con OCR
    final imageFile = File(document.filePath);
    final extractedText = await _ocrService.extractText(imageFile);

    // 3. Re-clasificar tipo basado en texto real
    final detectedType = _classifier.detectType(extractedText);

    // 4. Extraer fecha de vencimiento si existe
    final extractedDate = _classifier.extractDueDate(extractedText);

    // 5. Actualizar documento
    final updatedDocument = document.copyWith(
      ocrText: extractedText,
      docType: detectedType,
      extractedDate: extractedDate,
    );

    // 6. Guardar en BD
    await _repository.updateDocument(updatedDocument);

    // 7. Retornar documento actualizado
    return updatedDocument;
  }
}
