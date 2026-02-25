/// Genera el título automático de una nota a partir de su contenido.
class NoteTitle {
  NoteTitle._();

  static const _months = [
    '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  /// Retorna las primeras 5 palabras del [text], o "Nota {día} {mes}" si está vacío.
  static String generate(String text, DateTime date) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return 'Nota ${date.day} ${_months[date.month]}';
    }
    final words = trimmed.split(RegExp(r'\s+')).take(5).join(' ');
    return words;
  }
}
