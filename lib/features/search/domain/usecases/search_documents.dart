import 'package:escandoc/features/search/data/models/search_result.dart';
import 'package:escandoc/features/search/data/repositories/search_repository.dart';

/// UseCase para buscar documentos y notas
///
/// Orquesta la búsqueda utilizando FTS5 en documentos y notas,
/// retornando resultados combinados ordenados por relevancia.
class SearchDocuments {
  final SearchRepository repository;

  const SearchDocuments({required this.repository});

  /// Ejecuta la búsqueda con el query especificado
  ///
  /// Busca en:
  /// - Nombres de documentos
  /// - Texto OCR de documentos
  /// - Contenido de notas vinculadas
  ///
  /// Retorna lista de resultados ordenados por relevancia (rank),
  /// limitados a 20 items, con snippets destacando el query.
  Future<List<SearchResult>> execute(String query) async {
    return await repository.search(query);
  }
}
