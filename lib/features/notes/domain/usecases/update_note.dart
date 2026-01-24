import 'package:escandoc/features/notes/data/models/note_model.dart';
import 'package:escandoc/features/notes/data/repositories/note_repository.dart';

/// UseCase: Actualiza una nota existente
///
/// Reglas de negocio:
/// - La nota debe existir (tener ID)
/// - Si falla la actualización, retorna null
class UpdateNote {
  final NoteRepository repository;

  UpdateNote({required this.repository});

  /// Ejecuta el caso de uso
  /// Retorna NoteModel actualizada, o null si falla
  Future<NoteModel?> call({
    required int noteId,
    required String title,
    String? content,
  }) async {
    try {
      // Crear nota actualizada con nuevo timestamp
      final updatedNote = NoteModel(
        id: noteId,
        title: title.trim(),
        content: content?.trim(),
        createdAt: DateTime.now(), // Se mantiene el original en BD
        updatedAt: DateTime.now(),
      );

      // Actualizar en BD
      return await repository.updateNote(updatedNote);
    } catch (e) {
      // Fail-safe: retornar null en caso de error
      return null;
    }
  }
}
