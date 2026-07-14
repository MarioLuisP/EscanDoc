import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:escandoc/core/theme/document_type_colors.dart';

/// Clave i18n del tipo de documento a partir del campo `documentType`.
/// Tipos desconocidos caen a "documento".
String documentTypeKey(String? documentType) {
  const known = {
    'documento', 'foto', 'folleto', 'manuscrito', 'recibo', 'factura', 'nota',
  };
  final type = documentType?.toLowerCase() ?? '';
  return known.contains(type) ? 'doc_type_$type' : 'doc_type_documento';
}

/// Chip de tipo de documento (Documento / Foto / Folleto…), con color por tipo.
///
/// Misma geometría que [PageNumberChip] para que la lista se lea como un
/// sistema: cada fila lleva un chip en la línea de la fecha — "Pág. N" si es
/// parte de un PDF multipágina, o el tipo con color si es individual.
class DocumentTypeChip extends StatelessWidget {
  final String? documentType;
  const DocumentTypeChip({super.key, required this.documentType});

  @override
  Widget build(BuildContext context) {
    final scheme = DocumentTypeColors.of(documentType);
    final label = documentTypeKey(documentType).tr();
    final display =
        label.isEmpty ? label : label[0].toUpperCase() + label.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.border, width: 1),
      ),
      child: Text(
        display,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: scheme.fg,
        ),
      ),
    );
  }
}
