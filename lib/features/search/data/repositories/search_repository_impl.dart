import 'package:escandoc/core/database/database_helper.dart';
import 'package:escandoc/features/search/data/models/search_result.dart';
import 'package:escandoc/features/search/data/repositories/search_repository.dart';

/// Implementación del repositorio de búsqueda usando FTS4
class SearchRepositoryImpl implements SearchRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<List<SearchResult>> search(String query) async {
    if (query.isEmpty) {
      return [];
    }

    final db = await _dbHelper.database;

    // Sanitizar query para FTS4 (escapar caracteres especiales)
    final sanitizedQuery = _sanitizeQuery(query);

    if (sanitizedQuery.isEmpty) {
      return [];
    }

    // Buscar en documentos usando FTS4
    final docResults = await db.rawQuery('''
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
    ''', [sanitizedQuery]);

    // Buscar en notas usando FTS4
    // document_id viene de la tabla intermedia document_notes
    final noteResults = await db.rawQuery('''
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
    ''', [sanitizedQuery]);

    // Combinar resultados
    final List<SearchResult> results = [];

    // Convertir resultados de documentos
    for (final row in docResults) {
      results.add(SearchResult(
        id: row['id'] as int,
        type: row['type'] as String,
        title: row['title'] as String,
        snippet: row['snippet'] as String,
        date: row['created_at'] != null
            ? DateTime.parse(row['created_at'] as String)
            : null,
      ));
    }

    // Convertir resultados de notas
    for (final row in noteResults) {
      results.add(SearchResult(
        id: row['id'] as int,
        type: row['type'] as String,
        title: row['title'] as String,
        snippet: row['snippet'] as String,
        date: row['created_at'] != null
            ? DateTime.parse(row['created_at'] as String)
            : null,
      ));
    }

    // Ordenar resultados combinados por fecha (más reciente primero)
    results.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });

    // Limitar a 20 resultados totales
    return results.take(20).toList();
  }

  /// Sanitiza el query para FTS4, removiendo caracteres especiales
  /// que pueden causar errores de sintaxis
  String _sanitizeQuery(String query) {
    // Remover caracteres que pueden causar problemas en FTS4
    // Mantener solo letras, números y espacios
    String sanitized = query.trim();

    // Escapar comillas dobles
    sanitized = sanitized.replaceAll('"', '""');

    // Si el query está vacío después de sanitizar, retornar vacío
    if (sanitized.isEmpty) {
      return '';
    }

    // Envolver en comillas dobles para búsqueda de frase
    // Esto permite buscar caracteres especiales como $, ., etc.
    return '"$sanitized"';
  }
}
