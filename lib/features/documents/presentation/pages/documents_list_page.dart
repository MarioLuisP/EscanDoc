import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gal/gal.dart';
import 'package:escandoc/features/documents/presentation/providers/documents_provider.dart';
import 'package:escandoc/features/documents/presentation/providers/import_provider.dart';
import 'package:escandoc/features/scan/presentation/providers/scan_provider.dart';
import 'package:escandoc/features/documents/presentation/widgets/document_card.dart';
import 'package:escandoc/features/documents/presentation/widgets/empty_state.dart';
import 'package:escandoc/features/documents/presentation/widgets/delete_confirmation_dialog.dart';
import 'package:escandoc/features/scan/presentation/widgets/photo_detected_dialog.dart';
import 'package:escandoc/features/image_processing/classification/domain/classification_result.dart';

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
          // Botón IMPORTAR documento
          IconButton(
            icon: const Icon(Icons.upload_file, size: 28),
            onPressed: () => _handleImport(context),
            tooltip: 'Importar documento',
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

  /// Ejecuta flujo de escaneo completo con clasificación
  Future<void> _handleScan(BuildContext context) async {
    final scanProvider = context.read<ScanProvider>();
    final documentsProvider = context.read<DocumentsProvider>();
    final locale = context.locale.languageCode;

    // 1. Preparar escaneo (scanner + convertir + clasificar + normalizar solo si es documento)
    final preparation = await scanProvider.prepareScan();

    if (preparation == null) {
      // Usuario canceló o error
      if (mounted && scanProvider.error != null) {
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

    if (!mounted) return;

    // 2. Si detectó FOTO → Mostrar diálogo especial (guardar en galería O app)
    if (preparation.classification.type == DocumentType.photo) {
      final action = await PhotoDetectedDialog.show(
        context,
        preparation.processedFile,
      );

      if (action == PhotoAction.cancel || action == null) {
        // Usuario canceló
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Escaneo cancelado',
                style: TextStyle(fontSize: 16),
              ),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Guardar en galería (feature oculta)
      if (action == PhotoAction.saveToGallery) {
        await _savePhotoToGallery(preparation.processedFile);
        return;
      }

      // Si eligió "Guardar en App" → continuar flujo normal
    }

    if (!mounted) return;

    // 3. Completar escaneo (normalizar si es foto + guardar + OCR)
    final document = await scanProvider.completeScan(
      preparation,
      locale,
    );

    if (document == null) {
      // Error al guardar
      if (mounted && scanProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al guardar: ${scanProvider.error}',
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    // 4. Éxito - recargar lista y mostrar confirmación
    if (mounted) {
      documentsProvider.loadDocuments(); // Sin await - carga en background
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

  /// Guarda una foto en la galería del teléfono (feature oculta)
  Future<void> _savePhotoToGallery(File photoFile) async {
    try {
      debugPrint('[DocumentsListPage] Guardando foto en galería: ${photoFile.path}');

      // Guardar en galería usando gal
      await Gal.putImage(photoFile.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Foto guardada en tu galería ✅',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFF2D5016), // Verde bosque
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('[DocumentsListPage] ERROR al guardar en galería: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al guardar en galería: ${e.toString()}',
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
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

  /// Ejecuta flujo de importación de documento
  Future<void> _handleImport(BuildContext context) async {
    try {
      // 1. Seleccionar archivo con FilePicker
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        // Usuario canceló
        return;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        throw Exception('No se pudo obtener la ruta del archivo');
      }

      final importedFile = File(filePath);
      if (!importedFile.existsSync()) {
        throw Exception('El archivo seleccionado no existe');
      }

      if (!mounted) return;

      final importProvider = context.read<ImportProvider>();
      final documentsProvider = context.read<DocumentsProvider>();
      final locale = context.locale.languageCode;

      // 2. Preparar importación (convertir + clasificar + normalizar solo si es documento)
      final preparation = await importProvider.prepareImport(importedFile);

      if (preparation == null) {
        // Error en preparación
        if (mounted && importProvider.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error al preparar documento: ${importProvider.error}',
                style: const TextStyle(fontSize: 16),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      // 3. Si detectó FOTO → Mostrar diálogo (sin opción galería, ya está en galería)
      if (preparation.classification.type == DocumentType.photo) {
        final action = await PhotoDetectedDialog.show(
          context,
          preparation.processedFile,
          showGalleryOption: false, // Import: solo App o Cancelar
        );

        if (action == PhotoAction.cancel || action == null) {
          // Usuario canceló
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Importación cancelada',
                  style: TextStyle(fontSize: 16),
                ),
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }

        // Si eligió "Guardar en App" → continuar flujo normal
        // (PhotoAction.saveToGallery no debería aparecer aquí por showGalleryOption=false)
      }

      if (!mounted) return;

      // 4. Completar importación (normalizar si es foto + guardar + OCR)
      final document = await importProvider.completeImport(
        preparation,
        locale,
      );

      if (document == null) {
        // Error al guardar
        if (mounted && importProvider.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error al guardar documento: ${importProvider.error}',
                style: const TextStyle(fontSize: 16),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // 5. Recargar lista y mostrar confirmación
      if (mounted) {
        documentsProvider.loadDocuments();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Documento importado exitosamente',
              style: TextStyle(fontSize: 16),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('[DocumentsListPage] ERROR en _handleImport: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al importar: $e',
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

}
