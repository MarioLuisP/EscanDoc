import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

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
            TextButton.icon(
              icon: const Icon(Icons.share, size: 20, color: Colors.white),
              label: Text(
                'share_button'.tr(),
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              onPressed: () => _onShareTap(context),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
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
              const SizedBox(height: 20),
              Text(
                'share_title'.tr(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              // Botón verde tenue — Como foto (JPG)
              _ShareButton(
                icon: Icons.image_outlined,
                label: 'share_as_photo'.tr(),
                gradientColors: const [Color(0xFFE8F5E8), Color(0xFFC0D8C0)],
                borderColor: const Color(0xFF7AAB7A),
                shadowColor: const Color(0xFF4A7A4A),
                iconColor: const Color(0xFF2E7D32),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareFile(widget.filePath, mimeType: 'image/jpeg');
                },
              ),
              const SizedBox(height: 14),
              // Botón celeste tenue — Como documento (PDF)
              _ShareButton(
                icon: Icons.picture_as_pdf_outlined,
                label: 'share_as_document'.tr(),
                gradientColors: const [Color(0xFFE3F2FD), Color(0xFFB3D4EC)],
                borderColor: const Color(0xFF7AAFC8),
                shadowColor: const Color(0xFF3A7A9A),
                iconColor: const Color(0xFF1565C0),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareAsDocumentPdf(context);
                },
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareFile(String path, {required String mimeType}) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path, mimeType: mimeType)]),
    );
  }

  Future<void> _shareAsDocumentPdf(BuildContext context) async {
    setState(() => _sharing = true);

    File? tempPdf;
    try {
      final imageBytes = await File(widget.filePath).readAsBytes();

      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      const monthKeys = [
        'month_jan','month_feb','month_mar','month_apr',
        'month_may','month_jun','month_jul','month_aug',
        'month_sep','month_oct','month_nov','month_dec',
      ];
      final dateSuffix = '${now.day}${monthKeys[now.month - 1].tr()}';
      final tempPath = '${tempDir.path}/EscanDoc_$dateSuffix.pdf';

      final converter = PdfConverterServiceImpl();
      tempPdf = await converter.convertImageBytesToPdfA4(imageBytes, tempPath);

      if (!mounted) return;
      setState(() => _sharing = false);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(tempPdf.path, mimeType: 'application/pdf')]),
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
    }
    // No borramos el archivo temporal: el OS limpia getTemporaryDirectory()
    // automáticamente. Borrarlo manualmente puede romper el share a la misma app.
  }
}

class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradientColors;
  final Color borderColor;
  final Color shadowColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _ShareButton({
    required this.icon,
    required this.label,
    required this.gradientColors,
    required this.borderColor,
    required this.shadowColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withValues(alpha: 0.38),
              offset: const Offset(0, 4),
              blurRadius: 7,
              spreadRadius: -1,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 32),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
