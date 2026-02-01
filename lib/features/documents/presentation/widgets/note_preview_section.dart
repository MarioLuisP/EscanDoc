import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Sección de preview de nota (20% altura)
/// Tap → abre editor de nota
class NotePreviewSection extends StatelessWidget {
  final String? noteContent;
  final VoidCallback onTap;

  const NotePreviewSection({
    super.key,
    required this.noteContent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasNote = noteContent != null && noteContent!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber[50],
          border: Border(
            top: BorderSide(color: Colors.grey[300]!, width: 1),
            bottom: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  hasNote ? Icons.note : Icons.note_add,
                  size: 20,
                  color: Colors.amber[800],
                ),
                const SizedBox(width: 8),
                Text(
                  'note_section_title'.tr(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.grey[400],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Preview de nota o mensaje vacío
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  hasNote ? noteContent! : 'note_empty_hint'.tr(),
                  style: TextStyle(
                    fontSize: 16,
                    color: hasNote ? Colors.grey[800] : Colors.grey[500],
                    fontStyle: hasNote ? FontStyle.normal : FontStyle.italic,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
