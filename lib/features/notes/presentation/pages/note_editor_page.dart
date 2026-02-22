import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:escandoc/features/notes/presentation/providers/note_provider.dart';

/// Página de edición/creación de notas — diseño crema/verde.
class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final _contentController = TextEditingController();
  late bool _isEditing;
  late int _documentId;
  String _documentTitle = '';
  String _originalContent = '';
  bool _initialized = false;
  bool _hasChanges = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _documentId = args?['documentId'] as int? ?? 0;
    _isEditing = args?['isEditing'] as bool? ?? false;
    _documentTitle = args?['documentTitle'] as String? ?? '';

    if (_isEditing) {
      final content =
          context.read<NoteProvider>().currentNote?.content ?? '';
      _contentController.text = content;
      _originalContent = content;
    }

    _contentController.addListener(() {
      final changed = _contentController.text != _originalContent;
      if (changed != _hasChanges) {
        setState(() => _hasChanges = changed);
      }
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('discard_changes_title'.tr(),
            style: const TextStyle(fontSize: 20)),
        content: Text('discard_changes_message'.tr(),
            style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('discard_no'.tr(),
                style: const TextStyle(fontSize: 16)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'discard_yes'.tr(),
              style: const TextStyle(fontSize: 16, color: Colors.red),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final pageTitle = _isEditing
        ? 'note_edit_title'.tr(namedArgs: {'docName': _documentTitle})
        : 'note_new_title'.tr(namedArgs: {'docName': _documentTitle});

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldDiscard = await _confirmDiscard();
        if (shouldDiscard && mounted) {
          setState(() => _hasChanges = false);
          if (mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F0E8),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, pageTitle),
              Expanded(child: _buildTextArea()),
              _buildActionButtons(context),
              _buildBottomBar(context),
            ],
          ),
        ),
      ),
    );
  }

  // --- Header: ← título centrado ---

  Widget _buildHeader(BuildContext context, String title) {
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
            onPressed: () async {
              final shouldPop = await _confirmDiscard();
              if (shouldPop && mounted) Navigator.pop(context);
            },
          ),
          Expanded(
            child: Text(
              title,
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
          const SizedBox(width: 48), // espacio simétrico al back button
        ],
      ),
    );
  }

  // --- Área de texto: fondo papel con ícono ✏️ ---

  Widget _buildTextArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFDFAF2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDDD0B8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              offset: const Offset(0, 3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Campo de texto ocupa todo el contenedor
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 44, 16),
              child: TextField(
                controller: _contentController,
                autofocus: true,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                  fontSize: 17,
                  color: Colors.black87,
                  height: 1.65,
                ),
                decoration: InputDecoration(
                  hintText: 'note_content_hint'.tr(),
                  hintStyle:
                      TextStyle(fontSize: 17, color: Colors.grey[400]),
                  border: InputBorder.none,
                ),
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
            // Ícono ✏️ en esquina superior derecha
            Positioned(
              top: 14,
              right: 14,
              child: Icon(
                Icons.edit_note,
                size: 26,
                color: Colors.grey[300],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Botones CANCELAR / GUARDAR ---

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(child: _buildCancelButton(context)),
          const SizedBox(width: 12),
          Expanded(child: _buildSaveButton()),
        ],
      ),
    );
  }

  Widget _buildCancelButton(BuildContext context) {
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
            color: const Color(0xFF9A8060).withOpacity(0.45),
            offset: const Offset(0, 4),
            blurRadius: 7,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final shouldPop = await _confirmDiscard();
            if (shouldPop && mounted) Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(50),
          splashColor: const Color(0xFFBBAA88).withOpacity(0.3),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.close, size: 20, color: Color(0xFF5A4A30)),
                const SizedBox(width: 8),
                Text(
                  'cancel_button'.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFF5A4A30),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
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
            color: const Color(0xFF1A5C1A).withOpacity(0.50),
            offset: const Offset(0, 4),
            blurRadius: 8,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _saveNote,
          borderRadius: BorderRadius.circular(50),
          splashColor: Colors.white24,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check, size: 20, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'save_button'.tr(),
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

  // --- Bottom bar: Inicio / Ver Todos ---

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8),
        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _GradientOutlineButton(
              icon: Icons.home_outlined,
              label: 'go_home'.tr(),
              onTap: () async {
                final ok = await _confirmDiscard();
                if (ok && mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/home', (route) => false);
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _GradientOutlineButton(
              icon: Icons.folder_open,
              label: 'view_all'.tr(),
              onTap: () async {
                final ok = await _confirmDiscard();
                if (ok && mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/documents', (route) => false);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Lógica ---

  void _saveNote() async {
    final noteProvider = context.read<NoteProvider>();
    bool success;

    if (_isEditing) {
      success =
          await noteProvider.updateNote(content: _contentController.text);
    } else {
      success = await noteProvider.createNote(
        content: _contentController.text,
        documentId: _documentId,
      );
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('note_saved'.tr(), style: const TextStyle(fontSize: 16)),
        duration: const Duration(milliseconds: 1500),
      ));
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.pop(context, true);
    }
  }
}

// ---------------------------------------------------------------------------
// Widget privado: botón con gradiente crema + borde + sombra 3D
// ---------------------------------------------------------------------------

class _GradientOutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GradientOutlineButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
            color: const Color(0xFF9A8060).withOpacity(0.45),
            offset: const Offset(0, 4),
            blurRadius: 7,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          splashColor: const Color(0xFFBBAA88).withOpacity(0.3),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: const Color(0xFF5A4A30)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 22,
                    color: Color(0xFF5A4A30),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
