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

  /// Genera nombre de documento localizado: {tipo}_{día}_{mes}_{año}
  ///
  /// Ejemplos:
  /// - ES: "factura_25_Ene_2026"
  /// - EN: "invoice_25_Jan_2026"
  String generateDocumentName(String tipo, DateTime date, String locale) {
    final day = date.day;
    final year = date.year;

    // Traducir tipo según locale
    final translatedType = _translateType(tipo, locale);

    // Obtener mes abreviado según locale
    final month = _getMonthAbbreviation(date.month, locale);

    return '${translatedType}_${day}_${month}_$year';
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
          // Fecha inválida, continuar buscando
          continue;
        }
      }
    }

    return null;
  }

  // =========================================================================
  // Métodos privados
  // =========================================================================

  /// Traduce tipo de documento según locale
  String _translateType(String tipo, String locale) {
    if (locale == 'en') {
      switch (tipo) {
        case 'factura':
          return 'invoice';
        case 'recibo':
          return 'receipt';
        case 'contrato':
          return 'contract';
        case 'médico':
          return 'medical';
        case 'documento':
          return 'document';
        default:
          return 'document';
      }
    }

    // Default: español (mantener original)
    return tipo;
  }

  /// Retorna mes abreviado según locale
  String _getMonthAbbreviation(int month, String locale) {
    if (locale == 'en') {
      const monthsEN = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return monthsEN[month - 1];
    }

    // Default: español
    const monthsES = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return monthsES[month - 1];
  }
}
