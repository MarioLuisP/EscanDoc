import 'package:flutter/material.dart';

/// Paleta de colores pastel por tipo de documento.
///
/// Usar con la clave interna del clasificador (no la clave i18n):
/// 'documento', 'foto', 'folleto', 'manuscrito', 'recibo', 'factura', 'nota'
class DocumentTypeColors {
  DocumentTypeColors._();

  static const _map = <String, DocumentTypeScheme>{
    'documento':  DocumentTypeScheme(
      bg:     Color(0xFFD6E4F0),
      fg:     Color(0xFF2C5F7A),
      border: Color(0xFFADCAE0),
    ),
    'foto':       DocumentTypeScheme(
      bg:     Color(0xFFE8D6F0),
      fg:     Color(0xFF5A2C7A),
      border: Color(0xFFCFAAE0),
    ),
    'folleto':    DocumentTypeScheme(
      bg:     Color(0xFFFAE3CC),
      fg:     Color(0xFF8A4A1A),
      border: Color(0xFFE8C4A0),
    ),
    'manuscrito': DocumentTypeScheme(
      bg:     Color(0xFFD6F0E0),
      fg:     Color(0xFF1A6640),
      border: Color(0xFFA0D8B8),
    ),
    'recibo':     DocumentTypeScheme(
      bg:     Color(0xFFFAF0CC),
      fg:     Color(0xFF7A6010),
      border: Color(0xFFE0D090),
    ),
    'factura':    DocumentTypeScheme(
      bg:     Color(0xFFF0D6D6),
      fg:     Color(0xFF7A2C2C),
      border: Color(0xFFDEADAD),
    ),
    'nota':       DocumentTypeScheme(
      bg:     Color(0xFFF0EAD6),
      fg:     Color(0xFF6A5020),
      border: Color(0xFFD8C898),
    ),
  };

  static const _fallback = DocumentTypeScheme(
    bg:     Color(0xFFEEE4CC),
    fg:     Color(0xFF5A4A30),
    border: Color(0xFFBBAA88),
  );

  /// Retorna el esquema de colores para [documentType].
  /// Si el tipo es desconocido, retorna el fallback crema neutro.
  static DocumentTypeScheme of(String? documentType) =>
      _map[documentType?.toLowerCase()] ?? _fallback;
}

class DocumentTypeScheme {
  final Color bg;
  final Color fg;
  final Color border;

  const DocumentTypeScheme({
    required this.bg,
    required this.fg,
    required this.border,
  });
}
