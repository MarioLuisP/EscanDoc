import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:escandoc/features/documents/presentation/providers/documents_provider.dart';
import 'package:escandoc/features/documents/presentation/widgets/document_card.dart';
import 'package:escandoc/features/documents/presentation/widgets/empty_state.dart';
import 'package:escandoc/features/documents/presentation/widgets/delete_confirmation_dialog.dart';

/// Página principal que muestra la lista de documentos guardados
/// HU-001: Ver lista de documentos guardados
class DocumentsListPage extends StatefulWidget {
  const DocumentsListPage({super.key});

  @override
  State<DocumentsListPage> createState() => _DocumentsListPageState();
}

class _DocumentsListPageState extends State<DocumentsListPage> {
  @override
  void initState() {
    super.initState();
    // Cargar documentos al iniciar la página
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DocumentsProvider>().loadDocuments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'home_title'.tr(),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Botón de búsqueda
          IconButton(
            icon: const Icon(Icons.search, size: 28),
            onPressed: () {
              Navigator.pushNamed(context, '/search');
            },
            tooltip: 'search_button'.tr(),
          ),
        ],
      ),
      body: Consumer<DocumentsProvider>(
        builder: (context, provider, child) {
          // Estado de carga
          if (provider.isLoading && !provider.hasDocuments) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Estado vacío
          if (!provider.hasDocuments) {
            return const EmptyState();
          }

          // Lista de documentos
          return RefreshIndicator(
            onRefresh: () => provider.loadDocuments(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: provider.documents.length,
              itemBuilder: (context, index) {
                final document = provider.documents[index];

                return DocumentCard(
                  document: document,
                  onTap: () => _navigateToDetail(document.id!),
                  onLongPress: () => _showDeleteDialog(document.id!),
                );
              },
            ),
          );
        },
      ),

      // Botón flotante ESCANEAR (grande y visible)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Implementar en Épica Scan
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Scan feature coming in next epic',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          );
        },
        icon: const Icon(Icons.camera_alt, size: 28),
        label: Text(
          'scan_button'.tr(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  /// Navega a la vista detalle del documento
  void _navigateToDetail(int documentId) async {
    await Navigator.pushNamed(
      context,
      '/document/detail',
      arguments: documentId,
    );

    // Recargar lista al volver (por si se eliminó desde detalle)
    if (mounted) {
      context.read<DocumentsProvider>().loadDocuments();
    }
  }

  /// Muestra el diálogo de confirmación de eliminación
  void _showDeleteDialog(int documentId) async {
    final confirmed = await DeleteConfirmationDialog.show(context);

    if (confirmed == true && mounted) {
      final provider = context.read<DocumentsProvider>();
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
      }
    }
  }
}
