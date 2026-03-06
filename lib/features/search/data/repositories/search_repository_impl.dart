import 'package:escandoc/core/database/database_helper.dart';
import 'package:escandoc/core/utils/text_normalizer.dart';
import 'package:escandoc/features/search/data/models/search_result.dart';
import 'package:escandoc/features/search/data/repositories/search_repository.dart';

/// Implementación del repositorio de búsqueda.
///
/// Estrategia: LIKE sobre columnas shadow pre-normalizadas (title_search, note_search).
/// Cero REPLACE() en SQL — la normalización se hace en Dart al escribir.
class SearchRepositoryImpl implements SearchRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<List<SearchResult>> search(String query) async {
    if (query.isEmpty) return [];

    final db = await _dbHelper.database;
    final normalized = TextNormalizer.normalize(query.trim());
    if (normalized.isEmpty) return [];

    final likePattern = '%$normalized%';

    final rows = await db.rawQuery('''
      SELECT
        d.id,
        d.title,
        d.note_content,
        CASE
          WHEN d.title_search LIKE ? THEN 'document'
          ELSE 'note'
        END as type,
        d.created_at
      FROM documents d
      WHERE d.title_search LIKE ?
         OR d.note_search  LIKE ?
      ORDER BY d.created_at DESC
      LIMIT 20
    ''', [likePattern, likePattern, likePattern]);

    final List<SearchResult> results = [];

    for (final row in rows) {
      final id = row['id'] as int;
      final type = row['type'] as String;
      final title = row['title'] as String;
      final noteContent = row['note_content'] as String?;

      final snippet = type == 'note' && noteContent != null
          ? noteContent.substring(0, noteContent.length.clamp(0, 100))
          : title;

      results.add(SearchResult(
        id: id,
        documentId: id,
        type: type,
        title: title,
        snippet: snippet,
        date: row['created_at'] != null
            ? DateTime.parse(row['created_at'] as String)
            : null,
      ));
    }

    return results;
  }
}
