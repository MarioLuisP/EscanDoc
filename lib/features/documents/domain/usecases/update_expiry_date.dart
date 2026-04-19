import 'package:escandoc/features/documents/data/repositories/document_repository.dart';

/// UseCase: Asigna o quita la fecha de vencimiento de un documento.
///
/// Reglas de negocio:
/// - La fecha no puede estar en el pasado (se valida al día de hoy).
/// - Pasar null quita el vencimiento del documento.
/// - Si el documento no existe, retorna false.
class UpdateExpiryDate {
  final DocumentRepository repository;

  UpdateExpiryDate({required this.repository});

  /// Retorna true si se actualizó correctamente.
  ///
  /// [expiryDate] null → elimina el vencimiento.
  /// Lanza [ArgumentError] si la fecha es anterior a hoy.
  Future<bool> call(int documentId, DateTime? expiryDate) async {
    if (expiryDate != null) {
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      final expiryOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
      if (expiryOnly.isBefore(todayOnly)) {
        throw ArgumentError('La fecha de vencimiento no puede ser anterior a hoy');
      }
    }

    try {
      final document = await repository.getDocumentById(documentId);
      if (document == null) return false;

      await repository.updateExpiryDate(documentId, expiryDate);
      return true;
    } catch (e) {
      if (e is ArgumentError) rethrow;
      return false;
    }
  }
}
