import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';

/// UseCase: Obtiene un documento específico por su ID
///
/// Reglas de negocio:
/// - Si el documento existe, lo retorna
/// - Si no existe, retorna null
/// - Si hay error de BD, retorna null (fail-safe para MVP)
class GetDocumentById {
  final DocumentRepository repository;

  GetDocumentById({required this.repository});

  /// Ejecuta el caso de uso
  /// Retorna DocumentModel si existe, null si no
  Future<DocumentModel?> call(int id) async {
    try {
      return await repository.getDocumentById(id);
    } catch (e) {
      // Fail-safe: retornar null en caso de error
      return null;
    }
  }
}
