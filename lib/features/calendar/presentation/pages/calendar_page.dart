import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:escandoc/features/documents/presentation/providers/documents_provider.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/core/theme/document_type_colors.dart';

/// Calendario de vencimientos.
///
/// Muestra un calendario mensual donde los días con documentos que vencen
/// están marcados. Al tocar un día, se listan los documentos de ese día.
/// El calendario se colapsa al hacer scroll hacia abajo y se expande al volver arriba.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

enum _CalendarState { expanded, collapsed }

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Map<DateTime, int> _expiryCounts = {};
  List<DocumentModel> _docsForDay = [];
  bool _loadingDocs = false;

  _CalendarState _calendarState = _CalendarState.expanded;
  double _fullCalendarHeight = 340.0;
  final GlobalKey _calendarKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  static const double _collapsedFraction = 0.15;

  // ─── Modo asignar ─────────────────────────────────────────────────────────
  int? _assignDocumentId;
  String? _assignDocumentTitle;
  bool get _isAssignMode => _assignDocumentId != null;
  bool _isPickingMode = false; // true = próximo tap en día asigna fecha

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readRouteArgs();
      _measureCalendarHeight();
      _loadExpiryCounts();
      _loadDocsForDay(_selectedDay);
    });
  }

  void _readRouteArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final docId = args['documentId'] as int?;
      final docTitle = args['documentTitle'] as String?;
      final expiryDate = args['currentExpiryDate'] as DateTime?;
      if (docId != null) {
        setState(() {
          _assignDocumentId = docId;
          _assignDocumentTitle = docTitle;
          final focus = expiryDate ?? DateTime.now();
          _focusedDay = focus;
          _selectedDay = focus;
          // Sin fecha → directo a picking. Con fecha → browse normal primero.
          _isPickingMode = expiryDate == null;
        });
        _loadDocsForDay(_selectedDay);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // ─── Lógica de colapso ───────────────────────────────────────────────────

  void _onScroll() {
    final pos = _scrollController.position.pixels;
    if (pos > _fullCalendarHeight / 2 && _calendarState == _CalendarState.expanded) {
      setState(() => _calendarState = _CalendarState.collapsed);
    } else if (pos < 20 && _calendarState == _CalendarState.collapsed) {
      setState(() => _calendarState = _CalendarState.expanded);
    }
  }

  void _measureCalendarHeight() {
    Future.delayed(const Duration(milliseconds: 150), () {
      final box = _calendarKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final h = box.size.height + 16.0;
        if ((h - _fullCalendarHeight).abs() > 5.0) {
          setState(() => _fullCalendarHeight = h);
        }
      }
    });
  }

  // ─── Carga de datos ──────────────────────────────────────────────────────

  Future<void> _loadExpiryCounts() async {
    final start = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
    final end = DateTime(_focusedDay.year, _focusedDay.month + 2, 0);
    final counts = await context.read<DocumentsProvider>().getExpiryCounts(start, end);
    if (mounted) setState(() => _expiryCounts = counts);
  }

  Future<void> _loadDocsForDay(DateTime day) async {
    setState(() => _loadingDocs = true);
    final docs = await context.read<DocumentsProvider>().getDocumentsExpiringOn(day);
    if (mounted) setState(() { _docsForDay = docs; _loadingDocs = false; });
  }

  int _countForDay(DateTime day) =>
      _expiryCounts[DateTime(day.year, day.month, day.day)] ?? 0;

  // ─── Handlers ────────────────────────────────────────────────────────────

  void _onDaySelected(DateTime selected, DateTime focused) {
    setState(() {
      _selectedDay = selected;
      _focusedDay = focused;
    });
    if (_isPickingMode) {
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      if (selected.isBefore(todayOnly)) return; // ignorar días pasados
      _confirmAssign(selected);
    } else {
      _loadDocsForDay(selected);
    }
  }

  Future<void> _confirmAssign(DateTime date) async {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year;
    final formatted = '$d/$m/$y';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFFFDFAF4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month, color: Color(0xFF388E3C), size: 32),
              const SizedBox(height: 12),
              Text(
                'Asignar vencimiento',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                formatted,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF388E3C)),
              ),
              const SizedBox(height: 4),
              Text(
                _assignDocumentTitle ?? '',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _AssignButton(
                    label: 'Cancelar',
                    onTap: () => Navigator.pop(ctx, false),
                    gradientColors: const [Color(0xFFFDFAF4), Color(0xFFE0D4BC)],
                    textColor: const Color(0xFF5A4A30),
                    shadowColor: const Color(0xFF9A8060),
                    border: Border.all(color: const Color(0xFFBBAA88), width: 1.5),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _AssignButton(
                    label: 'Guardar',
                    onTap: () => Navigator.pop(ctx, true),
                    gradientColors: const [Color(0xFF6FBF6F), Color(0xFF2E7D32)],
                    textColor: Colors.white,
                    shadowColor: Color(0xFF1A5C1A),
                  )),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<DocumentsProvider>().updateExpiryDate(_assignDocumentId!, date);
      if (mounted) Navigator.pop(context);
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    EasyLocalization.of(context)?.locale;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isPickingMode ? 'Elegí una fecha' : 'Vencimientos',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade300),
        ),
      ),
      body: Stack(
        children: [
          _buildScrollableContent(),
          _buildCalendarOverlay(),
        ],
      ),

    );
  }

  Widget _buildScrollableContent() {
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: _fullCalendarHeight + 24)),
        if (_loadingDocs)
          const SliverToBoxAdapter(
            child: Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )),
          )
        else if (_docsForDay.isEmpty)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _isPickingMode
                      ? 'Tocá un día para asignar el vencimiento'
                      : 'Sin vencimientos para este día',
                  style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ExpiryDocCard(
                    document: _docsForDay[i],
                    onTap: () async {
                      await Navigator.pushNamed(
                        context,
                        '/document/detail',
                        arguments: _docsForDay[i].id,
                      );
                      _loadDocsForDay(_selectedDay);
                      _loadExpiryCounts();
                    },
                    onChangeTap: (_isAssignMode && !_isPickingMode && _docsForDay[i].id == _assignDocumentId)
                        ? () => setState(() => _isPickingMode = true)
                        : null,
                  ),
                ),
                childCount: _docsForDay.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCalendarOverlay() {
    return Positioned(
      top: 8,
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: () {
          if (_calendarState == _CalendarState.collapsed) {
            setState(() => _calendarState = _CalendarState.expanded);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _calendarState == _CalendarState.collapsed
                ? _buildCollapsedHeader()
                : _buildFullCalendar(),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedHeader() {
    return SizedBox(
      height: _fullCalendarHeight * _collapsedFraction,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Calendario',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
            Text(
              '${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF388E3C)),
            ),
            const Icon(Icons.expand_more, color: Colors.black38, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFullCalendar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TableCalendar(
        key: _calendarKey,
        locale: 'es_ES',
        firstDay: DateTime(2020, 1, 1),
        lastDay: DateTime(2035, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        enabledDayPredicate: _isPickingMode
            ? (day) {
                final today = DateTime.now();
                final todayOnly = DateTime(today.year, today.month, today.day);
                return !day.isBefore(todayOnly);
              }
            : null,
        onDaySelected: _onDaySelected,
        onFormatChanged: (format) {
          setState(() => _calendarFormat = format);
          WidgetsBinding.instance.addPostFrameCallback((_) => _measureCalendarHeight());
        },
        onPageChanged: (focused) {
          setState(() => _focusedDay = focused);
          _loadExpiryCounts();
          WidgetsBinding.instance.addPostFrameCallback((_) => _measureCalendarHeight());
        },
        daysOfWeekHeight: 20,
        rowHeight: 34,
        sixWeekMonthsEnforced: false,
        availableCalendarFormats: const {
          CalendarFormat.month: 'Mes',
          CalendarFormat.twoWeeks: '2 sem',
          CalendarFormat.week: 'Sem',
        },
        headerStyle: HeaderStyle(
          formatButtonVisible: true,
          formatButtonShowsNext: false,
          titleCentered: true,
          titleTextStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          formatButtonTextStyle: const TextStyle(color: Colors.white, fontSize: 12),
          formatButtonDecoration: BoxDecoration(
            color: const Color(0xFF388E3C),
            borderRadius: BorderRadius.circular(8),
          ),
          leftChevronPadding: const EdgeInsets.all(4),
          rightChevronPadding: const EdgeInsets.all(4),
        ),
        calendarStyle: const CalendarStyle(
          todayDecoration: BoxDecoration(
            color: Color(0xFFC8E6C9),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          selectedDecoration: BoxDecoration(
            color: Color(0xFF388E3C),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          defaultDecoration: BoxDecoration(
            color: Color(0xFFEEEEEE),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          weekendDecoration: BoxDecoration(
            color: Color(0xFFEEEEEE),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          outsideDecoration: BoxDecoration(
            color: Color(0xFFEEEEEE),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          todayTextStyle: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
          selectedTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          defaultTextStyle: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
          weekendTextStyle: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
          outsideTextStyle: TextStyle(color: Colors.black38, fontWeight: FontWeight.bold),
          disabledDecoration: BoxDecoration(
            color: Color(0xFFEEEEEE),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          disabledTextStyle: TextStyle(color: Colors.black26, fontWeight: FontWeight.bold),
        ),
        calendarBuilders: CalendarBuilders(
          // Día normal con vencimientos → naranja
          defaultBuilder: (context, day, focused) {
            final count = _countForDay(day);
            if (count == 0) return null;
            return _DayCell(day: day, color: const Color(0xFFFFB74D), textColor: Colors.black87);
          },
          // Hoy con vencimientos → verde oscuro
          todayBuilder: (context, day, focused) {
            final isSelected = isSameDay(_selectedDay, day);
            final count = _countForDay(day);
            final color = isSelected
                ? const Color(0xFF388E3C)
                : count > 0
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFC8E6C9);
            final textColor = (isSelected || count > 0) ? Colors.white : Colors.black87;
            return _DayCell(day: day, color: color, textColor: textColor,
                border: isSelected ? null : const Border.fromBorderSide(
                  BorderSide(color: Color(0xFF388E3C), width: 2)));
          },
          // Día seleccionado con vencimientos → verde más oscuro
          selectedBuilder: (context, day, focused) {
            if (isSameDay(day, DateTime.now())) return null;
            final count = _countForDay(day);
            final color = count > 0 ? const Color(0xFF1B5E20) : const Color(0xFF388E3C);
            return _DayCell(day: day, color: color, textColor: Colors.white);
          },
          // Badge con cantidad
          markerBuilder: (context, date, events) {
            final count = _countForDay(date);
            if (count == 0) return null;
            return Positioned(
              left: 0,
              bottom: 2,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE65100),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Center(
                  child: Text(
                    '$count',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            );
          },
        ),
        eventLoader: (day) {
          final count = _countForDay(day);
          return List.generate(count, (i) => i);
        },
      ),
    );
  }
}

// ─── Celda de día del calendario ────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final DateTime day;
  final Color color;
  final Color textColor;
  final BoxBorder? border;

  const _DayCell({
    required this.day,
    required this.color,
    required this.textColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.only(bottom: 1),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: border,
        ),
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }
}

// ─── Card de documento en la lista inferior ──────────────────────────────────

class _ExpiryDocCard extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback onTap;
  final VoidCallback? onChangeTap; // si no null → muestra botón "Cambiar fecha"

  const _ExpiryDocCard({required this.document, required this.onTap, this.onChangeTap});

  @override
  Widget build(BuildContext context) {
    final scheme = DocumentTypeColors.of(document.documentType);
    final expiry = document.expiryDate!;
    final daysLeft = expiry.difference(DateTime.now()).inDays;
    final urgencyColor = daysLeft <= 7
        ? Colors.red[700]!
        : daysLeft <= 30
            ? Colors.orange[700]!
            : const Color(0xFF388E3C);

    return Container(
      decoration: BoxDecoration(
        color: scheme.bg.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.border),
        boxShadow: [
          BoxShadow(
            color: scheme.border.withValues(alpha: 0.40),
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
                // Miniatura
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(document.filePath),
                    width: 52,
                    height: 62,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 52,
                      height: 62,
                      color: Colors.grey[200],
                      child: const Icon(Icons.insert_drive_file, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.title,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black87),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: urgencyColor),
                          const SizedBox(width: 4),
                          Text(
                            _formatExpiry(expiry, daysLeft),
                            style: TextStyle(fontSize: 14, color: urgencyColor, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      if (onChangeTap != null) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: onChangeTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF6FBF6F), Color(0xFF2E7D32)],
                              ),
                              borderRadius: BorderRadius.circular(50),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1A5C1A).withValues(alpha: 0.45),
                                  offset: const Offset(0, 3),
                                  blurRadius: 6,
                                  spreadRadius: -1,
                                ),
                              ],
                            ),
                            child: const Text(
                              'Cambiar fecha',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatExpiry(DateTime date, int daysLeft) {
    if (daysLeft == 0) return 'Vence hoy';
    if (daysLeft == 1) return 'Vence mañana';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = (date.year % 100).toString().padLeft(2, '0');
    if (daysLeft < 0) return 'Venció el $d/$m/$y';
    return 'Vence el $d/$m/$y';
  }
}

// ─── Botón 3D para el diálogo de asignación ──────────────────────────────────

class _AssignButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final List<Color> gradientColors;
  final Color textColor;
  final Color shadowColor;
  final BoxBorder? border;

  const _AssignButton({
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
    );
  }
}
