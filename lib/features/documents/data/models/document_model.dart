/// Modelo de dominio para un documento escaneado
/// Mapea directamente con la tabla 'documents' en SQLite
class DocumentModel {
  final int? id;
  final String title;
  final String filePath;
  final String? documentType;
  final String? noteContent;
  final String? ocrText;
  final DateTime? extractedDate;
  final DateTime? expiryDate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const DocumentModel({
    this.id,
    required this.title,
    required this.filePath,
    this.documentType,
    this.noteContent,
    this.ocrText,
    this.extractedDate,
    this.expiryDate,
    required this.createdAt,
    this.updatedAt,
  });

  /// Crea un DocumentModel desde un Map de SQLite
  factory DocumentModel.fromMap(Map<String, dynamic> map) {
    return DocumentModel(
      id: map['id'] as int?,
      title: map['title'] as String,
      filePath: map['file_path'] as String,
      documentType: map['document_type'] as String?,
      noteContent: map['note_content'] as String?,
      ocrText: map['ocr_text'] as String?,
      extractedDate: map['extracted_date'] != null
          ? DateTime.tryParse(map['extracted_date'] as String)
          : null,
      expiryDate: map['expiry_date'] != null
          ? DateTime.tryParse(map['expiry_date'] as String)
          : null,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }

  /// Convierte el DocumentModel a Map para SQLite
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'file_path': filePath,
      'document_type': documentType,
      'note_content': noteContent,
      'ocr_text': ocrText,
      'extracted_date': extractedDate?.toIso8601String(),
      'expiry_date': expiryDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// CopyWith para inmutabilidad.
  /// Para limpiar expiryDate pasar [clearExpiryDate: true].
  DocumentModel copyWith({
    int? id,
    String? title,
    String? filePath,
    String? documentType,
    String? noteContent,
    String? ocrText,
    DateTime? extractedDate,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      documentType: documentType ?? this.documentType,
      noteContent: noteContent ?? this.noteContent,
      ocrText: ocrText ?? this.ocrText,
      extractedDate: extractedDate ?? this.extractedDate,
      expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
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
        other.documentType == documentType &&
        other.noteContent == noteContent &&
        other.ocrText == ocrText &&
        other.extractedDate == extractedDate &&
        other.expiryDate == expiryDate &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      filePath,
      documentType,
      noteContent,
      ocrText,
      extractedDate,
      expiryDate,
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'DocumentModel(id: $id, title: $title, createdAt: $createdAt)';
  }
}
