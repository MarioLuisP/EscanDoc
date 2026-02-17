import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:escandoc/core/services/document_classifier.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';
import 'package:escandoc/features/notes/data/models/note_model.dart';
import 'package:escandoc/features/notes/data/repositories/note_repository.dart';

/// UseCase para guardar documento escaneado (JPG only)
///
/// FLUJO:
/// 1. Usar clasificación TFLite para el nombre provisional
/// 2. Contar documentos del mismo tipo creados hoy → número secuencial
/// 3. Generar nombre: "Factura 1 del 17/2"
/// 4. Guardar en BD
/// 5. Crear nota inicial con clasificación TFLite
///
/// ProcessOCR (background) hará:
/// - OCR desde JPG
/// - Refinar clasificación
/// - Actualizar título si el tipo cambia
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
  /// - [tfliteClass]: tipo inicial del clasificador TFLite (ej: 'documento', 'manuscrito')
  /// - [locale]: idioma para el nombre (es/en)
  /// - [initialNotes]: nota automática con clasificación TFLite
  Future<DocumentModel> call(
    File scannedFile,
    String outputDirectory,
    String locale, {
    DateTime? currentDate,
    String? initialNotes,
    String tfliteClass = 'documento',
  }) async {
    final date = currentDate ?? DateTime.now();

    final startSave = DateTime.now();
    debugPrint('[SaveScannedDocument] 🟢 START: Guardado (JPG only) - ${startSave.millisecondsSinceEpoch}');
    debugPrint('[SaveScannedDocument] JPG: ${scannedFile.path}');

    // 1. Obtener nombre visible del tipo y contar existentes hoy
    final displayName = _classifier.getTypeDisplayName(tfliteClass, locale);
    final todayCount = await _repository.countByTypePrefix(displayName, date);
    debugPrint('[SaveScannedDocument] Tipo: $tfliteClass → "$displayName", hoy: $todayCount');

    // 2. Generar nombre: "Factura 1 del 17/2"
    final documentName = _classifier.generateDocumentName(
      tfliteClass,
      date,
      locale,
      todayCount + 1,
    );
    debugPrint('[SaveScannedDocument] Nombre generado: $documentName');

    // 3. Crear modelo de documento
    final document = DocumentModel(
      title: documentName,
      filePath: scannedFile.path,
      ocrText: null,
      extractedDate: null,
      createdAt: date,
      updatedAt: date,
    );

    // 4. Insertar en BD y obtener ID
    final startDB = DateTime.now();
    debugPrint('[SaveScannedDocument] 🟢 START: Insertar en BD - ${startDB.millisecondsSinceEpoch}');
    final insertedId = await _repository.insertDocument(document);
    debugPrint('[SaveScannedDocument] 🔴 END: Insertar en BD - ${DateTime.now().difference(startDB).inMilliseconds}ms - ID: $insertedId');

    // 5. Crear nota inicial si se proporcionó (clasificación TFLite)
    if (initialNotes != null && initialNotes.isNotEmpty) {
      debugPrint('[SaveScannedDocument] 📝 Creando nota inicial: $initialNotes');
      await _noteRepository.createNote(
        NoteModel(content: initialNotes, createdAt: date, updatedAt: date),
        insertedId,
      );
      debugPrint('[SaveScannedDocument] ✅ Nota inicial creada');
    }

    debugPrint('[SaveScannedDocument] 🔴 END: Guardado (JPG only) - ${DateTime.now().difference(startSave).inMilliseconds}ms');

    return document.copyWith(id: insertedId);
  }
}
