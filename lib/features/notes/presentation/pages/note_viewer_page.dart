import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:escandoc/features/notes/domain/note_marker.dart';

class NoteViewerPage extends StatelessWidget {
  final int documentId;
  final String documentTitle;
  final String content;

  const NoteViewerPage({
    super.key,
    required this.documentId,
    required this.documentTitle,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    EasyLocalization.of(context)?.locale;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Expanded(child: _buildContentArea(context)),
            _buildActionBar(context),
          ],
        ),
      ),
    );
  }

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
              documentTitle,
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
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildContentArea(BuildContext context) {
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
        child: SelectionArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildText(context),
          ),
        ),
      ),
    );
  }

  Widget _buildText(BuildContext context) {
    final linked = _autoLinkUrls(content);
    final spans = _buildSpans(context, linked);
    // Text.rich (no RichText) para que participe del SelectionArea de arriba y
    // se pueda seleccionar/copiar una parte del texto — igual que el OCR.
    return Text.rich(TextSpan(children: spans));
  }

  Widget _buildActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8),
        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildCopyButton(context)),
          const SizedBox(width: 12),
          Expanded(child: _buildEditButton(context)),
        ],
      ),
    );
  }

  Widget _buildCopyButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFDFAF4), Color(0xFFE0D4BC)],
        ),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: const Color(0xFFBBAA88), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9A8060).withValues(alpha: 0.45),
            offset: const Offset(0, 4),
            blurRadius: 7,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: content));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('ocr_copied'.tr(),
                  style: const TextStyle(fontSize: 16)),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ));
          },
          borderRadius: BorderRadius.circular(50),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.copy, size: 20, color: Color(0xFF5A4A30)),
                const SizedBox(width: 8),
                Text('ocr_copy_button'.tr(),
                    style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF5A4A30),
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditButton(BuildContext context) {
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
          onTap: () async {
            final result = await Navigator.pushNamed(
              context,
              '/note/edit',
              arguments: {
                'documentId': documentId,
                'isEditing': true,
                'isNewNote': false,
                'documentTitle': documentTitle,
                'initialContent': content,
              },
            );
            if (result == true && context.mounted) {
              Navigator.pop(context);
            }
          },
          borderRadius: BorderRadius.circular(50),
          splashColor: Colors.white24,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.edit, size: 20, color: Colors.white),
                const SizedBox(width: 8),
                Text('note_edit_button'.tr(),
                    style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(String raw) async {
    final withScheme = raw.startsWith('http') ? raw : 'https://$raw';
    final uri = Uri.tryParse(withScheme);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static String _autoLinkUrls(String text) {
    return text.replaceAllMapped(
      RegExp(
        r'(?<!\()(?<!\])\b(https?://[^\s\)\]<>]+|www\.[a-zA-Z0-9\-]+\.[^\s\)\]<>]+)',
        caseSensitive: false,
      ),
      (m) {
        final url = m.group(0)!;
        final href = url.startsWith('http') ? url : 'https://$url';
        return '\x00$url\x01$href\x02';
      },
    );
  }

  List<InlineSpan> _buildSpans(BuildContext context, String linked) {
    final spans = <InlineSpan>[];
    final parts = linked.split(RegExp(r'\x00'));
    for (final part in parts) {
      final linkEnd = part.indexOf('\x02');
      if (linkEnd < 0) {
        spans.add(TextSpan(
          text: part,
          style: const TextStyle(
              fontSize: 17, color: Colors.black87, height: 1.65),
        ));
      } else {
        final sep = part.indexOf('\x01');
        final label = part.substring(0, sep);
        final href = part.substring(sep + 1, linkEnd);
        final after = part.substring(linkEnd + 1);
        spans.add(TextSpan(
          text: label,
          style: const TextStyle(
              fontSize: 17,
              color: Colors.blue,
              decoration: TextDecoration.underline,
              height: 1.65),
          recognizer: TapGestureRecognizer()..onTap = () => _openUrl(href),
        ));
        if (after.isNotEmpty) {
          spans.add(TextSpan(
            text: after,
            style: const TextStyle(
                fontSize: 17, color: Colors.black87, height: 1.65),
          ));
        }
      }
    }
    return spans;
  }
}
