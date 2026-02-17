/// Servicio stateless para clasificar documentos basado en texto OCR
/// y generar nombres localizados
class DocumentClassifier {
  /// Detecta el tipo de documento basado en keywords en el texto OCR
  ///
  /// Retorna: 'factura', 'recibo', 'contrato', 'médico', o 'documento' (default)
  String detectType(String ocrText) {
    final text = ocrText.toLowerCase();

    // Orden de prioridad en detección
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
  /// Usado para:
  /// - Generar el prefijo del título del documento
  /// - Contar documentos del mismo tipo en BD (countByTypePrefix)
  ///
  /// Ejemplos ES: 'factura' → 'Factura', 'manuscrito' → 'Nota'
  /// Ejemplos EN: 'factura' → 'Invoice', 'manuscrito' → 'Note'
  String getTypeDisplayName(String tipo, String locale) {
    if (locale == 'en') {
      switch (tipo) {
        case 'factura':    return 'Invoice';
        case 'recibo':     return 'Receipt';
        case 'contrato':   return 'Contract';
        case 'médico':     return 'Medical';
        case 'manuscrito': return 'Note';
        case 'folleto':    return 'Brochure';
        case 'foto':       return 'Photo';
        default:           return 'Document';
      }
    }

    // Español (default)
    switch (tipo) {
      case 'factura':    return 'Factura';
      case 'recibo':     return 'Recibo';
      case 'contrato':   return 'Contrato';
      case 'médico':     return 'Médico';
      case 'manuscrito': return 'Nota';
      case 'folleto':    return 'Folleto';
      case 'foto':       return 'Foto';
      default:           return 'Documento';
    }
  }

  /// Genera nombre de documento: {Tipo} {N} del {día}/{mes}
  ///
  /// Ejemplos ES: "Factura 1 del 17/2", "Nota 3 del 5/11"
  /// Ejemplos EN: "Invoice 1 of 17/2", "Note 3 of 5/11"
  ///
  /// [count]: número secuencial del tipo en ese día (obtenido de BD)
  String generateDocumentName(
      String tipo, DateTime date, String locale, int count) {
    final displayName = getTypeDisplayName(tipo, locale);
    final connector = locale == 'en' ? 'of' : 'del';
    return '$displayName $count $connector ${date.day}/${date.month}';
  }

  /// Extrae fecha de vencimiento del texto OCR
  ///
  /// Busca patrones: "vencimiento:", "vence:", "pagar antes de:", "due date:"
  /// Formatos: DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD
  ///
  /// Retorna null si no encuentra fecha o si la fecha es pasada
  DateTime? extractDueDate(String ocrText) {
    final text = ocrText.toLowerCase();

    // Patrones de fecha
    final patterns = [
      // DD/MM/YYYY
      RegExp(r'(\d{2})/(\d{2})/(\d{4})'),
      // DD-MM-YYYY
      RegExp(r'(\d{2})-(\d{2})-(\d{4})'),
      // YYYY-MM-DD
      RegExp(r'(\d{4})-(\d{2})-(\d{2})'),
    ];

    // Buscar keywords de vencimiento
    final hasVencimientoKeyword = text.contains('vencimiento:') ||
                                   text.contains('vence:') ||
                                   text.contains('pagar antes de:') ||
                                   text.contains('due date:');

    if (!hasVencimientoKeyword) {
      return null;
    }

    // Intentar extraer fecha
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          DateTime date;

          // YYYY-MM-DD
          if (match.group(1)!.length == 4) {
            final year = int.parse(match.group(1)!);
            final month = int.parse(match.group(2)!);
            final day = int.parse(match.group(3)!);
            date = DateTime(year, month, day);
          }
          // DD/MM/YYYY o DD-MM-YYYY
          else {
            final day = int.parse(match.group(1)!);
            final month = int.parse(match.group(2)!);
            final year = int.parse(match.group(3)!);
            date = DateTime(year, month, day);
          }

          // Solo retornar si es fecha futura
          if (date.isAfter(DateTime.now())) {
            return date;
          }
        } catch (e) {
          continue;
        }
      }
    }

    return null;
  }
}
