import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:escandoc/core/services/pdf_generator.dart';
import 'package:escandoc/core/services/document_classifier.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';
import 'package:path/path.dart' as path;

/// UseCase para guardar documento escaneado
///
/// Orquesta:
/// 1. Generar PDF desde imagen
/// 2. Generar thumbnail
/// 3. Detectar tipo automáticamente (sin OCR inicial)
/// 4. Generar nombre localizado
/// 5. Guardar en BD
///
/// OCR se ejecutará en background después (ProcessOCR UseCase)
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

    // Detectar si el archivo es PDF o imagen
    final isPDF = scannedFile.path.toLowerCase().endsWith('.pdf');
    debugPrint('[SaveScannedDocument] ¿Es PDF? $isPDF');

    File pdfFile;
    File thumbnailFile;

    if (isPDF) {
      // 1a. El scanner ya generó un PDF, copiarlo a nuestro directorio
      final pdfPath = path.join(outputDirectory, 'pdf_$timestamp.pdf');
      debugPrint('[SaveScannedDocument] Copiando PDF a: $pdfPath');
      pdfFile = await _pdfGenerator.copyPDF(scannedFile, pdfPath);
      debugPrint('[SaveScannedDocument] PDF copiado: ${pdfFile.path}');

      // 2a. Extraer primera página del PDF como imagen
      final imageFromPdfPath = path.join(outputDirectory, 'page_$timestamp.png');
      debugPrint('[SaveScannedDocument] Extrayendo primera página del PDF como imagen...');
      final imageFromPdf = await _pdfGenerator.extractFirstPageAsImage(
        pdfFile,
        imageFromPdfPath,
      );
      debugPrint('[SaveScannedDocument] Imagen extraída: ${imageFromPdf.path}');

      // 2b. Generar thumbnail desde la imagen extraída
      final thumbnailPath = path.join(outputDirectory, 'thumb_$timestamp.jpg');
      debugPrint('[SaveScannedDocument] Generando thumbnail desde imagen extraída...');
      thumbnailFile = await _pdfGenerator.generateThumbnail(
        imageFromPdf,
        thumbnailPath,
      );
      debugPrint('[SaveScannedDocument] Thumbnail generado: ${thumbnailFile.path}');
    } else {
      // 1b. Archivo es imagen, crear PDF desde imagen
      final pdfPath = path.join(outputDirectory, 'pdf_$timestamp.pdf');
      debugPrint('[SaveScannedDocument] Generando PDF desde imagen en: $pdfPath');
      pdfFile = await _pdfGenerator.createPDF(scannedFile, pdfPath);
      debugPrint('[SaveScannedDocument] PDF generado: ${pdfFile.path}');

      // 2b. Generar thumbnail desde imagen
      final thumbnailPath = path.join(outputDirectory, 'thumb_$timestamp.jpg');
      debugPrint('[SaveScannedDocument] Generando thumbnail desde imagen...');
      thumbnailFile = await _pdfGenerator.generateThumbnail(
        scannedFile,
        thumbnailPath,
      );
      debugPrint('[SaveScannedDocument] Thumbnail generado: ${thumbnailFile.path}');
    }

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

    // 5. Crear modelo de documento
    final document = DocumentModel(
      title: documentName,
      filePath: pdfFile.path,
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
