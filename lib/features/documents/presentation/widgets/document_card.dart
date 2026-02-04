import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' as easy;
import 'package:escandoc/features/documents/data/models/document_model.dart';

/// Card para mostrar un documento en la lista
/// Diseño accesible con thumbnail grande (80x80dp) y textos legibles
class DocumentCard extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const DocumentCard({
    super.key,
    required this.document,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Thumbnail (80x80dp)
              _buildThumbnail(),
              const SizedBox(width: 16),

              // Información del documento
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre del documento (18sp)
                    Text(
                      document.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Fecha (16sp)
                    Text(
                      _formatDate(document.createdAt),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Ícono de menú (indicador visual de long-press)
              Icon(
                Icons.more_vert,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye el thumbnail del documento
  Widget _buildThumbnail() {
    // Si existe thumbnail, mostrarlo
    if (document.thumbnailPath != null) {
      final thumbnailFile = File(document.thumbnailPath!);

      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            thumbnailFile,
            width: 80,
            height: 80,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Si falla cargar imagen, mostrar ícono
              return _buildPlaceholderIcon();
            },
          ),
        ),
      );
    }

    // Si no hay thumbnail, mostrar ícono placeholder
    return _buildPlaceholderIcon();
  }

  /// Ícono placeholder cuando no hay thumbnail
  Widget _buildPlaceholderIcon() {
    IconData icon;
    Color color;

    // Ícono según tipo de documento
    switch (document.docType) {
      case 'factura':
        icon = Icons.receipt_long;
        color = Colors.blue;
        break;
      case 'recibo':
        icon = Icons.receipt;
        color = Colors.green;
        break;
      case 'contrato':
        icon = Icons.description;
        color = Colors.orange;
        break;
      case 'médico':
        icon = Icons.medical_information;
        color = Colors.red;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.grey;
    }

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: 40,
        color: color,
      ),
    );
  }

  /// Formatea la fecha en formato localizado: "20 Ene 2026"
  String _formatDate(DateTime date) {
    final day = date.day;
    final monthKey = 'month_${_getMonthAbbreviation(date.month)}';
    final month = monthKey.tr();
    final year = date.year;

    return '$day $month $year';
  }

  /// Obtiene la abreviación del mes (para clave de traducción)
  String _getMonthAbbreviation(int month) {
    const months = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec'
    ];
    return months[month - 1];
  }
}
