import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:escandoc/features/documents/presentation/providers/documents_provider.dart';
import 'package:escandoc/features/documents/presentation/providers/import_provider.dart';
import 'package:escandoc/features/scan/presentation/providers/scan_provider.dart';
import 'package:escandoc/features/documents/presentation/widgets/document_card.dart';
import 'package:escandoc/features/documents/presentation/widgets/empty_state.dart';
import 'package:escandoc/features/documents/presentation/widgets/delete_confirmation_dialog.dart';
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

      // 3. Si detectó FOTO → Confirmar con usuario
      if (preparation.classification.type == DocumentType.photo) {
        final confirmed = await _showPhotoConfirmationDialog(
          context,
          preparation.classification,
        );

        if (confirmed != true) {
          // Usuario canceló
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Importación cancelada',
                  style: TextStyle(fontSize: 16),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return;
        }
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

  /// Muestra diálogo de confirmación cuando se detecta una FOTO
  Future<bool?> _showPhotoConfirmationDialog(
    BuildContext context,
    ClassificationResult classification,
  ) async {
    final uniqueColors = classification.metadata['uniqueColors'] as int? ?? 0;
    final topTenCoverage = classification.metadata['topTenCoverage'] as double? ?? 0;
    final confidence = (classification.confidence * 100).toStringAsFixed(0);

    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.photo_camera, size: 32, color: Colors.orange),
              SizedBox(width: 12),
              Text('Foto detectada'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🖼️ Creo que tratas de importar una foto',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                '¿Aún así quieres continuar?',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              // Detalles de detección (para debugging - puedes comentar después)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confianza: $confidence%',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Colores únicos: ${uniqueColors.toString()}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cobertura top 10: ${(topTenCoverage * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancelar',
                style: TextStyle(fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Continuar de todas formas',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }
}
