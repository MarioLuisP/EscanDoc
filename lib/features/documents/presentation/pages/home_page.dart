import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gal/gal.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/presentation/providers/documents_provider.dart';
import 'package:escandoc/features/documents/presentation/providers/import_provider.dart';
import 'package:escandoc/features/scan/presentation/providers/scan_provider.dart';
import 'package:escandoc/features/scan/presentation/widgets/photo_detected_dialog.dart';
import 'package:escandoc/features/image_processing/classification/domain/classification_result.dart';
import 'package:escandoc/core/user/user_preferences.dart';
import 'package:escandoc/core/theme/document_type_colors.dart';
import 'package:escandoc/features/backup/presentation/providers/backup_provider.dart';

/// Dashboard principal de EscanDocs
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  StreamSubscription? _intentSub;
  bool _wasProcessingOCR = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DocumentsProvider>().loadDocuments();
      context.read<ImportProvider>().addListener(_onImportChanged);
      _initSharingIntent();
    });
  }

  void _onImportChanged() {
    if (!mounted) return;
    final isProcessing = context.read<ImportProvider>().isProcessingOCR;
    if (_wasProcessingOCR && !isProcessing) {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      context.read<DocumentsProvider>().loadDocuments();
    }
    _wasProcessingOCR = isProcessing;
  }

  void _initSharingIntent() {
    // App ya abierta — llega un archivo compartido
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> files) {
        if (files.isEmpty) return;
        _processSharedFile(files.first.path).catchError((Object e) {
          debugPrint('[HomePageState] Error procesando archivo compartido: $e');
        });
      },
      onError: (Object e) =>
          debugPrint('[HomePageState] Error en stream de sharing: $e'),
    );

    // App cerrada — se abrió desde un archivo compartido (cold start)
    ReceiveSharingIntent.instance.getInitialMedia().then(
      (List<SharedMediaFile> files) async {
        if (files.isEmpty) return;
        await _processSharedFile(files.first.path);
        ReceiveSharingIntent.instance.reset();
      },
    ).catchError((Object e) {
      debugPrint('[HomePageState] Error en getInitialMedia: $e');
    });
  }

  /// Copia el archivo compartido al cache propio antes de procesarlo.
  ///
  /// Cuando el usuario comparte una captura de pantalla sin guardarla,
  /// Android provee un URI efímero que puede expirar o ser borrado por el
  /// sistema antes de que terminemos de procesar. Copiando al cache propio
  /// garantizamos acceso estable durante todo el pipeline.
  Future<void> _processSharedFile(String sourcePath) async {
    if (sourcePath.isEmpty) return;
    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync()) return;

    try {
      final tempDir = await getTemporaryDirectory();

      // Extraer extensión solo del nombre de archivo — evita confundir puntos
      // del package name (com.app.package) con la extensión del archivo.
      final filename = sourcePath.split('/').last;
      final dotIndex = filename.lastIndexOf('.');
      final rawExt = dotIndex >= 0
          ? filename.substring(dotIndex + 1).split('?').first.toLowerCase()
          : '';
      const validExts = {'jpg', 'jpeg', 'png', 'pdf', 'webp', 'heic', 'heif', 'escdc'};

      // Si la extensión no es reconocida, detectar por magic bytes.
      final String ext;
      if (validExts.contains(rawExt)) {
        ext = rawExt == 'jpeg' ? 'jpg' : rawExt;
      } else {
        ext = await _detectFormatByMagicBytes(sourceFile) ?? 'jpg';
      }

      final baseName = dotIndex >= 0
          ? filename.substring(0, dotIndex)
          : 'import';
      final stableFile = await sourceFile.copy(
        '${tempDir.path}/${baseName}_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );

      if (ext == 'escdc') {
        await _runBackupImport(stableFile.path);
      } else if (ext == 'pdf') {
        await _handlePdfImport(stableFile.path);
      } else {
        await _processImportedFile(stableFile);
      }
    } catch (_) {
      // Si no se puede copiar, intentar con el archivo original
      await _processImportedFile(sourceFile);
    }
  }

  /// Detecta el formato de un archivo leyendo sus primeros bytes (magic bytes).
  /// Retorna 'pdf', 'jpg', 'png' o 'webp', o null si no se reconoce.
  Future<String?> _detectFormatByMagicBytes(File file) async {
    try {
      final raf = await file.open();
      final bytes = await raf.read(8);
      await raf.close();
      if (bytes.length >= 4) {
        // PDF: %PDF (25 50 44 46)
        if (bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) return 'pdf';
        // JPEG: FF D8 FF
        if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return 'jpg';
        // PNG: 89 50 4E 47
        if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return 'png';
        // WebP: RIFF....WE
        if (bytes.length >= 8 &&
            bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
            bytes[6] == 0x57 && bytes[7] == 0x45) {
          return 'webp';
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    context.read<ImportProvider>().removeListener(_onImportChanged);
    _intentSub?.cancel();
    super.dispose();
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
                    final provider = context.read<DocumentsProvider>();
                    await Navigator.pushNamed(context, '/documents');
                    if (!mounted) return;
                    provider.loadDocuments();
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
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFDFAF4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ActionsSheet(
        onImport: () {
          Navigator.pop(ctx);
          _handleImport();
        },
        onNewNote: () {
          Navigator.pop(ctx);
          Navigator.pushNamed(ctx, '/note/edit',
              arguments: {'isNewNote': true});
        },
        onCalendar: () {
          Navigator.pop(ctx);
          Navigator.pushNamed(ctx, '/calendar');
        },
        onSettings: () {
          Navigator.pop(ctx);
          Navigator.pushNamed(ctx, '/settings');
        },
      ),
    );
  }

  Future<void> _runBackupImport(String filePath) async {
    final messenger = ScaffoldMessenger.of(context);
    final backupProvider = context.read<BackupProvider>();
    final documentsProvider = context.read<DocumentsProvider>();

    messenger.showSnackBar(SnackBar(
      content: Text('backup_importing'.tr(), style: const TextStyle(fontSize: 16)),
      duration: const Duration(seconds: 60),
    ));

    final docsDir = await getApplicationDocumentsDirectory();
    final count = await backupProvider.importBackup(File(filePath), docsDir.path);
    if (!mounted) return;

    messenger.hideCurrentSnackBar();

    if (backupProvider.error != null) {
      messenger.showSnackBar(SnackBar(
        content: Text('backup_import_error'.tr(), style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ));
      return;
    }

    messenger.showSnackBar(SnackBar(
      content: Text(
        'backup_import_success'.tr(namedArgs: {'count': '$count'}),
        style: const TextStyle(fontSize: 16),
      ),
      backgroundColor: const Color(0xFF2D5016),
      duration: const Duration(seconds: 3),
    ));

    await documentsProvider.loadDocuments();
  }

  // --- Botón ESCANEAR ---

  Widget _buildScanButton(BuildContext context) {
    return Consumer2<ScanProvider, ImportProvider>(
      builder: (context, scanProvider, importProvider, _) {
        final busy = scanProvider.isBusy || importProvider.isBusy;
        final gradientColors = busy
            ? [Colors.grey.shade400, Colors.grey.shade600]
            : [const Color(0xFF6FBF6F), const Color(0xFF2E7D32)];
        final shadowColor =
            busy ? Colors.grey.shade700 : const Color(0xFF1A5C1A);

        final String label;
        if (importProvider.pdfCurrentPage > 0 && importProvider.pdfTotalPages > 1) {
          label = 'status_pdf_page'.tr(namedArgs: {
            'current': '${importProvider.pdfCurrentPage}',
            'total': '${importProvider.pdfTotalPages}',
          });
        } else if (importProvider.statusMessage != null) {
          label = importProvider.statusMessage!.tr();
        } else if (scanProvider.isBusy) {
          label = scanProvider.isScanning
              ? 'scanning'.tr()
              : scanProvider.isSaving
                  ? 'document_saved'.tr()
                  : 'processing_text'.tr();
        } else {
          label = 'scan_button'.tr();
        }

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.35),
              width: 1,
            ),
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
    return Consumer2<DocumentsProvider, ImportProvider>(
      builder: (context, docsProvider, importProvider, _) {
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
            if (docsProvider.isLoading && !docsProvider.hasDocuments)
              const Center(child: CircularProgressIndicator())
            else if (!docsProvider.hasDocuments)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'documents_empty'.tr(),
                  style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                ),
              )
            else
              _buildRecentList(docsProvider, importProvider),
          ],
        );
      },
    );
  }

  Widget _buildRecentList(DocumentsProvider provider, ImportProvider importProvider) {
    final recent = provider.documents.take(3).toList();
    return Column(
      children: [
        for (int i = 0; i < recent.length; i++) ...[
          _RecentDocItem(
            document: recent[i],
            isProcessingOcr: importProvider.processingOcrIds.contains(recent[i].id),
            onTap: () => _navigateToDetail(recent[i].id!),
          ),
          if (i < recent.length - 1) const SizedBox(height: 8),
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

    if (preparation.classification.type == DocumentType.foto) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      final action = await PhotoDetectedDialog.show(context,
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
  }

  Future<void> _savePhotoToGallery(File photoFile) async {
    try {
      await Gal.putImage(photoFile.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
                child: Text('photo_saved_gallery'.tr(),
                    style: const TextStyle(fontSize: 16))),
          ]),
          backgroundColor: const Color(0xFF2D5016),
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('photo_save_gallery_error'.tr(namedArgs: {'error': '$e'}),
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

  Future<void> _handleImport() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'webp', 'heic', 'heif'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.first.path;
    if (filePath == null) return;

    final ext = filePath.split('.').last.toLowerCase();
    if (ext == 'pdf') {
      await _handlePdfImport(filePath);
    } else {
      await _processSharedFile(filePath);
    }
  }

  Future<void> _handlePdfImport(String pdfPath) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final importProvider = context.read<ImportProvider>();
    final documentsProvider = context.read<DocumentsProvider>();
    final locale = context.locale.languageCode;

    // Contar páginas
    final pageCount = await importProvider.checkPdfPageCount(pdfPath);
    if (pageCount == 0) {
      messenger.showSnackBar(SnackBar(
        content: Text('pdf_read_error'.tr(),
            style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ));
      return;
    }

    // Si tiene más de 10 páginas, preguntar cuántas importar
    int pagesToImport = pageCount;
    if (pageCount > 10) {
      if (!mounted) return;
      pagesToImport = await _showPdfPagesDialog(pageCount) ?? 0;
      if (pagesToImport == 0) return; // Canceló
    }

    // Importar páginas
    final documents = await importProvider.importPdfPages(pdfPath, pagesToImport, locale);
    if (!mounted) return;

    if (documents.isEmpty) {
      messenger.showSnackBar(SnackBar(
        content: Text('pdf_import_error'.tr(),
            style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ));
      return;
    }

    await documentsProvider.loadDocuments();
  }

  /// Dialog para PDFs con más de 10 páginas.
  /// Retorna cuántas páginas importar, o null si cancela.
  Future<int?> _showPdfPagesDialog(int totalPages) {
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('pdf_pages_dialog_title'.tr(),
            style: const TextStyle(fontSize: 20)),
        content: Text(
          'pdf_pages_dialog_message'.tr(namedArgs: {'total': '$totalPages'}),
          style: const TextStyle(fontSize: 17),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('pdf_pages_cancel'.tr(),
                style: const TextStyle(fontSize: 16)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 10),
            child: Text('pdf_pages_first_10'.tr(),
                style: const TextStyle(fontSize: 16)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, totalPages),
            child: Text('pdf_pages_all'.tr(namedArgs: {'total': '$totalPages'}),
                style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Future<void> _processImportedFile(File importedFile) async {
    final messenger = ScaffoldMessenger.of(context);
    final importProvider = context.read<ImportProvider>();
    final documentsProvider = context.read<DocumentsProvider>();
    final locale = context.locale.languageCode;
    try {
      if (!importedFile.existsSync()) {
        throw Exception('El archivo no existe: ${importedFile.path}');
      }

      final preparation = await importProvider.prepareImport(importedFile);
      if (preparation == null) {
        if (importProvider.error != null) {
          messenger.showSnackBar(SnackBar(
            content: Text(
                'import_prepare_error'.tr(
                    namedArgs: {'error': '${importProvider.error}'}),
                style: const TextStyle(fontSize: 16)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ));
        }
        return;
      }

      if (preparation.classification.type == DocumentType.foto) {
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        final action = await PhotoDetectedDialog.show(context,
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
  final VoidCallback onCalendar;
  final VoidCallback onSettings;

  const _ActionsSheet({
    required this.onImport,
    required this.onNewNote,
    required this.onCalendar,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    EasyLocalization.of(context)?.locale;
    return SafeArea(
      top: false,
      child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                'sheet_title'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          _ToolCard(
            icon: Icons.image,
            iconColor: const Color(0xFF4A6A28),
            title: 'import_tool_label'.tr(),
            subtitle: 'import_document_desc'.tr(),
            onTap: onImport,
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: Icons.sticky_note_2,
            iconColor: const Color(0xFFF9A825),
            title: 'note_tool_label'.tr(),
            subtitle: 'note_new_desc'.tr(),
            onTap: onNewNote,
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: Icons.notifications,
            iconColor: const Color(0xFF1976D2),
            title: 'menu_calendar'.tr(),
            subtitle: 'menu_calendar_desc'.tr(),
            onTap: onCalendar,
          ),
          const SizedBox(height: 16),
          Divider(thickness: 1, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          _SheetItem(
            icon: Icons.settings_outlined,
            label: 'menu_settings'.tr(),
            onTap: onSettings,
          ),
        ],
      ),
      ),
    );
  }
}

/// Tarjeta de herramienta para el estuche (Importar, Nota, Vencimientos).
///
/// Ícono concreto en círculo blanco con color propio + nombre + frase que
/// explica qué hace — da la sensación de "varias mini-apps", no una lista plana.
class _ToolCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF3F5EC), Color(0xFFD8E0C0)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA2B882), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A8A50).withValues(alpha: 0.40),
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
          borderRadius: BorderRadius.circular(16),
          splashColor: const Color(0xFFA2B882).withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              children: [
                // Ícono concreto en círculo blanco con color propio
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                        color: iconColor.withValues(alpha: 0.35), width: 1.5),
                  ),
                  child: Icon(icon, size: 30, color: iconColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFF3A4A22),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6A7A4A),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right,
                    size: 24, color: const Color(0xFF4A6A28).withValues(alpha: 0.55)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón 3D arena para Configuración
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

// ---------------------------------------------------------------------------
// Botón central (caja de herramientas) — verde degradé, sombra 3D, sin Flutter FAB
// ---------------------------------------------------------------------------

class _CenterAddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CenterAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
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
          child: const Icon(Icons.home_repair_service,
              size: 26, color: Color(0xFF2E7D32)),
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
          colors: [Color(0xFFF3F5EC), Color(0xFFD8E0C0)],
        ),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: const Color(0xFFA2B882), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A8A50).withValues(alpha: 0.40),
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
          splashColor: const Color(0xFFA2B882).withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: const Color(0xFF4A6A28)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Color(0xFF4A6A28),
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
  final bool isProcessingOcr;

  const _RecentDocItem({
    required this.document,
    required this.onTap,
    this.isProcessingOcr = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = DocumentTypeColors.of(document.documentType);
    return Container(
      decoration: BoxDecoration(
        color: scheme.bg.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: scheme.border.withValues(alpha: 0.55),
            offset: const Offset(0, 3),
            blurRadius: 6,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      if (isProcessingOcr) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          SizedBox(
                            width: 11,
                            height: 11,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'status_extracting'.tr(),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
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
          key: ValueKey('${document.filePath}_${document.documentType}_${document.ocrText?.isNotEmpty == true}'),
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
