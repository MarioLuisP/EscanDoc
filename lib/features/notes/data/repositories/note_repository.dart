import 'package:escandoc/core/database/database_helper.dart';
import 'package:escandoc/features/notes/data/models/note_model.dart';

/// Repository para operaciones CRUD de notas en SQLite
/// Maneja la vinculación con documentos a través de la tabla document_notes
class NoteRepository {
  final DatabaseHelper _dbHelper;

  NoteRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Crea una nota y la vincula a un documento
  /// Usa transacción atómica para garantizar consistencia
  Future<NoteModel> createNote(NoteModel note, int documentId) async {
    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      // 1. Insertar nota
      final noteId = await txn.insert('notes', note.toMap());

      // 2. Vincular a documento
      await txn.insert('document_notes', {
        'document_id': documentId,
        'note_id': noteId,
      });

      // 3. Retornar nota con ID generado
      return note.copyWith(id: noteId);
    });
  }

  /// Actualiza una nota existente
  Future<NoteModel> updateNote(NoteModel note) async {
    final db = await _dbHelper.database;
    await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );

    return note;
  }

  /// Obtiene la nota vinculada a un documento
  /// Retorna null si el documento no tiene nota
  Future<NoteModel?> getNoteByDocument(int documentId) async {
    try {
      final db = await _dbHelper.database;

      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT n.*
        FROM notes n
        JOIN document_notes dn ON n.id = dn.note_id
        WHERE dn.document_id = ?
      ''', [documentId]);

      if (maps.isEmpty) return null;

      return NoteModel.fromMap(maps.first);
    } catch (e) {
      return null;
    }
  }

  /// Obtiene una nota por su ID
  Future<NoteModel?> getNoteById(int id) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'notes',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) return null;
      return NoteModel.fromMap(maps.first);
    } catch (e) {
      return null;
    }
  }

  /// Elimina una nota
  /// El CASCADE automático eliminará la vinculación en document_notes
  Future<bool> deleteNote(int noteId) async {
    try {
      final db = await _dbHelper.database;
      final rowsDeleted = await db.delete(
        'notes',
        where: 'id = ?',
        whereArgs: [noteId],
      );

      return rowsDeleted > 0;
    } catch (e) {
      return false;
    }
  }
}
