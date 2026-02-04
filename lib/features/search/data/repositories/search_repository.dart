import 'package:escandoc/features/search/data/models/search_result.dart';

/// Repositorio de búsqueda
///
/// Responsable de ejecutar búsquedas FTS4 en documentos y notas,
/// combinando resultados y generando snippets.
abstract class SearchRepository {
  /// Busca en documentos y notas usando FTS4
  ///
  /// Retorna resultados combinados ordenados por fecha,
  /// limitados a 20 items, con snippets destacando el query.
  Future<List<SearchResult>> search(String query);
}
