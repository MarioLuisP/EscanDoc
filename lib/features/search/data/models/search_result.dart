/// Modelo de resultado de búsqueda
///
/// Representa un resultado individual de búsqueda que puede ser
/// un documento o una nota.
class SearchResult {
  /// ID del documento o nota
  final int id;

  /// Tipo de resultado: 'document' o 'note'
  final String type;

  /// Título del documento o nota
  final String title;

  /// Snippet del texto encontrado con query destacado usando tags <b></b>
  final String snippet;

  /// Fecha de creación para ordenamiento
  final DateTime? date;

  const SearchResult({
    required this.id,
    required this.type,
    required this.title,
    required this.snippet,
    this.date,
  });

  /// Crea una copia del resultado con algunos campos modificados
  SearchResult copyWith({
    int? id,
    String? type,
    String? title,
    String? snippet,
    DateTime? date,
  }) {
    return SearchResult(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      snippet: snippet ?? this.snippet,
      date: date ?? this.date,
    );
  }

  /// Convierte el resultado a un Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'snippet': snippet,
      'date': date?.toIso8601String(),
    };
  }

  /// Crea un SearchResult desde un Map
  factory SearchResult.fromMap(Map<String, dynamic> map) {
    return SearchResult(
      id: map['id'] as int,
      type: map['type'] as String,
      title: map['title'] as String,
      snippet: map['snippet'] as String,
      date: map['date'] != null ? DateTime.parse(map['date'] as String) : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SearchResult &&
        other.id == id &&
        other.type == type &&
        other.title == title &&
        other.snippet == snippet &&
        other.date == date;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      type,
      title,
      snippet,
      date,
    );
  }

  @override
  String toString() {
    return 'SearchResult(id: $id, type: $type, title: $title, snippet: $snippet, date: $date)';
  }
}
