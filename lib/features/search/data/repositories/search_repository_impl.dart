import 'package:escandoc/core/database/database_helper.dart';
import 'package:escandoc/features/search/data/models/search_result.dart';
import 'package:escandoc/features/search/data/repositories/search_repository.dart';

/// Implementación del repositorio de búsqueda.
///
/// Estrategia en dos pasos:
/// 1. FTS4 prefix search  → "nota*" matchea nota, notas, notación, etc.
/// 2. LIKE fallback        → si FTS no da resultados, búsqueda parcial en título
///
/// El query se normaliza antes de buscar: minúsculas + tildes eliminadas.
class SearchRepositoryImpl implements SearchRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<List<SearchResult>> search(String query) async {
    if (query.isEmpty) return [];

    final db = await _dbHelper.database;
    final normalized = _normalizeText(query.trim());
    if (normalized.isEmpty) return [];

    final ftsQuery = _buildFtsQuery(normalized);

    List<Map<String, Object?>> docResults = [];
    List<Map<String, Object?>> noteResults = [];

    // --- Paso 1: FTS prefix search ---
    try {
      docResults = await db.rawQuery('''
        SELECT
          d.id,
          d.id as document_id,
          d.title,
          'document' as type,
          snippet(documents_fts, 1, '<b>', '</b>', '...', 32) AS snippet,
          d.created_at
        FROM documents d
        JOIN documents_fts ON documents_fts.docid = d.id
        WHERE documents_fts MATCH ?
        LIMIT 20
      ''', [ftsQuery]);

      noteResults = await db.rawQuery('''
        SELECT
          n.id,
          dn.document_id,
          SUBSTR(n.content, 1, 50) as title,
          'note' as type,
          snippet(notes_fts, 0, '<b>', '</b>', '...', 32) AS snippet,
          n.created_at
        FROM notes n
        JOIN notes_fts ON notes_fts.docid = n.id
        JOIN document_notes dn ON dn.note_id = n.id
        WHERE notes_fts MATCH ?
        LIMIT 20
      ''', [ftsQuery]);
    } catch (_) {
      // FTS puede fallar con queries especiales — cae al LIKE
    }

    // --- Paso 2: LIKE fallback si FTS no encontró nada ---
    if (docResults.isEmpty && noteResults.isEmpty) {
      final likePattern = '%$normalized%';

      docResults = await db.rawQuery('''
        SELECT
          d.id,
          d.id as document_id,
          d.title,
          'document' as type,
          d.title AS snippet,
          d.created_at
        FROM documents d
        WHERE LOWER(d.title) LIKE ?
        LIMIT 20
      ''', [likePattern]);

      noteResults = await db.rawQuery('''
        SELECT
          n.id,
          dn.document_id,
          SUBSTR(n.content, 1, 50) as title,
          'note' as type,
          SUBSTR(n.content, 1, 100) AS snippet,
          n.created_at
        FROM notes n
        JOIN document_notes dn ON dn.note_id = n.id
        WHERE LOWER(n.content) LIKE ?
        LIMIT 20
      ''', [likePattern]);
    }

    // --- Combinar y deduplicar ---
    final List<SearchResult> results = [];
    final seenIds = <String>{};

    for (final row in docResults) {
      final key = 'doc_${row['id']}';
      if (seenIds.add(key)) {
        results.add(SearchResult(
          id: row['id'] as int,
          documentId: row['document_id'] as int,
          type: row['type'] as String,
          title: row['title'] as String,
          snippet: (row['snippet'] as String?) ?? '',
          date: row['created_at'] != null
              ? DateTime.parse(row['created_at'] as String)
              : null,
        ));
      }
    }

    for (final row in noteResults) {
      final key = 'note_${row['id']}';
      if (seenIds.add(key)) {
        results.add(SearchResult(
          id: row['id'] as int,
          documentId: row['document_id'] as int,
          type: row['type'] as String,
          title: row['title'] as String,
          snippet: (row['snippet'] as String?) ?? '',
          date: row['created_at'] != null
              ? DateTime.parse(row['created_at'] as String)
              : null,
        ));
      }
    }

    results.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });

    return results.take(20).toList();
  }

  /// Construye query FTS4 con prefijos por palabra.
  /// "nota reun" → "nota* reun*"  (cada término matchea prefijos)
  static String _buildFtsQuery(String normalized) {
    return normalized
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '$w*')
        .join(' ');
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
