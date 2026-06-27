import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/presentation/providers/documents_provider.dart';
import 'package:escandoc/features/documents/presentation/providers/import_provider.dart';
import 'package:escandoc/core/theme/document_type_colors.dart';
import 'package:escandoc/features/documents/presentation/pages/pdf_order_page.dart';

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

/// Pantalla "Ver Todos" — lista completa de documentos con filtro de orden
/// y modo selección múltiple (long-press).
class DocumentsListPage extends StatefulWidget {
  const DocumentsListPage({super.key});

  @override
  State<DocumentsListPage> createState() => _DocumentsListPageState();
}

class _DocumentsListPageState extends State<DocumentsListPage> {
  _SortOrder _sort = _SortOrder.recent;

  // --- Modo selección ---
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

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
        return list;
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

  // --- Selección ---

  void _enterSelectionMode(int docId) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(docId);
    });
  }

  /// Entra en modo selección sin preseleccionar nada (botón "Seleccionar").
  /// El usuario luego toca documentos para elegir uno o varios.
  void _startSelection() {
    setState(() {
      _selectionMode = true;
    });
  }

  void _toggleSelection(int docId) {
    setState(() {
      if (_selectedIds.contains(docId)) {
        _selectedIds.remove(docId);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(docId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    final allDocs = context.read<DocumentsProvider>().documents;

    // Expandir la selección a sus grupos (páginas de un mismo PDF multipágina).
    final groupExpanded = _expandToGroups(allDocs, _selectedIds);
    final hasUnselectedSiblings = groupExpanded.length > _selectedIds.length;

    final List<int> idsToDelete;
    if (hasUnselectedSiblings) {
      // La selección toca un grupo con páginas no seleccionadas → preguntar.
      final scope = await _showGroupDeleteDialog(
        selectedCount: _selectedIds.length,
        groupCount: groupExpanded.length,
      );
      if (scope == null || !mounted) return; // Canceló
      idsToDelete = scope == _DeleteScope.group
          ? groupExpanded.toList()
          : List<int>.from(_selectedIds);
    } else {
      // Sin grupo de por medio → confirmación normal.
      final count = _selectedIds.length;
      final title = count == 1
          ? 'delete_confirm_title'.tr()
          : 'delete_confirm_many'.tr(args: [count.toString()]);
      final confirmed = await _showDeleteConfirmation(title);
      if (confirmed != true || !mounted) return;
      idsToDelete = List<int>.from(_selectedIds);
    }

    final provider = context.read<DocumentsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final count = idsToDelete.length;

    _exitSelectionMode();

    for (final id in idsToDelete) {
      await provider.deleteDocument(id);
    }

    if (!mounted) return;
    final msg = count == 1
        ? 'document_deleted'.tr()
        : 'documents_deleted'.tr(args: [count.toString()]);
    messenger.showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 16)),
      duration: const Duration(seconds: 3),
    ));
  }

  // --- Agrupación de páginas de PDF multipágina ---
  //
  // No hay un "grupo" en la BD: las páginas de un PDF importado se guardan como
  // documentos sueltos. Se infiere el grupo por dos señales combinadas:
  //   1. Título con patrón `base_N` (ej. "tutorial_1", "tutorial_2"…).
  //   2. createdAt dentro de la misma ráfaga de import (ventana de tolerancia).
  // Combinarlas evita falsos positivos (un doc suelto "cosa_3" de otro día no se
  // agrupa con un "cosa_1" importado hoy).

  static final RegExp _groupPattern = RegExp(r'^(.+)_(\d+)$');
  static const Duration _groupWindow = Duration(minutes: 2);

  /// Prefijo de grupo de un título `base_N`, o null si no matchea el patrón.
  String? _groupBase(String title) => _groupPattern.firstMatch(title)?.group(1);

  /// Expande [selectedIds] incluyendo las páginas hermanas del mismo grupo.
  /// Si ningún seleccionado pertenece a un grupo, devuelve la misma selección.
  Set<int> _expandToGroups(List<DocumentModel> all, Set<int> selectedIds) {
    final result = Set<int>.from(selectedIds);
    final selectedDocs = all.where((d) => selectedIds.contains(d.id));
    for (final doc in selectedDocs) {
      final base = _groupBase(doc.title);
      if (base == null) continue;
      for (final other in all) {
        if (other.id == null) continue;
        if (_groupBase(other.title) == base &&
            other.createdAt.difference(doc.createdAt).abs() <= _groupWindow) {
          result.add(other.id!);
        }
      }
    }
    return result;
  }

  /// Diálogo de elección cuando la selección toca un grupo de PDF.
  /// Devuelve el alcance elegido, o null si cancela.
  Future<_DeleteScope?> _showGroupDeleteDialog({
    required int selectedCount,
    required int groupCount,
  }) {
    return showDialog<_DeleteScope>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFFFDFAF4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'delete_group_title'.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'delete_group_message'.tr(),
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: _DeleteDialogButton(
                  label: 'delete_only_selected'.tr(args: [selectedCount.toString()]),
                  onTap: () => Navigator.pop(ctx, _DeleteScope.selected),
                  gradientColors: const [Color(0xFFFDFAF4), Color(0xFFE0D4BC)],
                  textColor: const Color(0xFF5A4A30),
                  shadowColor: const Color(0xFF9A8060),
                  border: Border.all(color: const Color(0xFFBBAA88), width: 1.5),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _DeleteDialogButton(
                  label: 'delete_whole_group'.tr(args: [groupCount.toString()]),
                  onTap: () => Navigator.pop(ctx, _DeleteScope.group),
                  gradientColors: [Colors.red[400]!, Colors.red[800]!],
                  textColor: Colors.white,
                  shadowColor: Colors.red[900]!,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _DeleteDialogButton(
                  label: 'cancel_button'.tr(),
                  onTap: () => Navigator.pop(ctx, null),
                  gradientColors: const [Color(0xFFFDFAF4), Color(0xFFE0D4BC)],
                  textColor: const Color(0xFF5A4A30),
                  shadowColor: const Color(0xFF9A8060),
                  border: Border.all(color: const Color(0xFFBBAA88), width: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(String title) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFFFDFAF4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'delete_confirm_message'.tr(),
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _DeleteDialogButton(
                      label: 'delete_no_button'.tr(),
                      onTap: () => Navigator.pop(ctx, false),
                      gradientColors: const [Color(0xFFFDFAF4), Color(0xFFE0D4BC)],
                      textColor: const Color(0xFF5A4A30),
                      shadowColor: const Color(0xFF9A8060),
                      border: Border.all(color: const Color(0xFFBBAA88), width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DeleteDialogButton(
                      label: 'delete_yes_button'.tr(),
                      onTap: () => Navigator.pop(ctx, true),
                      gradientColors: [Colors.red[400]!, Colors.red[800]!],
                      textColor: Colors.white,
                      shadowColor: Colors.red[900]!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    context.locale;
    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelectionMode();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F0E8),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCompactHeader(),
              _buildTitleRow(),
              if (!_selectionMode) _buildSortBar(context),
              Expanded(child: _buildList(context)),
              _buildBottomBar(context),
            ],
          ),
        ),
      ),
    );
  }

  // --- Header compacto ---

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
    if (_selectionMode) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, size: 26, color: Colors.black87),
              onPressed: _exitSelectionMode,
              tooltip: 'cancel_button'.tr(),
            ),
            const SizedBox(width: 4),
            Text(
              'selection_count'.tr(args: [_selectedIds.length.toString()]),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      );
    }

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
                  colors: [Color(0xFFF3F5EC), Color(0xFFD8E0C0)],
                ),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: const Color(0xFFA2B882), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6A8A50).withValues(alpha: 0.40),
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
                        color: Color(0xFF4A6A28),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: Color(0xFF4A6A28),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          _buildSelectButton(),
        ],
      ),
    );
  }

  /// Botón celeste para entrar al modo selección de forma explícita.
  Widget _buildSelectButton() {
    return GestureDetector(
      onTap: _startSelection,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF4FB), Color(0xFFB8D8EC)],
          ),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: const Color(0xFF7AAFC8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3A7A9A).withValues(alpha: 0.40),
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
              const Icon(
                Icons.checklist_rounded,
                size: 18,
                color: Color(0xFF1565C0),
              ),
              const SizedBox(width: 6),
              Text(
                'select_button'.tr(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1565C0),
                ),
              ),
            ],
          ),
        ),
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
              final isSelected = _selectedIds.contains(doc.id);
              return _DocItem(
                document: doc,
                isProcessingOcr: importProvider.processingOcrIds.contains(doc.id),
                isSelected: isSelected,
                selectionMode: _selectionMode,
                onTap: _selectionMode
                    ? () => _toggleSelection(doc.id!)
                    : () => _navigateToDetail(doc.id!),
                onLongPress: _selectionMode
                    ? null
                    : () => _enterSelectionMode(doc.id!),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    if (_selectionMode) {
      return _buildSelectionBar(context);
    }
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

  Widget _buildSelectionBar(BuildContext context) {
    final hasSelection = _selectedIds.isNotEmpty;
    final canExport = _selectedIds.length >= 2;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8),
        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!hasSelection)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'selection_hint'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          if (canExport) ...[
            _Btn3D(
              icon: Icons.picture_as_pdf_outlined,
              label: 'create_pdf_button'.tr(),
              gradientColors: const [Color(0xFFE3F2FD), Color(0xFFB3D4EC)],
              borderColor: const Color(0xFF7AAFC8),
              shadowColor: const Color(0xFF3A7A9A),
              iconColor: const Color(0xFF1565C0),
              onTap: _openPdfOrder,
            ),
            const SizedBox(height: 10),
          ],
          if (hasSelection)
            _Btn3D(
              icon: Icons.delete_outline,
              label: 'delete_button'.tr(),
              gradientColors: const [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
              borderColor: const Color(0xFFE57373),
              shadowColor: const Color(0xFFD32F2F),
              iconColor: const Color(0xFFD32F2F),
              onTap: _deleteSelected,
            ),
        ],
      ),
    );
  }

  void _openPdfOrder() {
    final provider = context.read<DocumentsProvider>();
    // Mantener el orden de la lista actual (sort aplicado).
    // NO salir del modo selección → el usuario puede volver y ajustar.
    final docs = _sorted(provider.documents)
        .where((d) => _selectedIds.contains(d.id))
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PdfOrderPage(documents: docs)),
    );
  }

  // --- Lógica ---

  void _navigateToDetail(int documentId) async {
    await Navigator.pushNamed(context, '/document/detail',
        arguments: documentId);
    if (!mounted) return;
    context.read<DocumentsProvider>().loadDocuments();
  }
}

// ---------------------------------------------------------------------------
// Widgets privados
// ---------------------------------------------------------------------------

/// Alcance del borrado cuando la selección toca un grupo de PDF multipágina.
enum _DeleteScope { selected, group }

class _DocItem extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isProcessingOcr;
  final bool isSelected;
  final bool selectionMode;

  const _DocItem({
    required this.document,
    required this.onTap,
    this.onLongPress,
    this.isProcessingOcr = false,
    this.isSelected = false,
    this.selectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = DocumentTypeColors.of(document.documentType);

    // En modo selección: fondo verde tenue si está seleccionado
    final bgColor = isSelected
        ? const Color(0xFFD7EDD7)
        : scheme.bg.withValues(alpha: 0.38);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      color: bgColor,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              // Checkbox animado en modo selección
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: selectionMode
                    ? Padding(
                        key: const ValueKey('checkbox'),
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 28,
                          color: isSelected
                              ? const Color(0xFF388E3C)
                              : Colors.grey[400],
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('no-checkbox')),
              ),
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
                          'status_extracting'.tr(),
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
              if (!selectionMode)
                _TypeChip(
                  documentType: document.documentType,
                  typeKey: _docTypeKey(document.documentType),
                ),
            ],
          ),
        ),
      ),
    );
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
          key: ValueKey('${document.filePath}_${document.documentType}_${document.ocrText?.isNotEmpty == true}'),
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

/// Botón 3D genérico con gradiente, borde y sombra.
/// Usado en selección (eliminar), confirmación y futuro export.
class _Btn3D extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradientColors;
  final Color borderColor;
  final Color shadowColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _Btn3D({
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
          borderRadius: BorderRadius.circular(50),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(width: 12),
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

/// Botón con gradiente verde oliva + borde + sombra 3D.
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

class _DeleteDialogButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final List<Color> gradientColors;
  final Color textColor;
  final Color shadowColor;
  final BoxBorder? border;

  const _DeleteDialogButton({
    required this.label,
    required this.onTap,
    required this.gradientColors,
    required this.textColor,
    required this.shadowColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(50),
        border: border,
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.50),
            offset: const Offset(0, 4),
            blurRadius: 8,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          splashColor: Colors.white24,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
