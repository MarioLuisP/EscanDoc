import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:printing/printing.dart';
import 'package:escandoc/features/documents/presentation/providers/documents_provider.dart';
import 'package:escandoc/features/documents/presentation/widgets/delete_confirmation_dialog.dart';
import 'package:escandoc/features/notes/presentation/providers/note_provider.dart';
import 'package:escandoc/features/notes/presentation/widgets/note_display.dart';

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

          return Column(
            children: [
              // Visualizador de PDF
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // PDF/Imagen
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: _buildDocumentViewer(document.filePath),
                      ),

                      // Nota vinculada (si existe)
                      Consumer<NoteProvider>(
                        builder: (context, noteProvider, child) {
                          if (noteProvider.hasNote) {
                            return NoteDisplay(note: noteProvider.currentNote!);
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Botones de acción (AGREGAR NOTA, COMPARTIR)
              _buildActionButtons(),
            ],
          );
        },
      ),
    );
  }

  /// Visualizador de PDF/imagen con zoom
  Widget _buildDocumentViewer(String filePath) {
    final file = File(filePath);

    // Si es PDF, usar PdfPreview
    if (filePath.toLowerCase().endsWith('.pdf')) {
      return PdfPreview(
        build: (format) => file.readAsBytes(),
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canDebug: false,
      );
    }

    // Si es imagen, usar InteractiveViewer con zoom
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'error_loading'.tr(),
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Botones de acción grandes (AGREGAR NOTA, COMPARTIR)
  Widget _buildActionButtons() {
    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        final hasNote = noteProvider.hasNote;
        final documentId = context.read<DocumentsProvider>().selectedDocument?.id;

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
          child: Row(
            children: [
              // Botón AGREGAR NOTA / EDITAR NOTA
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: documentId != null
                      ? () => _navigateToNoteEditor(documentId, hasNote)
                      : null,
                  icon: Icon(
                    hasNote ? Icons.edit_note : Icons.note_add,
                    size: 24,
                  ),
                  label: Text(
                    hasNote ? 'note_edit_button'.tr() : 'note_add_button'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Botón COMPARTIR
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareDocument,
                  icon: const Icon(Icons.share, size: 24),
                  label: Text(
                    'share_button'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Navega al editor de notas
  void _navigateToNoteEditor(int documentId, bool isEditing) async {
    final result = await Navigator.pushNamed(
      context,
      '/note/edit',
      arguments: {
        'documentId': documentId,
        'isEditing': isEditing,
      },
    );

    // Si se guardó la nota, recargar
    if (result == true && mounted) {
      context.read<NoteProvider>().loadNoteByDocument(documentId);
    }
  }

  /// Comparte el documento
  void _shareDocument() {
    // TODO: Implementar compartir con share_plus (futuras épicas)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Share feature coming soon',
          style: const TextStyle(fontSize: 16),
        ),
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
