import 'package:escandoc/features/documents/data/repositories/document_repository.dart';

/// UseCase: Renombra un documento
///
/// Reglas de negocio:
/// - El título no puede quedar vacío
/// - El título se guarda tal cual lo escribe el usuario (sin transformaciones)
/// - Si el documento no existe, retorna false
class RenameDocument {
  final DocumentRepository repository;

  RenameDocument({required this.repository});

  /// Retorna true si se renombró correctamente
  Future<bool> call(int id, String newTitle) async {
    if (newTitle.trim().isEmpty) return false;

    try {
      final document = await repository.getDocumentById(id);
      if (document == null) return false;

      final trimmed = newTitle.trim();
      final capitalized = trimmed[0].toUpperCase() + trimmed.substring(1);
      final renamed = document.copyWith(title: capitalized);
      await repository.updateDocument(renamed);
      return true;
    } catch (e) {
      return false;
    }
  }
}
