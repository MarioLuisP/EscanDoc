import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gal/gal.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/presentation/providers/documents_provider.dart';
import 'package:escandoc/features/documents/presentation/providers/import_provider.dart';
import 'package:escandoc/features/scan/presentation/providers/scan_provider.dart';
import 'package:escandoc/features/scan/presentation/widgets/photo_detected_dialog.dart';
import 'package:escandoc/features/image_processing/classification/domain/classification_result.dart';
import 'package:escandoc/core/user/user_preferences.dart';

/// Dashboard principal de EscanDocs
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DocumentsProvider>().loadDocuments();
    });
  }

  @override
  Widget build(BuildContext context) {
    context.locale; // Registra dependencia EasyLocalization → rebuild al cambiar idioma
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      bottomNavigationBar: _buildBottomBar(context),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              _buildLogo(),
              const SizedBox(height: 32),
              _buildScanButton(context),
              const SizedBox(height: 8),
              _buildSubtitle(),
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 20),
              _buildRecentSection(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // --- Logo centrado ---

  Widget _buildLogo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset('assets/images/logo.png', width: 64, height: 64),
        const SizedBox(width: 12),
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Escan',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF388E3C),
                ),
              ),
              TextSpan(
                text: 'Docs',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF1B5E20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Barra inferior: [Ver Todos] [+] [Buscar] ---

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F0E8),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _GradientOutlineButton(
                  icon: Icons.folder_open,
                  label: 'view_all'.tr(),
                  onTap: () async {
                    await Navigator.pushNamed(context, '/documents');
                    if (!mounted) return;
                    context.read<DocumentsProvider>().loadDocuments();
                  },
                ),
              ),
              const SizedBox(width: 12),
              _CenterAddButton(onTap: () => _showActionsMenu(context)),
              const SizedBox(width: 12),
              Expanded(
                child: _GradientOutlineButton(
                  icon: Icons.search,
                  label: 'search_button'.tr(),
                  onTap: () => Navigator.pushNamed(context, '/search'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Bottom sheet de acciones ---

  void _showActionsMenu(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFFFDFAF4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ActionsSheet(
        onImport: () {
          Navigator.pop(ctx);
          _handleImport(ctx);
        },
        onNewNote: () {
          Navigator.pop(ctx);
          // TODO: implementar Nueva Nota (post DB-simplification)
          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
            content: Text('Próximamente: Nueva nota',
                style: TextStyle(fontSize: 16)),
            duration: Duration(seconds: 2),
          ));
        },
        onSettings: () {
          Navigator.pop(ctx);
          Navigator.pushNamed(ctx, '/settings');
        },
      ),
    );
  }

  // --- Botón ESCANEAR ---

  Widget _buildScanButton(BuildContext context) {
    return Consumer<ScanProvider>(
      builder: (context, scanProvider, _) {
        final busy = scanProvider.isBusy;
        final gradientColors = busy
            ? [Colors.grey.shade400, Colors.grey.shade600]
            : [const Color(0xFF6FBF6F), const Color(0xFF2E7D32)];
        final shadowColor =
            busy ? Colors.grey.shade700 : const Color(0xFF1A5C1A);

        final label = busy
            ? (scanProvider.isScanning
                ? 'scanning'.tr()
                : scanProvider.isSaving
                    ? 'document_saved'.tr()
                    : 'processing_text'.tr())
            : 'scan_button'.tr();

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: shadowColor.withValues(alpha: 0.55),
                offset: const Offset(0, 5),
                blurRadius: 8,
                spreadRadius: -1,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: busy ? null : () => _handleScan(context),
              borderRadius: BorderRadius.circular(50),
              splashColor: Colors.white24,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    busy
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.camera_alt,
                            size: 28, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'scan_subtitle'.tr(),
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 15, color: Colors.grey[600]),
    );
  }

  Widget _buildRecentSection(BuildContext context) {
    return Consumer<DocumentsProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'recent_documents'.tr(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            if (provider.isLoading && !provider.hasDocuments)
              const Center(child: CircularProgressIndicator())
            else if (!provider.hasDocuments)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'documents_empty'.tr(),
                  style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                ),
              )
            else
              _buildRecentList(provider),
          ],
        );
      },
    );
  }

  Widget _buildRecentList(DocumentsProvider provider) {
    final recent = provider.documents.take(3).toList();
    return Column(
      children: [
        for (int i = 0; i < recent.length; i++) ...[
          _RecentDocItem(
            document: recent[i],
            onTap: () => _navigateToDetail(recent[i].id!),
          ),
          if (i < recent.length - 1) const Divider(height: 1),
        ],
      ],
    );
  }

  // --- Lógica de negocio ---

  Future<void> _handleScan(BuildContext context) async {
    final scanProvider = context.read<ScanProvider>();
    final documentsProvider = context.read<DocumentsProvider>();
    final locale = context.locale.languageCode;
    final messenger = ScaffoldMessenger.of(context);

    final preparation = await scanProvider.prepareScan();

    if (preparation == null) {
      if (scanProvider.error != null) {
        messenger.showSnackBar(SnackBar(
          content: Text('error_scanning'.tr(),
              style: const TextStyle(fontSize: 16)),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ));
      }
      return;
    }

    if (!mounted) return;

    if (preparation.classification.type == DocumentType.photo) {
      if (!mounted) return;
      final action = await PhotoDetectedDialog.show(
        context,
        preparation.thumbnailFile ?? preparation.processedFile,
        userName: UserPreferences().userName,
      );

      if (action == PhotoAction.cancel || action == null) {
        messenger.showSnackBar(SnackBar(
          content: Text('scan_cancelled'.tr(),
              style: const TextStyle(fontSize: 16)),
          duration: const Duration(seconds: 2),
        ));
        return;
      }

      if (action == PhotoAction.saveToGallery) {
        await _savePhotoToGallery(preparation.processedFile);
        return;
      }
    }

    if (!mounted) return;

    final document = await scanProvider.completeScan(preparation, locale);

    if (document == null) {
      if (scanProvider.error != null) {
        messenger.showSnackBar(SnackBar(
          content: Text('Error al guardar: ${scanProvider.error}',
              style: const TextStyle(fontSize: 16)),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ));
      }
      return;
    }

    if (!mounted) return;
    documentsProvider.loadDocuments();
    messenger.showSnackBar(SnackBar(
      content: Text('document_saved'.tr(), style: const TextStyle(fontSize: 16)),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _savePhotoToGallery(File photoFile) async {
    try {
      await Gal.putImage(photoFile.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
                child: Text('Foto guardada en tu galería ✅',
                    style: TextStyle(fontSize: 16))),
          ]),
          backgroundColor: Color(0xFF2D5016),
          duration: Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al guardar en galería: $e',
              style: const TextStyle(fontSize: 16)),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ));
      }
    }
  }

  void _navigateToDetail(int documentId) async {
    await Navigator.pushNamed(context, '/document/detail',
        arguments: documentId);
    if (!mounted) return;
    context.read<DocumentsProvider>().loadDocuments();
  }

  Future<void> _handleImport(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final importProvider = context.read<ImportProvider>();
    final documentsProvider = context.read<DocumentsProvider>();
    final locale = context.locale.languageCode;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.first.path;
      if (filePath == null) {
        throw Exception('No se pudo obtener la ruta del archivo');
      }

      final importedFile = File(filePath);
      if (!importedFile.existsSync()) {
        throw Exception('El archivo seleccionado no existe');
      }

      final preparation = await importProvider.prepareImport(importedFile);
      if (preparation == null) {
        if (importProvider.error != null) {
          messenger.showSnackBar(SnackBar(
            content: Text(
                'Error al preparar documento: ${importProvider.error}',
                style: const TextStyle(fontSize: 16)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ));
        }
        return;
      }

      if (preparation.classification.type == DocumentType.photo) {
        if (!mounted) return;
        final action = await PhotoDetectedDialog.show(
          context,
          preparation.thumbnailFile ?? preparation.processedFile,
          userName: UserPreferences().userName,
          showGalleryOption: false,
        );

        if (action == PhotoAction.cancel || action == null) {
          messenger.showSnackBar(SnackBar(
            content: Text('import_cancelled'.tr(),
                style: const TextStyle(fontSize: 16)),
            duration: const Duration(seconds: 2),
          ));
          return;
        }
      }

      if (!mounted) return;

      final document = await importProvider.completeImport(preparation, locale);
      if (document == null) {
        if (importProvider.error != null) {
          messenger.showSnackBar(SnackBar(
            content: Text(
                'Error al guardar documento: ${importProvider.error}',
                style: const TextStyle(fontSize: 16)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ));
        }
        return;
      }

      if (!mounted) return;
      documentsProvider.loadDocuments();
      messenger.showSnackBar(SnackBar(
        content: Text('document_imported'.tr(),
            style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Error al importar: $e',
            style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ));
    }
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet de acciones secundarias
// ---------------------------------------------------------------------------

class _ActionsSheet extends StatelessWidget {
  final VoidCallback onImport;
  final VoidCallback onNewNote;
  final VoidCallback onSettings;

  const _ActionsSheet({
    required this.onImport,
    required this.onNewNote,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _SheetActionButton(
            icon: Icons.upload_file,
            label: 'import_document_tooltip'.tr(),
            onTap: onImport,
          ),
          const SizedBox(height: 10),
          _SheetActionButton(
            icon: Icons.edit_note,
            label: 'Nueva nota', // TODO: i18n al implementar
            onTap: onNewNote,
          ),
          // --- Separador visual: acciones principales / configuración ---
          const SizedBox(height: 6),
          Divider(thickness: 1, color: Colors.grey.shade300),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Text(
              'menu_settings'.tr().toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                letterSpacing: 1.1,
              ),
            ),
          ),
          _SheetItem(
            icon: Icons.settings_outlined,
            label: 'menu_settings'.tr(),
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}

/// Botón 3D crema para acciones principales del sheet (Importar, Nueva nota)
class _SheetActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SheetActionButton({
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBAA88), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9A8060).withValues(alpha: 0.40),
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
          borderRadius: BorderRadius.circular(14),
          splashColor: const Color(0xFFBBAA88).withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              children: [
                Icon(icon, size: 24, color: const Color(0xFF5A4A30)),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFF5A4A30),
                    fontWeight: FontWeight.w600,
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

class _SheetItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 26, color: const Color(0xFF5A4A30)),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                color: Color(0xFF5A4A30),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Botón "+" central — verde degradé, sombra 3D, sin Flutter FAB
// ---------------------------------------------------------------------------

class _CenterAddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CenterAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8F5E8), Color(0xFFC0D8C0)],
        ),
        border: Border.all(color: const Color(0xFF7AAB7A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A7A4A).withValues(alpha: 0.38),
            offset: const Offset(0, 4),
            blurRadius: 7,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          splashColor: const Color(0xFF7AAB7A).withValues(alpha: 0.3),
          child: const Icon(Icons.more_horiz, color: Color(0xFF2E7D32), size: 26),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Botón outline crema con gradiente (Ver Todos / Buscar)
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
            color: const Color(0xFF9A8060).withValues(alpha: 0.45),
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
          splashColor: const Color(0xFFBBAA88).withValues(alpha: 0.3),
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

// ---------------------------------------------------------------------------
// Item de documento reciente
// ---------------------------------------------------------------------------

class _RecentDocItem extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback onTap;

  const _RecentDocItem({required this.document, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            _buildThumbnail(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(document.createdAt),
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final imageFile = File(document.filePath);
    return Container(
      width: 60,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          imageFile,
          width: 60,
          height: 70,
          cacheWidth: 150,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.insert_drive_file,
            size: 32,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'month_jan', 'month_feb', 'month_mar', 'month_apr',
      'month_may', 'month_jun', 'month_jul', 'month_aug',
      'month_sep', 'month_oct', 'month_nov', 'month_dec',
    ];
    final month = months[date.month - 1].tr();
    return '${date.day} $month ${date.year}';
  }
}
