import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:pdfrx/pdfrx.dart';

/// Página fullscreen para visualizar documento (JPG o PDF) con zoom
///
/// NOTA: Ahora los documentos se almacenan como JPG por defecto.
/// PDF solo se genera on-demand para compartir/imprimir.
///
/// Botones: compartir, imprimir, cerrar
class PhotoFullscreenPage extends StatelessWidget {
  final String filePath;

  const PhotoFullscreenPage({
    super.key,
    required this.filePath,
  });

  @override
  Widget build(BuildContext context) {
    final isPDF = filePath.toLowerCase().endsWith('.pdf');

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
          // Botón compartir
          IconButton(
            icon: const Icon(Icons.share, size: 24),
            onPressed: () => _shareDocument(context),
            tooltip: 'share_button'.tr(),
          ),
          if (isPDF)
            // Botón imprimir (solo para PDFs)
            IconButton(
              icon: const Icon(Icons.print, size: 24),
              onPressed: () => _printDocument(context),
              tooltip: 'print_tooltip'.tr(),
            ),
        ],
      ),
      body: isPDF ? _buildPdfViewer() : _buildImageViewer(),
    );
  }

  /// Viewer de PDF con todas las páginas y zoom
  Widget _buildPdfViewer() {
    return PdfViewer.file(
      filePath,
      // El viewer por defecto ya incluye zoom, scroll y gestos
    );
  }

  /// Viewer de imagen con zoom
  Widget _buildImageViewer() {
    final file = File(filePath);

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 5.0,
      child: Center(
        child: Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'error_loading'.tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Comparte el documento
  /// TODO: Si es JPG, convertir a PDF on-demand antes de compartir
  void _shareDocument(BuildContext context) {
    // TODO: Implementar con share_plus package
    // Si filePath es JPG: convertir a PDF on-demand, luego compartir
    // Si filePath es PDF: compartir directamente
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Compartir disponible próximamente (convertirá JPG→PDF on-demand)',
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: Colors.grey[800],
      ),
    );
  }

  /// Imprime el documento
  /// TODO: Si es JPG, convertir a PDF on-demand antes de imprimir
  void _printDocument(BuildContext context) {
    // TODO: Implementar impresión con printing package
    // Si filePath es JPG: convertir a PDF on-demand, luego imprimir
    // Si filePath es PDF: imprimir directamente
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Imprimir disponible próximamente (convertirá JPG→PDF on-demand)',
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: Colors.grey[800],
      ),
    );
  }
}
