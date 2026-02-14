import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:escandoc/core/services/document_classifier.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';
import 'package:escandoc/features/notes/data/models/note_model.dart';
import 'package:escandoc/features/notes/data/repositories/note_repository.dart';

/// UseCase para guardar documento escaneado (SIMPLIFICADO - JPG only)
///
/// FLUJO SIMPLIFICADO:
/// 1. Guardar JPG normalizado en filePath
/// 2. Usar mismo JPG como thumbnail (sin comprimir)
/// 3. Detectar tipo automáticamente (sin OCR inicial)
/// 4. Generar nombre localizado
/// 5. Guardar en BD
///
/// ProcessOCR (background) hará:
/// - OCR desde JPG
/// - Actualizar BD con texto OCR
///
/// NOTA: PDF se generará on-demand solo cuando se necesite compartir/imprimir.
///
/// CLEAN ARCHITECTURE: Este UseCase NO conoce path_provider.
/// El storage path debe ser inyectado desde Data/Presentation layer.
class SaveScannedDocument {
  final DocumentClassifier _classifier;
  final DocumentRepository _repository;
  final NoteRepository _noteRepository;

  SaveScannedDocument(
    this._classifier,
    this._repository,
    this._noteRepository,
  );

  /// Guarda documento y retorna modelo con ID
  ///
  /// Parámetros:
  /// - [scannedImage]: Imagen escaneada
  /// - [outputDirectory]: Directorio donde guardar PDF/thumbnail (inyectado)
  /// - [locale]: Idioma para nombre (es/en)
  /// - [currentDate]: Fecha para timestamp (opcional, usa DateTime.now())
  /// - [initialNotes]: Notas iniciales (ej: clasificación) - se crea nota automática
  Future<DocumentModel> call(
    File scannedFile,
    String outputDirectory,
    String locale, {
    DateTime? currentDate,
    String? initialNotes,
  }) async {
    final date = currentDate ?? DateTime.now();
    final timestamp = date.millisecondsSinceEpoch;

    final startSave = DateTime.now();
    debugPrint('[SaveScannedDocument] 🟢 START: Guardado (JPG only) - ${startSave.millisecondsSinceEpoch}');
    debugPrint('[SaveScannedDocument] JPG: ${scannedFile.path}');

    // FLUJO SIMPLIFICADO: Solo guardar JPG, sin thumbnail ni PDF

    // 1. Detectar tipo (sin OCR inicial, usamos string vacío)
    final detectedType = _classifier.detectType('');
    debugPrint('[SaveScannedDocument] Tipo detectado: $detectedType');

    // 2. Generar nombre localizado
    final documentName = _classifier.generateDocumentName(
      detectedType,
      date,
      locale,
    );
    debugPrint('[SaveScannedDocument] Nombre generado: $documentName');

    // 3. Crear modelo de documento
    final document = DocumentModel(
      title: documentName,
      filePath: scannedFile.path, // JPG ~850KB (UI usará cacheWidth para thumbnails)
      ocrText: null, // Se llenará después con ProcessOCR
      extractedDate: null,
      createdAt: date,
      updatedAt: date,
    );

    // 4. Insertar en BD y obtener ID
    final startDB = DateTime.now();
    debugPrint('[SaveScannedDocument] 🟢 START: Insertar en BD - ${startDB.millisecondsSinceEpoch}');
    final insertedId = await _repository.insertDocument(document);
    final endDB = DateTime.now();
    final dbDuration = endDB.difference(startDB).inMilliseconds;
    debugPrint('[SaveScannedDocument] 🔴 END: Insertar en BD - Duración: ${dbDuration}ms - ID: $insertedId');

    // 5. Crear nota inicial si se proporcionó (ej: clasificación TFLite)
    if (initialNotes != null && initialNotes.isNotEmpty) {
      debugPrint('[SaveScannedDocument] 📝 Creando nota inicial: $initialNotes');
      final note = NoteModel(
        content: initialNotes,
        createdAt: date,
        updatedAt: date,
      );
      await _noteRepository.createNote(note, insertedId);
      debugPrint('[SaveScannedDocument] ✅ Nota inicial creada');
    }

    final endSave = DateTime.now();
    final saveDuration = endSave.difference(startSave).inMilliseconds;
    debugPrint('[SaveScannedDocument] 🔴 END: Guardado (JPG only) - Duración TOTAL: ${saveDuration}ms');

    // 6. Retornar documento con ID
    return document.copyWith(id: insertedId);
  }
}
