import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

import 'package:escandoc/core/services/a4_normalizer_service_impl.dart';
import 'package:escandoc/core/services/pdf_converter_service.dart';

/// Página fullscreen para visualizar documento (JPG o PDF) con zoom.
///
/// Botones: compartir, cerrar.
/// Al compartir JPG: pregunta "Como foto" o "Como documento (PDF A4)".
/// Al compartir PDF: comparte directamente.
class PhotoFullscreenPage extends StatefulWidget {
  final String filePath;

  const PhotoFullscreenPage({
    super.key,
    required this.filePath,
  });

  @override
  State<PhotoFullscreenPage> createState() => _PhotoFullscreenPageState();
}

class _PhotoFullscreenPageState extends State<PhotoFullscreenPage> {
  bool _sharing = false;

  bool get _isPDF => widget.filePath.toLowerCase().endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close, size: 28),
          onPressed: () => Navigator.pop(context),
          tooltip: 'back_button'.tr(),
        ),
        actions: [
          if (_sharing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.share, size: 24),
              onPressed: () => _onShareTap(context),
              tooltip: 'share_button'.tr(),
            ),
        ],
      ),
      body: _isPDF ? _buildPdfViewer() : _buildImageViewer(),
    );
  }

  Widget _buildPdfViewer() {
    return PdfViewer.file(widget.filePath);
  }

  Widget _buildImageViewer() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 5.0,
      child: Center(
        child: Image.file(
          File(widget.filePath),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  'error_loading'.tr(),
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Share logic
  // ---------------------------------------------------------------------------

  void _onShareTap(BuildContext context) {
    if (_isPDF) {
      // PDF ya es un documento: compartir directamente
      _shareFile(widget.filePath, mimeType: 'application/pdf');
      return;
    }
    // JPG: preguntar formato
    _showShareSheet(context);
  }

  void _showShareSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF5F0E8),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'share_title'.tr(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            ListTile(
              leading: const Icon(
                Icons.image_outlined,
                color: Color(0xFF388E3C),
                size: 28,
              ),
              title: Text(
                'share_as_photo'.tr(),
                style: const TextStyle(fontSize: 17),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _shareFile(widget.filePath, mimeType: 'image/jpeg');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.picture_as_pdf_outlined,
                color: Color(0xFFD32F2F),
                size: 28,
              ),
              title: Text(
                'share_as_document'.tr(),
                style: const TextStyle(fontSize: 17),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _shareAsDocumentPdf(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _shareFile(String path, {required String mimeType}) async {
    await Share.shareXFiles([XFile(path, mimeType: mimeType)]);
  }

  Future<void> _shareAsDocumentPdf(BuildContext context) async {
    setState(() => _sharing = true);

    File? tempPdf;
    try {
      final imageBytes = await File(widget.filePath).readAsBytes();

      final normalizer = A4NormalizerServiceImpl();
      final normalizedBytes = await normalizer.normalizeToA4(imageBytes);

      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/export_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final converter = PdfConverterServiceImpl();
      tempPdf = await converter.convertImageBytesToPdfA4(
          normalizedBytes, tempPath);

      if (!mounted) return;
      setState(() => _sharing = false);

      await Share.shareXFiles(
        [XFile(tempPdf.path, mimeType: 'application/pdf')],
      );
    } catch (e) {
      debugPrint('[Export] Error al exportar PDF: $e');
      if (!mounted) return;
      setState(() => _sharing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('share_error'.tr(),
              style: const TextStyle(fontSize: 16)),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      // Limpiar PDF temporal después de que share_plus lo haya procesado
      if (tempPdf != null && await tempPdf.exists()) {
        await tempPdf.delete();
      }
    }
  }
}
