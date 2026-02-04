import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:escandoc/features/documents/presentation/providers/documents_provider.dart';
import 'package:escandoc/features/scan/presentation/providers/scan_provider.dart';
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
          // TEMPORAL: Botón de diagnóstico SQLite
          IconButton(
            icon: const Icon(Icons.bug_report, size: 28),
            onPressed: () {
              Navigator.pushNamed(context, '/diagnostics');
            },
            tooltip: 'SQLite Diagnostics',
          ),
          // SPIKE TÉCNICO: Scanner custom (Épica 6)
          IconButton(
            icon: const Icon(Icons.science, size: 28, color: Colors.orange),
            onPressed: () {
              Navigator.pushNamed(context, '/spike/scanner');
            },
            tooltip: '🧪 SPIKE: Cunning Scanner',
          ),
          // DEBUG: Scanner nativo actual
          IconButton(
            icon: const Icon(Icons.bug_report_outlined, size: 28, color: Colors.blue),
            onPressed: () {
              Navigator.pushNamed(context, '/spike/native-debug');
            },
            tooltip: '🔍 DEBUG: Scanner Nativo',
          ),
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
      floatingActionButton: Consumer<ScanProvider>(
        builder: (context, scanProvider, child) {
          return FloatingActionButton.extended(
            onPressed: scanProvider.isBusy ? null : () => _handleScan(context),
            icon: scanProvider.isBusy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.camera_alt, size: 28),
            label: Text(
              scanProvider.isBusy
                  ? (scanProvider.isScanning
                      ? 'scanning'.tr()
                      : scanProvider.isSaving
                          ? 'document_saved'.tr()
                          : 'processing_text'.tr())
                  : 'scan_button'.tr(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: scanProvider.isBusy
                ? Colors.grey
                : Theme.of(context).primaryColor,
          );
        },
      ),
    );
  }

  /// Ejecuta flujo de escaneo completo
  Future<void> _handleScan(BuildContext context) async {
    final scanProvider = context.read<ScanProvider>();
    final documentsProvider = context.read<DocumentsProvider>();
    final locale = context.locale.languageCode;

    // Ejecutar scan and save
    final document = await scanProvider.scanAndSave(locale);

    // Usuario canceló o falló
    if (document == null && mounted) {
      if (scanProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'error_scanning'.tr(),
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Éxito - recargar lista y mostrar confirmación
    if (mounted) {
      await documentsProvider.loadDocuments();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'document_saved'.tr(),
            style: const TextStyle(fontSize: 16),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
