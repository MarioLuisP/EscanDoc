import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:escandoc/core/services/pdf_generator.dart';
import 'package:escandoc/core/services/document_classifier.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';
import 'package:path/path.dart' as path;

/// UseCase para guardar documento escaneado (Épica 6: OCR-first)
///
/// FLUJO NUEVO (OCR-first):
/// 1. Guardar JPG normalizado temporalmente en filePath
/// 2. Generar thumbnail desde JPG
/// 3. Detectar tipo automáticamente (sin OCR inicial)
/// 4. Generar nombre localizado
/// 5. Guardar en BD
///
/// ProcessOCR (background) hará:
/// - OCR desde JPG
/// - JPG → PDF
/// - Actualizar filePath con PDF
/// - Eliminar JPG
///
/// CLEAN ARCHITECTURE: Este UseCase NO conoce path_provider.
/// El storage path debe ser inyectado desde Data/Presentation layer.
class SaveScannedDocument {
  final PDFGenerator _pdfGenerator;
  final DocumentClassifier _classifier;
  final DocumentRepository _repository;

  SaveScannedDocument(
    this._pdfGenerator,
    this._classifier,
    this._repository,
  );

  /// Guarda documento y retorna modelo con ID
  ///
  /// Parámetros:
  /// - [scannedImage]: Imagen escaneada
  /// - [outputDirectory]: Directorio donde guardar PDF/thumbnail (inyectado)
  /// - [locale]: Idioma para nombre (es/en)
  /// - [currentDate]: Fecha para timestamp (opcional, usa DateTime.now())
  Future<DocumentModel> call(
    File scannedFile,
    String outputDirectory,
    String locale, {
    DateTime? currentDate,
  }) async {
    final date = currentDate ?? DateTime.now();
    final timestamp = date.millisecondsSinceEpoch;

    debugPrint('[SaveScannedDocument] Iniciando guardado...');
    debugPrint('[SaveScannedDocument] Archivo: ${scannedFile.path}');
    debugPrint('[SaveScannedDocument] Output dir: $outputDirectory');

    // ÉPICA 6: OCR-first - No generamos PDF aún
    // Scanner ahora retorna JPG normalizado (850 KB)
    // PDF se generará en ProcessOCR después del OCR

    debugPrint('[SaveScannedDocument] Guardando JPG normalizado temporalmente...');

    // 1. Generar thumbnail desde JPG normalizado
    final thumbnailPath = path.join(outputDirectory, 'thumb_$timestamp.jpg');
    debugPrint('[SaveScannedDocument] Generando thumbnail desde JPG...');
    final thumbnailFile = await _pdfGenerator.generateThumbnail(
      scannedFile,
      thumbnailPath,
    );
    debugPrint('[SaveScannedDocument] Thumbnail generado: ${thumbnailFile.path}');

    // 2. El JPG se guardará temporalmente en filePath
    // ProcessOCR lo reemplazará con el PDF después

    // 3. Detectar tipo (sin OCR inicial, usamos string vacío)
    final detectedType = _classifier.detectType('');
    debugPrint('[SaveScannedDocument] Tipo detectado: $detectedType');

    // 4. Generar nombre localizado
    final documentName = _classifier.generateDocumentName(
      detectedType,
      date,
      locale,
    );
    debugPrint('[SaveScannedDocument] Nombre generado: $documentName');

    // 5. Crear modelo de documento (con JPG temporal en filePath)
    final document = DocumentModel(
      title: documentName,
      filePath: scannedFile.path, // JPG temporal (ProcessOCR lo reemplazará con PDF)
      thumbnailPath: thumbnailFile.path,
      docType: detectedType,
      ocrText: null, // Se llenará después con ProcessOCR
      extractedDate: null,
      createdAt: date,
      updatedAt: date,
    );

    // 6. Insertar en BD y obtener ID
    debugPrint('[SaveScannedDocument] Insertando en BD...');
    final insertedId = await _repository.insertDocument(document);
    debugPrint('[SaveScannedDocument] Documento insertado con ID: $insertedId');

    // 7. Retornar documento con ID
    return document.copyWith(id: insertedId);
  }
}
