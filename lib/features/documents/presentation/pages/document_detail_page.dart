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
  bool _noteExpanded = true;
  bool _expiryExpanded = false;
  bool _ocrExpanded = false;
  int? _lastInitializedDocId; // para inicializar _expiryExpanded solo una vez por doc

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

            // Inicializar _expiryExpanded la primera vez que llega este documento
            if (_lastInitializedDocId != document.id) {
              _lastInitializedDocId = document.id;
              _expiryExpanded = document.expiryDate != null;
            }

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
                        const SizedBox(height: 8),
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
      isExpanded: _noteExpanded,
      onToggle: () => setState(() => _noteExpanded = !_noteExpanded),
      onContentTap: () => _openNoteEditor(documentId, documentTitle, noteContent),
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
      isExpanded: _ocrExpanded,
      onToggle: () => setState(() => _ocrExpanded = !_ocrExpanded),
      onContentTap: () => Navigator.push(
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
      isExpanded: _expiryExpanded,
      onToggle: () => setState(() => _expiryExpanded = !_expiryExpanded),
      onContentTap: () => Navigator.pushNamed(
        context,
        '/calendar',
        arguments: {
          'documentId': document.id as int,
          'documentTitle': document.title as String,
          'currentExpiryDate': expiry,
        },
      ),
      icon: Icons.calendar_month_outlined,
      iconColor: const Color(0xFF1976D2),
      title: 'expiry_section_title'.tr(),
      child: Row(
        children: [
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 15,
              color: subtitleColor,
              fontStyle: hasExpiry ? FontStyle.normal : FontStyle.italic,
              fontWeight: hasExpiry ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (hasExpiry) ...[
            const Spacer(),
            GestureDetector(
              onTap: () => _confirmDeleteExpiry(context, provider, document.id as int),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFF0F0), Color(0xFFFFCDD2)],
                  ),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: const Color(0xFFEF9A9A), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red[200]!.withValues(alpha: 0.50),
                      offset: const Offset(0, 3),
                      blurRadius: 6,
                      spreadRadius: -1,
                    ),
                  ],
                ),
                child: const Text(
                  'Borrar',
                  style: TextStyle(
                    color: Color(0xFFC62828),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDeleteExpiry(BuildContext context, DocumentsProvider provider, int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFFFDFAF4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '¿Eliminar vencimiento?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _StyledButton(
                      label: 'cancel_button'.tr(),
                      onTap: () => Navigator.pop(ctx, false),
                      gradientColors: const [Color(0xFFFDFAF4), Color(0xFFE0D4BC)],
                      textColor: const Color(0xFF5A4A30),
                      shadowColor: const Color(0xFF9A8060),
                      border: Border.all(color: const Color(0xFFBBAA88), width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StyledButton(
                      label: 'Eliminar',
                      onTap: () => Navigator.pop(ctx, true),
                      gradientColors: [Colors.red[400]!, Colors.red[800]!],
                      textColor: Colors.white,
                      shadowColor: Colors.red[900]!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) {
      await provider.updateExpiryDate(id, null);
    }
  }

  Future<void> _pickExpiryDate(BuildContext context, DocumentsProvider provider, int id, DateTime? initial) async {
    final today = DateTime.now();
    // Si la fecha guardada es pasada, el DatePicker arranca desde hoy + 30
    final safeInitial = (initial != null && initial.isAfter(today))
        ? initial
        : today.add(const Duration(days: 30));

    final picked = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: today,
      lastDate: DateTime(2040),
      locale: context.locale,
      helpText: 'expiry_set'.tr(),
      confirmText: 'save_button'.tr(),
      cancelText: 'cancel_button'.tr(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          textButtonTheme: TextButtonThemeData(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.pressed)
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF388E3C)),
              foregroundColor: WidgetStateProperty.all(Colors.white),
              elevation: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.pressed) ? 1.0 : 4.0),
              shadowColor: WidgetStateProperty.all(const Color(0xFF1A5C1A)),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              textStyle: WidgetStateProperty.all(
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        child: child!,
      ),
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

/// Card de sección colapsable.
///
/// Modo colapsable: [isExpanded] + [onToggle] + [onContentTap].
///   El header (icono + título + chevron) hace toggle.
///   El contenido, cuando está expandido, ejecuta [onContentTap] al tocar.
class _SectionCard extends StatelessWidget {
  /// Solo para cards NO colapsables (legacy — no usado actualmente).
  final VoidCallback? onTap;

  /// Toggle colapso/expansión al tocar el header.
  final VoidCallback? onToggle;

  /// Acción al tocar el contenido expandido (ej: abrir editor / fullscreen).
  final VoidCallback? onContentTap;

  /// null → no colapsable. bool → colapsable con estado.
  final bool? isExpanded;

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  const _SectionCard({
    this.onTap,
    this.onToggle,
    this.onContentTap,
    this.isExpanded,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  bool get _collapsible => isExpanded != null;

  @override
  Widget build(BuildContext context) {
    final chevron = _collapsible
        ? Icon(
            isExpanded! ? Icons.expand_less : Icons.expand_more,
            size: 22,
            color: Colors.grey[400],
          )
        : Icon(Icons.chevron_right, size: 22, color: Colors.grey[400]);

    final header = InkWell(
      onTap: _collapsible ? onToggle : onTap,
      borderRadius: _collapsible
          ? BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom: isExpanded! ? Radius.zero : const Radius.circular(16),
            )
          : BorderRadius.circular(16),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, _collapsible && !isExpanded! ? 16 : 10),
        child: Row(
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
            chevron,
          ],
        ),
      ),
    );

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            if (!_collapsible || isExpanded!)
              InkWell(
                onTap: _collapsible ? onContentTap : null,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 1, color: Color(0xFFEEE4CC)),
                      const SizedBox(height: 10),
                      child,
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Botón 3D con gradiente — mismo estilo que los botones de NoteEditorPage
// ---------------------------------------------------------------------------

class _StyledButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final List<Color> gradientColors;
  final Color textColor;
  final Color shadowColor;
  final BoxBorder? border;

  const _StyledButton({
    required this.label,
    required this.onTap,
    required this.gradientColors,
    required this.textColor,
    required this.shadowColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(50),
        border: border,
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.50),
            offset: const Offset(0, 4),
            blurRadius: 8,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          splashColor: Colors.white24,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
