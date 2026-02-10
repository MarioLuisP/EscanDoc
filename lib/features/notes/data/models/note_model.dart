/// Modelo de dominio para una nota
/// Mapea directamente con la tabla 'notes' en SQLite
///
/// NOTA: Las notas ya NO tienen título. Solo content (bloc de notas).
/// El título viene del documento asociado.
class NoteModel {
  final int? id;
  final String? content;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const NoteModel({
    this.id,
    this.content,
    required this.createdAt,
    this.updatedAt,
  });

  /// Crea un NoteModel desde un Map de SQLite
  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      id: map['id'] as int?,
      content: map['content'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// Convierte el NoteModel a Map para SQLite
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// CopyWith para inmutabilidad
  NoteModel copyWith({
    int? id,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteModel(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NoteModel &&
        other.id == id &&
        other.content == content &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      content,
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'NoteModel(id: $id, content: ${content?.substring(0, content!.length > 50 ? 50 : content!.length)}..., createdAt: $createdAt)';
  }
}
