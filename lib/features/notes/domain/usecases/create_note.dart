import 'package:escandoc/features/notes/data/models/note_model.dart';
import 'package:escandoc/features/notes/data/repositories/note_repository.dart';

/// UseCase: Crea una nota y la vincula a un documento
///
/// Reglas de negocio:
/// - El título no puede estar vacío
/// - Crea nota y vincula en transacción atómica
/// - Si el documento no existe, falla gracefully
/// - Retorna null en caso de error
class CreateNote {
  final NoteRepository repository;

  CreateNote({required this.repository});

  /// Ejecuta el caso de uso
  /// Retorna NoteModel creada con ID, o null si falla
  Future<NoteModel?> call({
    required String title,
    String? content,
    required int documentId,
  }) async {
    try {
      // Validar que el título no esté vacío
      if (title.trim().isEmpty) {
        return null;
      }

      // Crear nota con timestamp actual
      final note = NoteModel(
        title: title.trim(),
        content: content?.trim(),
        createdAt: DateTime.now(),
      );

      // Crear y vincular a documento
      return await repository.createNote(note, documentId);
    } catch (e) {
      // Fail-safe: retornar null en caso de error
      return null;
    }
  }
}
