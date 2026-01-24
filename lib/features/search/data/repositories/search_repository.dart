import 'package:escandoc/features/search/data/models/search_result.dart';

/// Repositorio de búsqueda
///
/// Responsable de ejecutar búsquedas FTS5 en documentos y notas,
/// combinando resultados y generando snippets.
abstract class SearchRepository {
  /// Busca en documentos y notas usando FTS5
  ///
  /// Retorna resultados combinados ordenados por relevancia (rank),
  /// limitados a 20 items, con snippets destacando el query.
  Future<List<SearchResult>> search(String query);
}
