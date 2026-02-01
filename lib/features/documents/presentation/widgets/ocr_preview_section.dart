import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Sección de preview de texto OCR (30% altura)
/// Tap → abre vista completa con capacidad de copiar
class OcrPreviewSection extends StatelessWidget {
  final String? ocrText;
  final VoidCallback onTap;

  const OcrPreviewSection({
    super.key,
    required this.ocrText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = ocrText != null && ocrText!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          border: Border(
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
                  Icons.text_fields,
                  size: 20,
                  color: Colors.blue[800],
                ),
                const SizedBox(width: 8),
                Text(
                  'ocr_section_title'.tr(),
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

            // Preview de texto OCR o mensaje vacío
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  hasText ? ocrText! : 'ocr_empty_hint'.tr(),
                  style: TextStyle(
                    fontSize: 16,
                    color: hasText ? Colors.grey[800] : Colors.grey[500],
                    fontStyle: hasText ? FontStyle.normal : FontStyle.italic,
                  ),
                  maxLines: 6,
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
