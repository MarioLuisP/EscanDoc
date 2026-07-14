import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:escandoc/core/database/database_helper.dart';
import 'package:escandoc/core/utils/text_normalizer.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';

/// Repository para operaciones CRUD de documentos en SQLite
/// Implementa la capa de acceso a datos (Data Layer)
class DocumentRepository {
  final DatabaseHelper _dbHelper;

  DocumentRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Obtiene todos los documentos ordenados por fecha (más reciente primero)
  Future<List<DocumentModel>> getAllDocuments() async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'documents',
        orderBy: 'created_at DESC',
      );

      return maps.map((map) => DocumentModel.fromMap(map)).toList();
    } catch (e) {
      debugPrint('[DocumentRepository] ERROR getAllDocuments: $e');
      return [];
    }
  }

  /// Obtiene un documento por su ID
  Future<DocumentModel?> getDocumentById(int id) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'documents',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) return null;
      return DocumentModel.fromMap(maps.first);
    } catch (e) {
      debugPrint('[DocumentRepository] ERROR getDocumentById($id): $e');
      return null;
    }
  }

  /// Inserta un nuevo documento y retorna el ID generado
  Future<int> insertDocument(DocumentModel document) async {
    final db = await _dbHelper.database;
    final map = document.toMap();
    map['title_search'] = TextNormalizer.normalize(document.title);
    map['note_search'] = document.noteContent != null
        ? TextNormalizer.normalize(document.noteContent!)
        : null;
    return await db.insert('documents', map);
  }

  /// Actualiza un documento existente
  Future<int> updateDocument(DocumentModel document) async {
    final db = await _dbHelper.database;

    // Crear map sin el 'id' (PRIMARY KEY no debe actualizarse)
    final map = document.toMap();
    map.remove('id');
    map['title_search'] = TextNormalizer.normalize(document.title);
    map['note_search'] = document.noteContent != null
        ? TextNormalizer.normalize(document.noteContent!)
        : null;

    return await db.update(
      'documents',
      map,
      where: 'id = ?',
      whereArgs: [document.id],
    );
  }

  /// Crea un documento de tipo nota (pergamino) y retorna el ID generado.
  Future<int> createNoteDocument({
    required String title,
    required String filePath,
    required String noteContent,
  }) {
    final doc = DocumentModel(
      title: title,
      filePath: filePath,
      documentType: 'nota',
      noteContent: noteContent,
      createdAt: DateTime.now(),
    );
    return insertDocument(doc);
  }

  /// Elimina un documento de la BD y sus archivos asociados.
  /// Retorna true si se eliminó correctamente.
  ///
  /// Orden deliberado: BD primero, filesystem después.
  /// - Si falla la BD → archivo intacto, estado consistente.
  /// - Si falla el filesystem → archivo huérfano en disco, pero sin registro
  ///   en BD → no hay crash al cargar documentos.
  Future<bool> deleteDocument(int id) async {
    try {
      // 1. Obtener documento para acceder a la ruta del archivo
      final document = await getDocumentById(id);
      if (document == null) return false;

      // 2. Eliminar registro de BD primero
      final db = await _dbHelper.database;
      final rowsDeleted = await db.delete(
        'documents',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rowsDeleted == 0) return false;

      // 3. Eliminar archivo del filesystem (best-effort)
      await _deleteFile(document.filePath);

      return true;
    } catch (e) {
      debugPrint('[DocumentRepository] ERROR deleteDocument($id): $e');
      return false;
    }
  }

  /// Elimina varios documentos en un solo lote.
  ///
  /// Mismo criterio que [deleteDocument] pero en una sola pasada:
  /// - Lee las rutas y borra los registros dentro de una transacción (BD primero).
  /// - Borra los archivos del filesystem después, best-effort y en paralelo.
  ///
  /// Devuelve los ids efectivamente borrados (los que existían en la BD).
  Future<List<int>> deleteDocuments(List<int> ids) async {
    if (ids.isEmpty) return [];
    try {
      final db = await _dbHelper.database;
      final placeholders = List.filled(ids.length, '?').join(',');

      final List<int> deletedIds = [];
      final List<String> filePaths = [];

      await db.transaction((txn) async {
        // 1. Rutas + ids de los docs a borrar (una sola query).
        final rows = await txn.query(
          'documents',
          columns: ['id', 'file_path'],
          where: 'id IN ($placeholders)',
          whereArgs: ids,
        );
        if (rows.isEmpty) return;

        for (final row in rows) {
          deletedIds.add(row['id'] as int);
          filePaths.add(row['file_path'] as String);
        }

        // 2. Borrar todos los registros en una sola sentencia.
        await txn.delete(
          'documents',
          where: 'id IN ($placeholders)',
          whereArgs: ids,
        );
      });

      // 3. Borrar archivos del filesystem (best-effort, en paralelo).
      await Future.wait(filePaths.map(_deleteFile));

      return deletedIds;
    } catch (e) {
      debugPrint('[DocumentRepository] ERROR deleteDocuments($ids): $e');
      return [];
    }
  }

  /// Actualiza la fecha de vencimiento de un documento.
  /// Pasar null para quitar el vencimiento.
  Future<void> updateExpiryDate(int documentId, DateTime? expiryDate) async {
    final db = await _dbHelper.database;
    await db.update(
      'documents',
      {'expiry_date': expiryDate?.toIso8601String()},
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }

  /// Retorna todos los documentos que tienen expiry_date asignado,
  /// ordenados por fecha de vencimiento ascendente.
  Future<List<DocumentModel>> getDocumentsWithExpiry() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'documents',
        where: 'expiry_date IS NOT NULL',
        orderBy: 'expiry_date ASC',
      );
      return maps.map((m) => DocumentModel.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[DocumentRepository] ERROR getDocumentsWithExpiry: $e');
      return [];
    }
  }

  /// Retorna documentos con vencimiento dentro del rango [start, end] inclusive.
  /// Útil para cargar solo los meses visibles en el calendario.
  Future<List<DocumentModel>> getDocumentsExpiringInRange(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final db = await _dbHelper.database;
      final startStr = start.toIso8601String().substring(0, 10);
      final endStr = end.toIso8601String().substring(0, 10);
      final maps = await db.query(
        'documents',
        where: 'expiry_date IS NOT NULL AND date(expiry_date) BETWEEN ? AND ?',
        whereArgs: [startStr, endStr],
        orderBy: 'expiry_date ASC',
      );
      return maps.map((m) => DocumentModel.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[DocumentRepository] ERROR getDocumentsExpiringInRange: $e');
      return [];
    }
  }

  /// Actualiza el campo note_content de un documento
  Future<void> updateNote(int documentId, String? content) async {
    final db = await _dbHelper.database;
    await db.update(
      'documents',
      {
        'note_content': content,
        'note_search': content != null ? TextNormalizer.normalize(content) : null,
      },
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }

  /// Actualiza el texto de la nota y su imagen (nuevo file_path) en una sola
  /// operación. Se usa al editar una nota: el texto cambió, así que hay que
  /// regenerar el pergamino y apuntar el documento a la imagen nueva.
  Future<void> updateNoteImage(
      int documentId, String? content, String filePath) async {
    final db = await _dbHelper.database;
    await db.update(
      'documents',
      {
        'note_content': content,
        'note_search': content != null ? TextNormalizer.normalize(content) : null,
        'file_path': filePath,
      },
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }

  /// Cuenta documentos cuyo título empieza con [prefix] creados en [date]
  ///
  /// Usado para generar el número secuencial del nombre:
  /// "Factura 1 del 17/2" → prefix = "Factura"
  Future<int> countByTypePrefix(String prefix, DateTime date) async {
    try {
      final db = await _dbHelper.database;
      final dayStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final result = await db.rawQuery(
        "SELECT COUNT(*) as count FROM documents "
        "WHERE title LIKE ? AND date(created_at) = ?",
        ['$prefix %', dayStr],
      );
      return (result.first['count'] as int?) ?? 0;
    } catch (e) {
      debugPrint('[DocumentRepository] ERROR countByTypePrefix($prefix): $e');
      return 0;
    }
  }

  /// Helper privado para eliminar archivos del filesystem
  Future<bool> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (e) {
      debugPrint('[DocumentRepository] ERROR _deleteFile($path): $e');
      return false;
    }
  }
}
