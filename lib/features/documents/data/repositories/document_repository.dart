import 'dart:io';
import 'package:escandoc/core/database/database_helper.dart';
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
      // En caso de error, retornar lista vacía (fail-safe para MVP)
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
      return null;
    }
  }

  /// Inserta un nuevo documento y retorna el ID generado
  Future<int> insertDocument(DocumentModel document) async {
    final db = await _dbHelper.database;
    return await db.insert('documents', document.toMap());
  }

  /// Actualiza un documento existente
  Future<int> updateDocument(DocumentModel document) async {
    final db = await _dbHelper.database;

    // Crear map sin el 'id' (PRIMARY KEY no debe actualizarse)
    final map = document.toMap();
    map.remove('id');

    return await db.update(
      'documents',
      map,
      where: 'id = ?',
      whereArgs: [document.id],
    );
  }

  /// Elimina un documento de la BD y sus archivos asociados
  /// Retorna true si se eliminó correctamente
  Future<bool> deleteDocument(int id) async {
    try {
      // 1. Obtener documento para acceder a las rutas de archivos
      final document = await getDocumentById(id);
      if (document == null) return false;

      // 2. Eliminar archivo del filesystem
      final fileDeleted = await _deleteFile(document.filePath);
      if (!fileDeleted) return false;

      // 3. Eliminar registro de BD
      final db = await _dbHelper.database;
      final rowsDeleted = await db.delete(
        'documents',
        where: 'id = ?',
        whereArgs: [id],
      );

      return rowsDeleted > 0;
    } catch (e) {
      return false;
    }
  }

  /// Actualiza el campo note_content de un documento
  Future<void> updateNote(int documentId, String? content) async {
    final db = await _dbHelper.database;
    await db.update(
      'documents',
      {'note_content': content},
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
      return false;
    }
  }
}
