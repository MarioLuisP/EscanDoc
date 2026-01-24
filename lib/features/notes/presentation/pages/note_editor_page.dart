import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:escandoc/features/notes/presentation/providers/note_provider.dart';

/// Página de edición/creación de notas
/// HU-004: Agregar nota a documento
class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late bool _isEditing;
  late int _documentId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Obtener argumentos: {documentId: int, isEditing: bool}
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _documentId = args?['documentId'] as int? ?? 0;
    _isEditing = args?['isEditing'] as bool? ?? false;

    // Si es edición, pre-poblar los campos
    if (_isEditing) {
      final noteProvider = context.watch<NoteProvider>();
      if (noteProvider.currentNote != null) {
        _titleController.text = noteProvider.currentNote!.title;
        _contentController.text = noteProvider.currentNote!.content ?? '';
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'note_edit'.tr() : 'note_add'.tr(),
          style: const TextStyle(fontSize: 20),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () => Navigator.pop(context),
          tooltip: 'back_button'.tr(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Campo de título
            Text(
              'note_title_label'.tr(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              autofocus: true, // Teclado aparece automáticamente
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: 'note_title_hint'.tr(),
                hintStyle: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[400],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El título no puede estar vacío';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Campo de contenido
            Text(
              'note_content_label'.tr(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _contentController,
              style: const TextStyle(fontSize: 18),
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'note_content_hint'.tr(),
                hintStyle: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[400],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 32),

            // Botones GUARDAR y CANCELAR (grandes)
            Row(
              children: [
                // Botón CANCELAR
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(
                        color: Colors.grey[600]!,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'cancel_button'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Botón GUARDAR
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveNote,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'save_button'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Guarda o actualiza la nota
  void _saveNote() async {
    if (!_formKey.currentState!.validate()) return;

    final noteProvider = context.read<NoteProvider>();
    bool success;

    if (_isEditing) {
      // Actualizar nota existente
      success = await noteProvider.updateNote(
        title: _titleController.text,
        content: _contentController.text,
      );
    } else {
      // Crear nueva nota
      success = await noteProvider.createNote(
        title: _titleController.text,
        content: _contentController.text,
        documentId: _documentId,
      );
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'note_saved'.tr(),
            style: const TextStyle(fontSize: 16),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context, true); // Retornar true para indicar que se guardó
    }
  }
}
