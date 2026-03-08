import 'dart:math';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONTRATO
// Entrada : List<TextBlock> de MLKit + DocumentType + rotationDegrees (ya calculado)
// Salida  : String Markdown con estructura detectada automáticamente
// ─────────────────────────────────────────────────────────────────────────────

enum DocumentType { documento, factura, folleto, recibo, manuscrito }

// Umbral de gap para separar columnas: 25% del ancho total.
const double _kColumnGapThreshold = 0.25;

// Mínimo de líneas para que un cluster sea considerado columna válida.
const int _kMinLinesPerColumn = 3;

String blocksToMarkdown(
  List<TextBlock> blocks,
  DocumentType docType,
  int rotationDegrees,
) {
  if (blocks.isEmpty) return '';

  // ── 1. imageSize desde max de bboxes ────────────────────────────────────
  final imageWidth  = blocks.map((b) => b.boundingBox.right).reduce(max);
  final imageHeight = blocks.map((b) => b.boundingBox.bottom).reduce(max);

  // ── 2. Rotación ya detectada por el caller ───────────────────────────────
  final rotation = _rotationFromDegrees(rotationDegrees);

  // ── 3. Aplanar a _Line con coordenadas transformadas ────────────────────
  final lines = <_Line>[];
  for (final block in blocks) {
    for (final line in block.lines) {
      final bbox = line.boundingBox;
      final (readTop, readLeft) = _transform(
        bbox.top, bbox.left, bbox.bottom, bbox.right,
        rotation, imageWidth, imageHeight,
      );
      final isRotated = rotation == _Rotation.deg90 || rotation == _Rotation.deg270;
      lines.add(_Line(
        text:       line.text,
        readTop:    readTop,
        readLeft:   readLeft,
        readHeight: isRotated ? bbox.width  : bbox.height,
        readWidth:  isRotated ? bbox.height : bbox.width,
        lineCount:  block.lines.length,
      ));
    }
  }

  if (lines.isEmpty) return '';

  final totalReadWidth = lines.map((l) => l.readLeft + l.readWidth).reduce(max);

  // ── 4. Separar líneas anchas (títulos/sección) de narrow (columnas) ──────
  // Las wide lines (readWidth > 50%) actúan de puente entre columnas y
  // destruyen el clustering si se incluyen. Se renderizan aparte, intercaladas
  // por posición vertical.
  bool isWideSeparator(_Line l) {
    final t = l.text.trim();
    return l.readWidth > totalReadWidth * 0.5 &&
        t == t.toUpperCase() &&
        t.contains(RegExp(r'[A-ZÁÉÍÓÚÑ]'));
  }

  final wideLines   = lines.where(isWideSeparator).toList()
    ..sort((a, b) => a.readTop.compareTo(b.readTop));
  final narrowLines = lines.where((l) => !isWideSeparator(l)).toList();

  // ── 5. maxCapsHeight para jerarquía ALL_CAPS ────────────────────────────
  // Comparación directa contra el máximo: >= 80% → #, >= 50% → ##, resto → ###
  final maxCapsHeight = lines.fold(0.0, (m, l) {
    final t = l.text.trim();
    return (t == t.toUpperCase() && t.contains(RegExp(r'[A-ZÁÉÍÓÚÑ]')))
        ? max(m, l.readHeight)
        : m;
  });

  // ── 6. Renderizar: wide lines como divisores de bandas verticales ────────
  final buffer = StringBuffer();
  double bandStart = -double.infinity;

  for (final wide in wideLines) {
    // Narrow lines que caen en la banda anterior a esta wide line
    final band = narrowLines.where((l) => l.readTop >= bandStart && l.readTop < wide.readTop).toList();
    if (band.isNotEmpty) {
      _renderBand(buffer, band, docType, totalReadWidth, maxCapsHeight);
    }
    // Insertar la wide line como texto jerárquico
    final formatted = _formatLine(wide, maxCapsHeight);
    if (formatted.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln(formatted);
    }
    bandStart = wide.readTop;
  }

  // Última banda: narrow lines después de la última wide line (o todas si no hay wide)
  final remaining = narrowLines.where((l) => l.readTop >= bandStart).toList();
  if (remaining.isNotEmpty) {
    if (buffer.isNotEmpty) buffer.writeln();
    _renderBand(buffer, remaining, docType, totalReadWidth, maxCapsHeight);
  }

  return buffer.toString().trim();
}

/// Mapea el string del clasificador TFLite → DocumentType
DocumentType documentTypeFromString(String label) {
  switch (label) {
    case 'factura':    return DocumentType.factura;
    case 'folleto':    return DocumentType.folleto;
    case 'recibo':     return DocumentType.recibo;
    case 'manuscrito': return DocumentType.manuscrito;
    default:           return DocumentType.documento;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIPOS INTERNOS
// ─────────────────────────────────────────────────────────────────────────────

enum _Rotation { deg0, deg90, deg180, deg270 }

class _Line {
  final String text;
  final double readTop;
  final double readLeft;
  final double readHeight;
  final double readWidth;
  final int    lineCount;

  const _Line({
    required this.text,
    required this.readTop,
    required this.readLeft,
    required this.readHeight,
    required this.readWidth,
    required this.lineCount,
  });
}

_Rotation _rotationFromDegrees(int deg) {
  switch (deg) {
    case 90:  return _Rotation.deg90;
    case 180: return _Rotation.deg180;
    case 270: return _Rotation.deg270;
    default:  return _Rotation.deg0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRANSFORMACIÓN DE COORDENADAS
// ─────────────────────────────────────────────────────────────────────────────

(double readTop, double readLeft) _transform(
  double top, double left, double bottom, double right,
  _Rotation rotation, double imgW, double imgH,
) {
  switch (rotation) {
    case _Rotation.deg0:   return (top,         left);
    case _Rotation.deg90:  return (left,         imgH - bottom);
    case _Rotation.deg180: return (imgH - bottom, imgW - right);
    case _Rotation.deg270: return (imgW - right,  top);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RENDERIZADO DE BANDA
// Una banda es el conjunto de narrow lines entre dos wide lines consecutivas.
// ─────────────────────────────────────────────────────────────────────────────

void _renderBand(
  StringBuffer buffer,
  List<_Line> lines,
  DocumentType docType,
  double totalReadWidth,
  double maxCapsHeight,
) {
  final columns = _clusterColumns(lines, totalReadWidth);
  final isStructured = docType == DocumentType.factura || docType == DocumentType.recibo;

  if (columns.length > 1 && isStructured) {
    _buildTableMarkdown(buffer, columns);
  } else if (columns.length > 1) {
    _buildInlineColumns(buffer, columns, maxCapsHeight);
  } else {
    _appendColumnMarkdown(buffer, columns.isEmpty ? lines : columns.first, maxCapsHeight);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CLUSTERING DE COLUMNAS
//
// FIX 2a — Referencia: centro del bbox (readLeft + readWidth/2).
// FIX 2b — Densidad mínima: clusters con < _kMinLinesPerColumn líneas
//           se colapsan a la columna válida más cercana.
// Nota: las wide lines ya fueron separadas antes de llegar aquí.
// ─────────────────────────────────────────────────────────────────────────────

double _centerX(_Line l) => l.readLeft + l.readWidth / 2;

List<List<_Line>> _clusterColumns(List<_Line> lines, double totalWidth) {
  if (lines.isEmpty) return [];
  if (totalWidth <= 0) return [lines];

  final threshold = totalWidth * _kColumnGapThreshold;
  final sorted = List<_Line>.from(lines)
    ..sort((a, b) => _centerX(a).compareTo(_centerX(b)));

  final columnCenters = <double>[_centerX(sorted.first)];
  for (int i = 1; i < sorted.length; i++) {
    final gap = _centerX(sorted[i]) - _centerX(sorted[i - 1]);
    if (gap > threshold) {
      final alreadyExists = columnCenters.any(
        (c) => (c - _centerX(sorted[i])).abs() < threshold,
      );
      if (!alreadyExists) columnCenters.add(_centerX(sorted[i]));
    }
  }

  // Asignación: cada línea → columna de centro más cercano
  final rawColumns = List.generate(columnCenters.length, (_) => <_Line>[]);
  for (final line in lines) {
    int best = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < columnCenters.length; i++) {
      final dist = (_centerX(line) - columnCenters[i]).abs();
      if (dist < bestDist) { bestDist = dist; best = i; }
    }
    rawColumns[best].add(line);
  }

  // FIX 2b — Eliminar columnas fantasma por densidad insuficiente
  final validIndices = <int>[];
  for (int i = 0; i < rawColumns.length; i++) {
    if (rawColumns[i].length >= _kMinLinesPerColumn) validIndices.add(i);
  }

  final columns = validIndices.isEmpty
      ? rawColumns
      : List.generate(validIndices.length, (i) => List<_Line>.from(rawColumns[validIndices[i]]));

  // Reasignar líneas de columnas descartadas a la válida más cercana
  if (validIndices.isNotEmpty && validIndices.length < rawColumns.length) {
    final validCenters = validIndices.map((i) => columnCenters[i]).toList();
    for (int i = 0; i < rawColumns.length; i++) {
      if (validIndices.contains(i)) continue;
      for (final line in rawColumns[i]) {
        int best = 0;
        double bestDist = double.infinity;
        for (int j = 0; j < validCenters.length; j++) {
          final dist = (_centerX(line) - validCenters[j]).abs();
          if (dist < bestDist) { bestDist = dist; best = j; }
        }
        columns[best].add(line);
      }
    }
  }

  for (final col in columns) {
    col.sort((a, b) => a.readTop.compareTo(b.readTop));
  }

  return columns;
}

// ─────────────────────────────────────────────────────────────────────────────
// FORMATO TABLA (factura / recibo)
//
// FIX 3 — Anchor: la columna con más líneas, no necesariamente la columna 0.
// ─────────────────────────────────────────────────────────────────────────────

void _buildTableMarkdown(StringBuffer buffer, List<List<_Line>> columns) {
  final allLines = columns.expand((c) => c).toList();
  final avgH = allLines.map((l) => l.readHeight).reduce((a, b) => a + b) / allLines.length;
  final rowTolerance = avgH * 0.8;

  int anchorIndex = 0;
  for (int i = 1; i < columns.length; i++) {
    if (columns[i].length > columns[anchorIndex].length) anchorIndex = i;
  }
  final orderedColumns = [
    columns[anchorIndex],
    ...columns.asMap().entries
        .where((e) => e.key != anchorIndex)
        .map((e) => e.value),
  ];

  final rows = <List<_Line?>>[];
  for (final anchor in orderedColumns[0]) {
    final row = <_Line?>[anchor];
    for (int c = 1; c < orderedColumns.length; c++) {
      final match = orderedColumns[c].where(
        (l) => (l.readTop - anchor.readTop).abs() < rowTolerance,
      );
      row.add(match.isNotEmpty ? match.first : null);
    }
    rows.add(row);
  }

  final colCount = orderedColumns.length;
  buffer.writeln(List.generate(colCount, (i) => 'Col${i + 1}').join(' | '));
  buffer.writeln(List.filled(colCount, '---').join(' | '));
  for (final row in rows) {
    buffer.writeln(row.map((l) => l != null ? _formatText(l) : '').join(' | '));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORMATO INLINE COLUMNAS (documento / folleto con múltiples columnas)
//
// Misma lógica de matching que _buildTableMarkdown (anchor + rowTolerance),
// pero salida como "izq\t\tder" sin headers ni separadores.
// ─────────────────────────────────────────────────────────────────────────────

void _buildInlineColumns(StringBuffer buffer, List<List<_Line>> columns, double maxCapsHeight) {
  final allLines = columns.expand((c) => c).toList();
  final avgH = allLines.map((l) => l.readHeight).reduce((a, b) => a + b) / allLines.length;
  final rowTolerance = avgH * 0.8;

  int anchorIndex = 0;
  for (int i = 1; i < columns.length; i++) {
    if (columns[i].length > columns[anchorIndex].length) anchorIndex = i;
  }
  final orderedColumns = [
    columns[anchorIndex],
    ...columns.asMap().entries
        .where((e) => e.key != anchorIndex)
        .map((e) => e.value),
  ];

  for (final anchor in orderedColumns[0]) {
    final cells = <String>[_formatLine(anchor, maxCapsHeight)];
    for (int c = 1; c < orderedColumns.length; c++) {
      final match = orderedColumns[c].where(
        (l) => (l.readTop - anchor.readTop).abs() < rowTolerance,
      );
      cells.add(match.isNotEmpty ? _formatText(match.first) : '');
    }
    // Eliminar celdas vacías del final; si solo queda una, sin tab
    while (cells.length > 1 && cells.last.isEmpty) cells.removeLast();
    buffer.writeln(cells.join('\t\t'));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORMATO SECUENCIAL (documento / folleto / manuscrito)
// ─────────────────────────────────────────────────────────────────────────────

void _appendColumnMarkdown(StringBuffer buffer, List<_Line> lines, double maxCapsHeight) {
  for (final line in lines) {
    buffer.writeln(_formatLine(line, maxCapsHeight));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// JERARQUÍA VISUAL
// ALL_CAPS → heading según ratio respecto al máximo ALL_CAPS del documento.
// ─────────────────────────────────────────────────────────────────────────────

String _formatLine(_Line line, double maxCapsHeight) {
  final text = line.text.trim();
  if (text.isEmpty) return '';

  if (text.startsWith('•') || text.startsWith('-')) {
    return '- ${text.replaceFirst(RegExp(r'^[•\-]\s*'), '')}';
  }

  final isAllCaps = text == text.toUpperCase() && text.contains(RegExp(r'[A-ZÁÉÍÓÚÑ]'));
  if (isAllCaps && maxCapsHeight > 0) {
    final ratio = line.readHeight / maxCapsHeight;
    if (ratio >= 0.80) return '# $text';
    if (ratio >= 0.50) return '## $text';
    return '### $text';
  }

  return text;
}

// Versión plana para celdas de tabla (sin prefijos markdown)
String _formatText(_Line line) {
  final text = line.text.trim();
  if (text.startsWith('•') || text.startsWith('-')) {
    return text.replaceFirst(RegExp(r'^[•\-]\s*'), '');
  }
  return text;
}
