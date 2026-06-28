import 'package:escandoc/features/documents/data/repositories/document_repository.dart';

/// UseCase: Elimina varios documentos en un solo lote.
///
/// Reglas de negocio:
/// - Delega el borrado (BD + archivos) al repositorio en una sola operación.
/// - Lista vacía → no toca el repositorio, devuelve `[]`.
/// - Devuelve los ids efectivamente borrados (puede ser un subconjunto del
///   pedido ante un fallo parcial).
/// - Fail-safe: ante cualquier excepción, devuelve `[]`.
class DeleteDocuments {
  final DocumentRepository repository;

  DeleteDocuments({required this.repository});

  /// Ejecuta el caso de uso.
  /// Retorna la lista de ids que se eliminaron correctamente.
  Future<List<int>> call(List<int> ids) async {
    if (ids.isEmpty) return [];
    try {
      return await repository.deleteDocuments(ids);
    } catch (e) {
      // Fail-safe: ante error, no se reporta ningún borrado.
      return [];
    }
  }
}
