import 'package:escandoc/features/notes/data/models/note_model.dart';
import 'package:escandoc/features/notes/data/repositories/note_repository.dart';

/// UseCase: Obtiene la nota vinculada a un documento
///
/// Reglas de negocio:
/// - Si el documento tiene nota, la retorna
/// - Si no tiene nota, retorna null
/// - Si hay error de BD, retorna null (fail-safe)
class GetNoteByDocument {
  final NoteRepository repository;

  GetNoteByDocument({required this.repository});

  /// Ejecuta el caso de uso
  /// Retorna NoteModel si existe, null si no
  Future<NoteModel?> call(int documentId) async {
    try {
      return await repository.getNoteByDocument(documentId);
    } catch (e) {
      // Fail-safe: retornar null en caso de error
      return null;
    }
  }
}
