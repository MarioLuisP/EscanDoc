import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:escandoc/features/documents/presentation/providers/documents_provider.dart';
import 'package:escandoc/features/documents/presentation/widgets/delete_confirmation_dialog.dart';
import 'package:escandoc/features/documents/presentation/pages/photo_fullscreen_page.dart';
import 'package:escandoc/features/documents/presentation/pages/ocr_fullscreen_page.dart';

/// Detalle de documento — fondo crema, imagen completa, cards de notas y OCR.
class DocumentDetailPage extends StatefulWidget {
  const DocumentDetailPage({super.key});

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final documentId = ModalRoute.of(context)?.settings.arguments as int?;
      if (documentId != null) {
        context.read<DocumentsProvider>().selectDocument(documentId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    context.locale; // Registra dependencia en EasyLocalization → rebuild al cambiar idioma
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Consumer<DocumentsProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.selectedDocument == null) {
              return Center(
                child: Text(
                  provider.errorMessage ?? 'error_loading'.tr(),
                  style: const TextStyle(fontSize: 18),
                ),
              );
            }

            final document = provider.selectedDocument!;

            return Column(
              children: [
                _buildHeader(context, provider, document.title),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Imagen del documento
                        _buildImageCard(document.filePath),
                        const SizedBox(height: 14),

                        // Card Notas
                        _buildNotesCard(
                          context,
                          document.noteContent,
                          document.id!,
                          document.title,
                        ),
                        const SizedBox(height: 14),

                        // Card Vencimiento
                        _buildExpiryCard(context, provider, document),
                        const SizedBox(height: 14),

                        // Card Texto Extraído (oculta para notas)
                        if (document.documentType != 'nota')
                          _buildOcrCard(context, document.ocrText),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- Header: ← título ✏️ 🗑️ ---

  Widget _buildHeader(
      BuildContext context, DocumentsProvider provider, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8),
        border:
            Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
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
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 24),
            color: const Color(0xFF388E3C),
            onPressed: () => _showRenameDialog(context, provider),
            tooltip: 'rename_button'.tr(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 24),
            color: Colors.red[400],
            onPressed: () => _showDeleteDialog(context, provider),
            tooltip: 'delete_button'.tr(),
          ),
        ],
      ),
    );
  }

  // --- Imagen completa del documento ---

  Widget _buildImageCard(String filePath) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoFullscreenPage(filePath: filePath),
        ),
      ),
      child: Container(
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              offset: const Offset(0, 4),
              blurRadius: 10,
              spreadRadius: -2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            File(filePath),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image,
                  size: 64, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }

  // --- Card Notas ---

  Widget _buildNotesCard(
      BuildContext context, String? noteContent, int documentId, String documentTitle) {
    final hasNote = noteContent != null && noteContent.isNotEmpty;

    return _SectionCard(
      onTap: () => _openNoteEditor(documentId, documentTitle, noteContent),
      icon: Icons.sticky_note_2_outlined,
      iconColor: const Color(0xFFF9A825),
      title: 'note_section_title'.tr(),
      child: Text(
        hasNote ? noteContent : 'note_empty_hint'.tr(),
        style: TextStyle(
          fontSize: 15,
          color: hasNote ? Colors.black87 : Colors.grey[500],
          fontStyle: hasNote ? FontStyle.normal : FontStyle.italic,
        ),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // --- Card Texto Extraído ---

  Widget _buildOcrCard(BuildContext context, String? ocrText) {
    final hasText = ocrText != null && ocrText.isNotEmpty;

    return _SectionCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OcrFullscreenPage(ocrText: ocrText),
        ),
      ),
      icon: Icons.text_snippet_outlined,
      iconColor: const Color(0xFF388E3C),
      title: 'ocr_section_title'.tr(),
      child: hasText
          ? MarkdownBody(
              data: ocrText,
              styleSheet:
                  MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: TextStyle(fontSize: 14, color: Colors.grey[800]),
                h1: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
                h2: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
                h3: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
            )
          : Text(
              'ocr_empty_hint'.tr(),
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
    );
  }

  // --- Card Vencimiento ---

  Widget _buildExpiryCard(BuildContext context, DocumentsProvider provider, dynamic document) {
    final expiry = document.expiryDate as DateTime?;
    final hasExpiry = expiry != null;

    String subtitle;
    Color subtitleColor = Colors.black87;
    if (!hasExpiry) {
      subtitle = 'expiry_none'.tr();
      subtitleColor = Colors.grey[500]!;
    } else {
      final daysLeft = expiry.difference(DateTime.now()).inDays;
      if (daysLeft < 0) {
        subtitle = 'expiry_overdue'.tr(namedArgs: {'days': '${-daysLeft}'});
        subtitleColor = Colors.red[700]!;
      } else if (daysLeft == 0) {
        subtitle = 'expiry_today'.tr();
        subtitleColor = Colors.red[700]!;
      } else if (daysLeft == 1) {
        subtitle = 'expiry_tomorrow'.tr();
        subtitleColor = Colors.orange[700]!;
      } else {
        subtitle = 'expiry_in_days'.tr(namedArgs: {'days': '$daysLeft'});
        subtitleColor = daysLeft <= 30 ? Colors.orange[700]! : const Color(0xFF388E3C);
      }
    }

    return _SectionCard(
      onTap: () => _showExpiryOptions(context, provider, document),
      icon: Icons.calendar_month_outlined,
      iconColor: const Color(0xFF1976D2),
      title: 'expiry_section_title'.tr(),
      child: Text(
        subtitle,
        style: TextStyle(
          fontSize: 15,
          color: subtitleColor,
          fontStyle: hasExpiry ? FontStyle.normal : FontStyle.italic,
          fontWeight: hasExpiry ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  void _showExpiryOptions(BuildContext context, DocumentsProvider provider, dynamic document) async {
    final expiry = document.expiryDate as DateTime?;
    final id = document.id as int;

    if (expiry == null) {
      // Sin vencimiento: abrir DatePicker directamente
      await _pickExpiryDate(context, provider, id, null);
    } else {
      // Con vencimiento: mostrar opciones
      await showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFFFDFAF4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              ListTile(
                leading: const Icon(Icons.edit_calendar, color: Color(0xFF388E3C)),
                title: Text('expiry_change'.tr(), style: const TextStyle(fontSize: 17)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickExpiryDate(context, provider, id, expiry);
                },
              ),
              ListTile(
                leading: Icon(Icons.cancel_outlined, color: Colors.red[400]),
                title: Text('expiry_remove'.tr(), style: const TextStyle(fontSize: 17)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await provider.updateExpiryDate(id, null);
                },
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _pickExpiryDate(BuildContext context, DocumentsProvider provider, int id, DateTime? initial) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2040),
      locale: context.locale,
      helpText: 'expiry_set'.tr(),
      confirmText: 'save_button'.tr(),
      cancelText: 'cancel_button'.tr(),
    );
    if (picked == null || !mounted) return;
    await provider.updateExpiryDate(id, picked);
  }

  // --- Lógica ---

  void _openNoteEditor(int documentId, String documentTitle, String? noteContent) async {
    final hasNote = noteContent != null && noteContent.isNotEmpty;
    final provider = context.read<DocumentsProvider>();
    final result = await Navigator.pushNamed(
      context,
      '/note/edit',
      arguments: {
        'documentId': documentId,
        'isEditing': hasNote,
        'documentTitle': documentTitle,
        'initialContent': noteContent ?? '',
      },
    );
    if (result != true || !mounted) return;
    provider.selectDocument(documentId);
  }

  void _showRenameDialog(
      BuildContext context, DocumentsProvider provider) async {
    final document = provider.selectedDocument;
    if (document == null) return;

    final controller = TextEditingController(text: document.title);
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('rename_dialog_title'.tr(),
            style: const TextStyle(fontSize: 20)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(hintText: 'rename_hint'.tr()),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'rename_empty_error'.tr()
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel_button'.tr(),
                style: const TextStyle(fontSize: 16)),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text('rename_button'.tr(),
                style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      await provider.renameDocument(document.id!, controller.text);
    }
    controller.dispose();
  }

  void _showDeleteDialog(
      BuildContext context, DocumentsProvider provider) async {
    final documentId = provider.selectedDocument?.id;
    if (documentId == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final confirmed = await DeleteConfirmationDialog.show(context);
    if (confirmed != true) return;
    if (!mounted) return;
    final success = await provider.deleteDocument(documentId);
    if (!success) return;
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text('document_deleted'.tr(),
          style: const TextStyle(fontSize: 16)),
      duration: const Duration(seconds: 3),
    ));
    navigator.pop();
  }
}

// ---------------------------------------------------------------------------
// Widget reutilizable para las secciones (Notas, OCR)
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.onTap,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            offset: const Offset(0, 3),
            blurRadius: 8,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header de la sección
                Row(
                  children: [
                    Icon(icon, size: 22, color: iconColor),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right,
                        size: 22, color: Colors.grey[400]),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFEEE4CC)),
                const SizedBox(height: 10),
                // Contenido
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
