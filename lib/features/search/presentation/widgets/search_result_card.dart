import 'package:flutter/material.dart';
import 'package:escandoc/features/search/data/models/search_result.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart' as easy;

/// Tarjeta de resultado de búsqueda
class SearchResultCard extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const SearchResultCard({
    super.key,
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tipo y fecha
              Row(
                children: [
                  // Icono según tipo
                  Icon(
                    result.type == 'document'
                        ? Icons.description
                        : Icons.note,
                    size: 20,
                    color: result.type == 'document'
                        ? Colors.blue
                        : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  // Tipo
                  Text(
                    result.type == 'document' ? 'result_type_document'.tr() : 'result_type_note'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  // Fecha
                  if (result.date != null)
                    Text(
                      DateFormat('dd/MM/yyyy').format(result.date!),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Título
              Text(
                result.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Snippet con highlight
              _buildSnippet(result.snippet),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSnippet(String snippet) {
    // Parsear snippet con tags <b></b> para resaltar
    final parts = <TextSpan>[];
    final regex = RegExp(r'<b>(.*?)</b>');
    var lastIndex = 0;

    for (final match in regex.allMatches(snippet)) {
      // Texto antes del match
      if (match.start > lastIndex) {
        parts.add(TextSpan(
          text: snippet.substring(lastIndex, match.start),
        ));
      }

      // Texto destacado
      parts.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.blue,
          backgroundColor: Color(0xFFE3F2FD),
        ),
      ));

      lastIndex = match.end;
    }

    // Texto después del último match
    if (lastIndex < snippet.length) {
      parts.add(TextSpan(
        text: snippet.substring(lastIndex),
      ));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey[700],
          height: 1.4,
        ),
        children: parts.isEmpty
            ? [TextSpan(text: snippet)]
            : parts,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}
