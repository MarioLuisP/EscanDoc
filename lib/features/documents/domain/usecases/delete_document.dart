import 'package:escandoc/features/documents/data/repositories/document_repository.dart';

/// UseCase: Elimina un documento de la BD y sus archivos asociados
///
/// Reglas de negocio:
/// - Elimina archivo PDF del filesystem
/// - Elimina thumbnail si existe
/// - Elimina registro de BD (triggers automáticos eliminan de FTS5)
/// - Si el documento no existe, retorna false
/// - Si falla la eliminación de archivos, retorna false (fail-safe)
class DeleteDocument {
  final DocumentRepository repository;

  DeleteDocument({required this.repository});

  /// Ejecuta el caso de uso
  /// Retorna true si se eliminó correctamente, false si falló
  Future<bool> call(int id) async {
    try {
      return await repository.deleteDocument(id);
    } catch (e) {
      // Fail-safe: retornar false en caso de error
      return false;
    }
  }
}
