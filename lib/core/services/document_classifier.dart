import 'package:escandoc/features/image_processing/classification/domain/classification_result.dart';

/// Servicio stateless para operaciones de clasificación de documentos.
class DocumentClassifier {
  /// Detecta el tipo de documento basado en keywords en el texto OCR.
  ///
  /// Retorna: 'factura', 'recibo', 'contrato', 'médico', o 'documento' (default).
  /// Nota: método legado — el pipeline principal usa TFLite + RefineClassification.
  String detectType(String ocrText) {
    final text = ocrText.toLowerCase();

    if (text.contains('factura') || text.contains('invoice')) {
      return 'factura';
    }
    if (text.contains('recibo') || text.contains('receipt')) {
      return 'recibo';
    }
    if (text.contains('contrato') || text.contains('contract')) {
      return 'contrato';
    }
    if (text.contains('médico') ||
        text.contains('medico') ||
        text.contains('medical') ||
        text.contains('consulta') ||
        text.contains('prescription')) {
      return 'médico';
    }

    return 'documento';
  }

  /// Retorna el nombre visible del tipo en el locale dado.
  ///
  /// Delega a [DocumentType.displayName] — fuente única de verdad.
  String getTypeDisplayName(DocumentType kind, String locale) =>
      kind.displayName(locale);

  /// Genera nombre de documento: {Tipo} {N} del {día}/{mes}
  ///
  /// Ejemplos ES: "Factura 1 del 17/2", "Nota 3 del 5/11"
  /// Ejemplos EN: "Invoice 1 of 17/2", "Note 3 of 5/11"
  String generateDocumentName(
      DocumentType kind, DateTime date, String locale, int count) {
    final displayName = kind.displayName(locale);
    final connector = locale == 'en' ? 'of' : 'del';
    return '$displayName $count $connector ${date.day}/${date.month}';
  }

  /// Extrae fecha de vencimiento del texto OCR.
  ///
  /// Busca patrones: "vencimiento:", "vence:", "pagar antes de:", "due date:"
  /// Formatos: DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD
  ///
  /// Retorna null si no encuentra fecha o si la fecha es pasada.
  DateTime? extractDueDate(String ocrText) {
    final text = ocrText.toLowerCase();

    final patterns = [
      RegExp(r'(\d{2})/(\d{2})/(\d{4})'),
      RegExp(r'(\d{2})-(\d{2})-(\d{4})'),
      RegExp(r'(\d{4})-(\d{2})-(\d{2})'),
    ];

    final hasVencimientoKeyword = text.contains('vencimiento:') ||
                                   text.contains('vence:') ||
                                   text.contains('pagar antes de:') ||
                                   text.contains('due date:');

    if (!hasVencimientoKeyword) return null;

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          DateTime date;
          if (match.group(1)!.length == 4) {
            date = DateTime(
              int.parse(match.group(1)!),
              int.parse(match.group(2)!),
              int.parse(match.group(3)!),
            );
          } else {
            date = DateTime(
              int.parse(match.group(3)!),
              int.parse(match.group(2)!),
              int.parse(match.group(1)!),
            );
          }
          final today = DateTime.now();
          final todayOnly = DateTime(today.year, today.month, today.day);
          if (!date.isBefore(todayOnly)) return date;
        } catch (e) {
          continue;
        }
      }
    }

    return null;
  }
}
