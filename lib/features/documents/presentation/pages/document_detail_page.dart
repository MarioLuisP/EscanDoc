import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:escandoc/features/documents/presentation/providers/documents_provider.dart';
import 'package:escandoc/features/documents/presentation/widgets/delete_confirmation_dialog.dart';
import 'package:escandoc/features/documents/presentation/widgets/photo_preview_section.dart';
import 'package:escandoc/features/documents/presentation/widgets/note_preview_section.dart';
import 'package:escandoc/features/documents/presentation/widgets/ocr_preview_section.dart';
import 'package:escandoc/features/documents/presentation/pages/photo_fullscreen_page.dart';
import 'package:escandoc/features/documents/presentation/pages/ocr_fullscreen_page.dart';
import 'package:escandoc/features/notes/presentation/providers/note_provider.dart';

/// Página de detalle del documento con visualización de PDF/imagen
/// HU-002: Ver documento en detalle
class DocumentDetailPage extends StatefulWidget {
  const DocumentDetailPage({super.key});

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  @override
  void initState() {
    super.initState();

    // Cargar documento seleccionado y su nota
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final documentId = ModalRoute.of(context)?.settings.arguments as int?;
      if (documentId != null) {
        context.read<DocumentsProvider>().selectDocument(documentId);
        context.read<NoteProvider>().loadNoteByDocument(documentId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Botón VOLVER grande y visible
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () => Navigator.pop(context),
          tooltip: 'back_button'.tr(),
        ),
        title: Consumer<DocumentsProvider>(
          builder: (context, provider, child) {
            return Text(
              provider.selectedDocument?.title ?? 'document_detail'.tr(),
              style: const TextStyle(fontSize: 20),
            );
          },
        ),
        actions: [
          // Botón de eliminación
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 28),
            onPressed: _showDeleteDialog,
            tooltip: 'delete_button'.tr(),
          ),
        ],
      ),
      body: Consumer<DocumentsProvider>(
        builder: (context, provider, child) {
          // Estado de carga
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error o documento no encontrado
          if (provider.selectedDocument == null) {
            return Center(
              child: Text(
                provider.errorMessage ?? 'error_loading'.tr(),
                style: const TextStyle(fontSize: 18),
              ),
            );
          }

          final document = provider.selectedDocument!;

          return Consumer<NoteProvider>(
            builder: (context, noteProvider, child) {
              return Column(
                children: [
                  // Sección 1 - Foto (50%)
                  Expanded(
                    flex: 50,
                    child: PhotoPreviewSection(
                      imagePath: document.filePath,
                      onTap: () => _openPhotoFullscreen(document.filePath),
                    ),
                  ),

                  // Sección 2 - Nota (20%)
                  Expanded(
                    flex: 20,
                    child: NotePreviewSection(
                      noteContent: noteProvider.currentNote?.content,
                      onTap: () => _openNoteEditor(document.id!),
                    ),
                  ),

                  // Sección 3 - Texto OCR (30%)
                  Expanded(
                    flex: 30,
                    child: OcrPreviewSection(
                      ocrText: document.ocrText,
                      onTap: () => _openOcrFullscreen(document.ocrText),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Abre la vista fullscreen de la foto/PDF
  void _openPhotoFullscreen(String filePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoFullscreenPage(filePath: filePath),
      ),
    );
  }

  /// Abre el editor de notas
  void _openNoteEditor(int documentId) async {
    final hasNote = context.read<NoteProvider>().hasNote;

    final result = await Navigator.pushNamed(
      context,
      '/note/edit',
      arguments: {
        'documentId': documentId,
        'isEditing': hasNote,
      },
    );

    // Si se guardó la nota, recargar
    if (result == true && mounted) {
      context.read<NoteProvider>().loadNoteByDocument(documentId);
    }
  }

  /// Abre la vista fullscreen del texto OCR
  void _openOcrFullscreen(String? ocrText) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OcrFullscreenPage(ocrText: ocrText),
      ),
    );
  }

  /// Muestra el diálogo de confirmación de eliminación
  void _showDeleteDialog() async {
    final provider = context.read<DocumentsProvider>();
    final documentId = provider.selectedDocument?.id;

    if (documentId == null) return;

    final confirmed = await DeleteConfirmationDialog.show(context);

    if (confirmed == true && mounted) {
      final success = await provider.deleteDocument(documentId);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'document_deleted'.tr(),
              style: const TextStyle(fontSize: 16),
            ),
            duration: const Duration(seconds: 3),
          ),
        );

        // Volver a la lista
        Navigator.pop(context);
      }
    }
  }
}
