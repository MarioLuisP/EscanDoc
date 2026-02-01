import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

/// Página fullscreen para visualizar y copiar texto OCR
/// TextField de solo lectura con scroll y botón copiar
class OcrFullscreenPage extends StatefulWidget {
  final String? ocrText;

  const OcrFullscreenPage({
    super.key,
    required this.ocrText,
  });

  @override
  State<OcrFullscreenPage> createState() => _OcrFullscreenPageState();
}

class _OcrFullscreenPageState extends State<OcrFullscreenPage> {
  late final TextEditingController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.ocrText ?? 'ocr_empty_hint'.tr(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.ocrText != null && widget.ocrText!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'ocr_section_title'.tr(),
          style: const TextStyle(fontSize: 20),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () => Navigator.pop(context),
          tooltip: 'back_button'.tr(),
        ),
        actions: [
          if (hasText)
            // Botón copiar texto
            IconButton(
              icon: const Icon(Icons.copy, size: 24),
              onPressed: _copyText,
              tooltip: 'ocr_copy_button'.tr(),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: TextField(
            controller: _controller,
            scrollController: _scrollController,
            readOnly: true,
            maxLines: null,
            expands: true,
            style: TextStyle(
              fontSize: 18,
              color: hasText ? Colors.grey[800] : Colors.grey[500],
              fontStyle: hasText ? FontStyle.normal : FontStyle.italic,
              height: 1.5,
            ),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[400]!),
              ),
              filled: true,
              fillColor: hasText ? Colors.grey[50] : Colors.grey[100],
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ),
      // Botón grande COPIAR TEXTO en el fondo (solo si hay texto)
      bottomNavigationBar: hasText ? _buildCopyButton() : null,
    );
  }

  /// Botón grande COPIAR TEXTO
  Widget _buildCopyButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _copyText,
        icon: const Icon(Icons.copy, size: 24),
        label: Text(
          'ocr_copy_button'.tr(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  /// Copia el texto al portapapeles
  void _copyText() {
    if (widget.ocrText != null && widget.ocrText!.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: widget.ocrText!));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ocr_copied'.tr(),
            style: const TextStyle(fontSize: 16),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
