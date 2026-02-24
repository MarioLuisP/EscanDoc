import 'package:escandoc/core/database/database_helper.dart';
import 'package:escandoc/features/search/data/models/search_result.dart';
import 'package:escandoc/features/search/data/repositories/search_repository.dart';

/// Implementación del repositorio de búsqueda.
///
/// Estrategia: LIKE normalizado sobre tabla documents.
/// Busca en título y note_content. Sin JOINs, sin FTS.
///
/// El query se normaliza antes de buscar: minúsculas + tildes eliminadas.
/// Las columnas también se normalizan en SQL con REPLACE() anidado,
/// para que "nóta" matchee "nota", "NOTA", "Nota", etc.
class SearchRepositoryImpl implements SearchRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<List<SearchResult>> search(String query) async {
    if (query.isEmpty) return [];

    final db = await _dbHelper.database;
    final normalized = _normalizeText(query.trim());
    if (normalized.isEmpty) return [];

    final likePattern = '%$normalized%';
    final titleExpr = _normalizeSqlExpr('d.title');
    final noteExpr = _normalizeSqlExpr('d.note_content');

    final rows = await db.rawQuery('''
      SELECT
        d.id,
        d.title,
        d.note_content,
        CASE
          WHEN $titleExpr LIKE ? THEN 'document'
          ELSE 'note'
        END as type,
        d.created_at
      FROM documents d
      WHERE $titleExpr LIKE ?
         OR $noteExpr LIKE ?
      ORDER BY d.created_at DESC
      LIMIT 20
    ''', [likePattern, likePattern, likePattern]);

    final List<SearchResult> results = [];

    for (final row in rows) {
      final id = row['id'] as int;
      final type = row['type'] as String;
      final title = row['title'] as String;
      final noteContent = row['note_content'] as String?;

      // Snippet: para 'note' mostrar los primeros 100 chars de la nota
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

  /// Genera expresión SQL que normaliza una columna (minúsculas + sin tildes).
  /// Permite comparar con LIKE independientemente de acentos y mayúsculas.
  static String _normalizeSqlExpr(String col) {
    var expr = 'LOWER($col)';
    const replacements = [
      ['á', 'a'], ['à', 'a'], ['â', 'a'], ['ã', 'a'], ['ä', 'a'],
      ['é', 'e'], ['è', 'e'], ['ê', 'e'], ['ë', 'e'],
      ['í', 'i'], ['ì', 'i'], ['î', 'i'], ['ï', 'i'],
      ['ó', 'o'], ['ò', 'o'], ['ô', 'o'], ['õ', 'o'], ['ö', 'o'],
      ['ú', 'u'], ['ù', 'u'], ['û', 'u'], ['ü', 'u'],
      ['ñ', 'n'], ['ç', 'c'],
    ];
    for (final r in replacements) {
      expr = "REPLACE($expr, '${r[0]}', '${r[1]}')";
    }
    return expr;
  }

  /// Normaliza texto para búsqueda: minúsculas + tildes → base.
  /// "Nótas" → "notas", "REUNIÓN" → "reunion"
  static String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp('[áàâãäå]'), 'a')
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[íìîï]'), 'i')
        .replaceAll(RegExp('[óòôõö]'), 'o')
        .replaceAll(RegExp('[úùûü]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('ç', 'c');
  }
}
