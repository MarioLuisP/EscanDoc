import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// Página fullscreen para visualizar y copiar texto OCR.
///
/// Estilo consistente con NoteEditorPage: fondo crema, header propio,
/// área de contenido con borde, barra inferior con botón degradado verde.
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
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.locale;
    final hasText = widget.ocrText != null && widget.ocrText!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Expanded(child: _buildContentArea(hasText)),
            if (hasText) _buildActionBar(),
          ],
        ),
      ),
    );
  }

  // --- Header: ← título ---

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8),
        border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 26),
            color: Colors.black87,
            onPressed: () => Navigator.pop(context),
            tooltip: 'back_button'.tr(),
          ),
          Expanded(
            child: Text(
              'ocr_section_title'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 48), // Equilibra el espacio del botón back
        ],
      ),
    );
  }

  // --- Área de contenido ---

  Widget _buildContentArea(bool hasText) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFDFAF2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDDD0B8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              offset: const Offset(0, 3),
              blurRadius: 8,
            ),
          ],
        ),
        child: hasText
            ? Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: Markdown(
                  controller: _scrollController,
                  data: widget.ocrText!,
                  selectable: true,
                  padding: const EdgeInsets.all(16),
                  styleSheet: MarkdownStyleSheet.fromTheme(
                    Theme.of(context).copyWith(
                      textTheme: Theme.of(context).textTheme.apply(
                            bodyColor: Colors.black87,
                          ),
                    ),
                  ).copyWith(
                    p: const TextStyle(
                        fontSize: 17, color: Colors.black87, height: 1.65),
                    h1: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.bold, color: Colors.black87),
                    h2: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                    h3: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                ),
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'ocr_empty_hint'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      color: Colors.grey[400],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // --- Barra inferior: [COPIAR TEXTO] ---

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8),
        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
      ),
      child: _buildCopyButton(),
    );
  }

  Widget _buildCopyButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6FBF6F), Color(0xFF2E7D32)],
        ),
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A5C1A).withValues(alpha: 0.50),
            offset: const Offset(0, 4),
            blurRadius: 8,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _copyText,
          borderRadius: BorderRadius.circular(50),
          splashColor: Colors.white24,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.copy, size: 20, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  'ocr_copy_button'.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: widget.ocrText!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ocr_copied'.tr(), style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
