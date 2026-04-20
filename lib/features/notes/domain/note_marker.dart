class NoteMarker {
  static const String _marker = '\u200B';

  static bool isDefault(String? content) {
    if (content == null || content.isEmpty) return false;
    return content.startsWith(_marker);
  }

  static String strip(String content) {
    if (!content.startsWith(_marker)) return content;
    return content.substring(_marker.length);
  }

  static String mark(String content) {
    if (content.startsWith(_marker)) return content;
    return '$_marker$content';
  }
}
