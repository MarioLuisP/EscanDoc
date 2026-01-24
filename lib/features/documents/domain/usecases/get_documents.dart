import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';

/// UseCase: Obtiene todos los documentos ordenados por fecha
///
/// Reglas de negocio:
/// - Retorna lista ordenada por created_at DESC (más reciente primero)
/// - Si no hay documentos, retorna lista vacía
/// - Si hay error de BD, retorna lista vacía (fail-safe para MVP)
class GetDocuments {
  final DocumentRepository repository;

  GetDocuments({required this.repository});

  /// Ejecuta el caso de uso
  /// Retorna lista de DocumentModel ordenada por fecha descendente
  Future<List<DocumentModel>> call() async {
    try {
      return await repository.getAllDocuments();
    } catch (e) {
      // Fail-safe: retornar lista vacía en caso de error
      return [];
    }
  }
}
