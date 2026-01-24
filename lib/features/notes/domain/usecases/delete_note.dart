import 'package:escandoc/features/notes/data/repositories/note_repository.dart';

/// UseCase: Elimina una nota de la BD
///
/// Reglas de negocio:
/// - Elimina la nota de la tabla notes
/// - El CASCADE automático elimina la vinculación en document_notes
/// - Si la nota no existe, retorna false
/// - Si falla la eliminación, retorna false (fail-safe)
class DeleteNote {
  final NoteRepository repository;

  DeleteNote({required this.repository});

  /// Ejecuta el caso de uso
  /// Retorna true si se eliminó correctamente, false si falló
  Future<bool> call(int noteId) async {
    try {
      return await repository.deleteNote(noteId);
    } catch (e) {
      // Fail-safe: retornar false en caso de error
      return false;
    }
  }
}
