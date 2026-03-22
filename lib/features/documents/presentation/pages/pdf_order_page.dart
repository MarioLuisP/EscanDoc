import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:escandoc/core/services/pdf_converter_service.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/core/theme/document_type_colors.dart';

/// Pantalla para reordenar documentos antes de exportarlos como PDF multipágina.
///
/// El usuario puede mover páginas con ▲ ▼.
/// Al confirmar, genera el PDF y abre el share sheet.
class PdfOrderPage extends StatefulWidget {
  final List<DocumentModel> documents;

  const PdfOrderPage({super.key, required this.documents});

  @override
  State<PdfOrderPage> createState() => _PdfOrderPageState();
}

class _PdfOrderPageState extends State<PdfOrderPage> {
  late List<DocumentModel> _ordered;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _ordered = List.from(widget.documents);
  }

  void _moveUp(int index) {
    if (index <= 0) return;
    setState(() {
      final item = _ordered.removeAt(index);
      _ordered.insert(index - 1, item);
    });
  }

  void _moveDown(int index) {
    if (index >= _ordered.length - 1) return;
    setState(() {
      final item = _ordered.removeAt(index);
      _ordered.insert(index + 1, item);
    });
  }

  Future<void> _export() async {
    setState(() => _exporting = true);

    File? tempPdf;
    try {
      final jpgPaths = _ordered.map((d) => d.filePath).toList();
      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      const monthKeys = [
        'month_jan','month_feb','month_mar','month_apr',
        'month_may','month_jun','month_jul','month_aug',
        'month_sep','month_oct','month_nov','month_dec',
      ];
      final dateSuffix = '${now.day}${monthKeys[now.month - 1].tr()}';
      final outputPath = '${tempDir.path}/EscanDoc_$dateSuffix.pdf';

      final converter = PdfConverterServiceImpl();
      tempPdf = await converter.convertJpgsToPdf(jpgPaths, outputPath);

      if (!mounted) return;
      setState(() => _exporting = false);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempPdf.path, mimeType: 'application/pdf')],
        ),
      );

      // Volver a la lista. Usamos addPostFrameCallback para asegurarnos
      // de que el share sheet ya terminó antes de navegar.
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      debugPrint('[PdfOrderPage] Error exportando: $e');
      if (!mounted) return;
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('share_error'.tr(),
              style: const TextStyle(fontSize: 16)),
          backgroundColor: Colors.red[700],
        ),
      );
    }
    // No borramos el archivo temporal: si se compartió a la misma app,
    // el intent necesita acceder al path. getTemporaryDirectory() es
    // limpiado por el OS automáticamente.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Expanded(child: _buildList()),
            _buildExportButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 26, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
            tooltip: 'back_button'.tr(),
          ),
          const SizedBox(width: 4),
          Text(
            'pdf_order_title'.tr(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _ordered.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Color(0xFFDDD0B8)),
      itemBuilder: (context, index) {
        final doc = _ordered[index];
        final isFirst = index == 0;
        final isLast = index == _ordered.length - 1;
        final scheme = DocumentTypeColors.of(doc.documentType);

        return Container(
          color: scheme.bg.withValues(alpha: 0.28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Número de posición
                SizedBox(
                  width: 32,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 10),
                // Miniatura
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                    File(doc.filePath),
                    width: 48,
                    height: 58,
                    cacheWidth: 96,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 48,
                      height: 58,
                      color: Colors.grey[200],
                      child: const Icon(Icons.insert_drive_file,
                          size: 24, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Título
                Expanded(
                  child: Text(
                    doc.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Flechas ▲ ▼
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ArrowButton(
                      icon: Icons.keyboard_arrow_up,
                      enabled: !isFirst,
                      onTap: () => _moveUp(index),
                    ),
                    const SizedBox(height: 4),
                    _ArrowButton(
                      icon: Icons.keyboard_arrow_down,
                      enabled: !isLast,
                      onTap: () => _moveDown(index),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExportButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: _exporting
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: CircularProgressIndicator(color: Color(0xFF1565C0)),
              ),
            )
          : _ExportBtn3D(
              label: 'pdf_export_button'
                  .tr(args: [_ordered.length.toString()]),
              onTap: _export,
            ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _ArrowButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xFFF5F0E8)
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled
                ? const Color(0xFFBBAA88)
                : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: const Color(0xFF9A8060).withValues(alpha: 0.30),
                    offset: const Offset(0, 3),
                    blurRadius: 5,
                    spreadRadius: -1,
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 28,
          color: enabled ? const Color(0xFF5A4A30) : Colors.grey[400],
        ),
      ),
    );
  }
}

class _ExportBtn3D extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ExportBtn3D({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F2FD), Color(0xFFB3D4EC)],
          ),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: const Color(0xFF7AAFC8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3A7A9A).withValues(alpha: 0.38),
              offset: const Offset(0, 4),
              blurRadius: 7,
              spreadRadius: -1,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf_outlined,
                color: Color(0xFF1565C0), size: 26),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1565C0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
