import 'package:escandoc/features/notes/data/models/note_model.dart';
import 'package:escandoc/features/notes/data/repositories/note_repository.dart';

/// UseCase: Crea una nota y la vincula a un documento
///
/// Reglas de negocio:
/// - Las notas ya NO tienen título (solo content, como bloc de notas)
/// - Crea nota y vincula en transacción atómica
/// - Si el documento no existe, falla gracefully
/// - Retorna null en caso de error
class CreateNote {
  final NoteRepository repository;

  CreateNote({required this.repository});

  /// Ejecuta el caso de uso
  /// Retorna NoteModel creada con ID, o null si falla
  Future<NoteModel?> call({
    String? content,
    required int documentId,
  }) async {
    try {
      // Crear nota con timestamp actual (sin título)
      final note = NoteModel(
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
