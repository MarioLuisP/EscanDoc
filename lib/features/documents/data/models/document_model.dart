/// Modelo de dominio para un documento escaneado
/// Mapea directamente con la tabla 'documents' en SQLite
class DocumentModel {
  final int? id;
  final String title;
  final String filePath;
  final String? ocrText;
  final DateTime? extractedDate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const DocumentModel({
    this.id,
    required this.title,
    required this.filePath,
    this.ocrText,
    this.extractedDate,
    required this.createdAt,
    this.updatedAt,
  });

  /// Crea un DocumentModel desde un Map de SQLite
  factory DocumentModel.fromMap(Map<String, dynamic> map) {
    return DocumentModel(
      id: map['id'] as int?,
      title: map['title'] as String,
      filePath: map['file_path'] as String,
      ocrText: map['ocr_text'] as String?,
      extractedDate: map['extracted_date'] != null
          ? DateTime.parse(map['extracted_date'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// Convierte el DocumentModel a Map para SQLite
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'file_path': filePath,
      'ocr_text': ocrText,
      'extracted_date': extractedDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// CopyWith para inmutabilidad
  DocumentModel copyWith({
    int? id,
    String? title,
    String? filePath,
    String? ocrText,
    DateTime? extractedDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      ocrText: ocrText ?? this.ocrText,
      extractedDate: extractedDate ?? this.extractedDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DocumentModel &&
        other.id == id &&
        other.title == title &&
        other.filePath == filePath &&
        other.ocrText == ocrText &&
        other.extractedDate == extractedDate &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      filePath,
      ocrText,
      extractedDate,
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'DocumentModel(id: $id, title: $title, createdAt: $createdAt)';
  }
}
