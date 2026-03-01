import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/presentation/providers/documents_provider.dart';
import 'package:escandoc/features/documents/presentation/providers/import_provider.dart';
import 'package:escandoc/features/documents/presentation/widgets/delete_confirmation_dialog.dart';
import 'package:escandoc/core/theme/document_type_colors.dart';

/// Retorna la clave i18n del tipo de documento a partir del campo documentType.
String _docTypeKey(String? documentType) {
  const known = {
    'documento', 'foto', 'folleto', 'manuscrito', 'recibo', 'factura', 'nota',
  };
  final type = documentType?.toLowerCase() ?? '';
  return known.contains(type) ? 'doc_type_$type' : 'doc_type_documento';
}

// ---------------------------------------------------------------------------

enum _SortOrder { recent, oldest, byName, byType }

/// Pantalla "Ver Todos" — lista completa de documentos con filtro de orden.
class DocumentsListPage extends StatefulWidget {
  const DocumentsListPage({super.key});

  @override
  State<DocumentsListPage> createState() => _DocumentsListPageState();
}

class _DocumentsListPageState extends State<DocumentsListPage> {
  _SortOrder _sort = _SortOrder.recent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DocumentsProvider>().loadDocuments();
    });
  }

  List<DocumentModel> _sorted(List<DocumentModel> docs) {
    final list = [...docs];
    switch (_sort) {
      case _SortOrder.recent:
        return list; // ya viene DESC por created_at
      case _SortOrder.oldest:
        return list.reversed.toList();
      case _SortOrder.byName:
        return list..sort((a, b) => a.title.compareTo(b.title));
      case _SortOrder.byType:
        return list..sort((a, b) =>
            _docTypeKey(a.documentType).compareTo(_docTypeKey(b.documentType)));
    }
  }

  String get _sortLabel {
    switch (_sort) {
      case _SortOrder.recent:  return 'sort_recent'.tr();
      case _SortOrder.oldest:  return 'sort_oldest'.tr();
      case _SortOrder.byName:  return 'sort_name'.tr();
      case _SortOrder.byType:  return 'sort_type'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    context.locale; // Registra dependencia en EasyLocalization → rebuild al cambiar idioma
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCompactHeader(),
            _buildTitleRow(),
            _buildSortBar(context),
            Expanded(child: _buildList(context)),
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  // --- Header compacto (logo pequeño, igual en todas las sub-pantallas) ---

  Widget _buildCompactHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/logo.png', width: 38, height: 38),
          const SizedBox(width: 8),
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Escan',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF388E3C),
                  ),
                ),
                TextSpan(
                  text: 'Docs',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Text(
        'all_documents_title'.tr(),
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildSortBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showSortMenu(context),
            child: Container(
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
                    color: const Color(0xFF9A8060).withValues(alpha: 0.40),
                    offset: const Offset(0, 3),
                    blurRadius: 6,
                    spreadRadius: -1,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _sortLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF5A4A30),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: Color(0xFF5A4A30),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSortMenu(BuildContext context) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<_SortOrder>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFFFDFAF4),
      items: [
        _sortItem(_SortOrder.recent,  Icons.schedule,      'sort_recent'.tr()),
        _sortItem(_SortOrder.oldest,  Icons.history,       'sort_oldest'.tr()),
        _sortItem(_SortOrder.byName,  Icons.sort_by_alpha, 'sort_name'.tr()),
        _sortItem(_SortOrder.byType,  Icons.label_outline, 'sort_type'.tr()),
      ],
    );

    if (selected == null || !mounted) return;
    setState(() => _sort = selected);
  }

  PopupMenuItem<_SortOrder> _sortItem(
      _SortOrder value, IconData icon, String label) {
    final selected = _sort == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: selected
                  ? const Color(0xFF388E3C)
                  : const Color(0xFF5A4A30)),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.normal,
              color: selected
                  ? const Color(0xFF388E3C)
                  : const Color(0xFF5A4A30),
            ),
          ),
          if (selected) ...[
            const Spacer(),
            const Icon(Icons.check, size: 16, color: Color(0xFF388E3C)),
          ],
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    return Consumer<DocumentsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && !provider.hasDocuments) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!provider.hasDocuments) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description_outlined,
                      size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'documents_empty'.tr(),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final docs = _sorted(provider.documents);

        return RefreshIndicator(
          onRefresh: () => provider.loadDocuments(),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFDDD0B8)),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final importProvider = context.watch<ImportProvider>();
              return _DocItem(
                document: doc,
                isProcessingOcr: importProvider.processingOcrIds.contains(doc.id),
                onTap: () => _navigateToDetail(doc.id!),
                onLongPress: () => _showDeleteDialog(doc.id!),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8),
        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _GradientOutlineButton(
              icon: Icons.home_outlined,
              label: 'go_home'.tr(),
              onTap: () => Navigator.pop(context),
            ),
          ),
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
    );
  }

  // --- Lógica ---

  void _navigateToDetail(int documentId) async {
    await Navigator.pushNamed(context, '/document/detail',
        arguments: documentId);
    if (!mounted) return;
    context.read<DocumentsProvider>().loadDocuments();
  }

  void _showDeleteDialog(int documentId) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await DeleteConfirmationDialog.show(context);
    if (confirmed != true || !mounted) return;
    final success =
        await context.read<DocumentsProvider>().deleteDocument(documentId);
    if (!success || !mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text('document_deleted'.tr(),
          style: const TextStyle(fontSize: 16)),
      duration: const Duration(seconds: 3),
    ));
  }
}

// ---------------------------------------------------------------------------
// Widgets privados
// ---------------------------------------------------------------------------

class _DocItem extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isProcessingOcr;

  const _DocItem({
    required this.document,
    required this.onTap,
    required this.onLongPress,
    this.isProcessingOcr = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = DocumentTypeColors.of(document.documentType);
    return Ink(
      color: scheme.bg.withValues(alpha: 0.38),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            _buildThumbnail(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatDate(document.createdAt),
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  if (isProcessingOcr) ...[
                    const SizedBox(height: 3),
                    Row(children: [
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Leyendo texto...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            _TypeChip(documentType: document.documentType, typeKey: _docTypeKey(document.documentType)),
          ],
        ),
      ),
    ));
  }

  Widget _buildThumbnail() {
    return Container(
      width: 56,
      height: 66,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(document.filePath),
          width: 56,
          height: 66,
          cacheWidth: 140,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.insert_drive_file,
            size: 28,
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

class _TypeChip extends StatelessWidget {
  final String? documentType;
  final String typeKey;
  const _TypeChip({required this.documentType, required this.typeKey});

  @override
  Widget build(BuildContext context) {
    final label = typeKey.tr();
    final display = label.isEmpty
        ? label
        : label[0].toUpperCase() + label.substring(1);
    final scheme = DocumentTypeColors.of(documentType);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.bg,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: scheme.border, width: 1),
      ),
      child: Text(
        display,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: scheme.fg,
        ),
      ),
    );
  }
}

/// Botón con gradiente crema + borde + sombra 3D.
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
                    fontSize: 20,
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
