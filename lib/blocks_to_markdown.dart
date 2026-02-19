import 'dart:math';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONTRATO
// Entrada : List<TextBlock> de MLKit + DocumentType del clasificador
// Salida  : String Markdown con estructura detectada automáticamente
// ─────────────────────────────────────────────────────────────────────────────

enum DocumentType { documento, factura, folleto, recibo, manuscrito }

// Umbral de gap para separar columnas: 25% del ancho total.
const double _kColumnGapThreshold = 0.25;

// Mínimo de líneas para que un cluster sea considerado columna válida.
// Clusters con menos líneas se colapsan a la columna más cercana.
const int _kMinLinesPerColumn = 3;

String blocksToMarkdown(
  List<TextBlock> blocks,
  DocumentType docType,
) {
  if (blocks.isEmpty) return '';

  // ── 1. imageSize desde max de bboxes ────────────────────────────────────
  final imageWidth = blocks.map((b) => b.boundingBox?.right ?? 0.0).reduce(max);
  final imageHeight = blocks.map((b) => b.boundingBox?.bottom ?? 0.0).reduce(max);

  // ── 2. Rotación dominante (mediana de ángulos de TextLine) ───────────────
  final allAngles = <double>[];
  for (final block in blocks) {
    for (final line in block.lines) {
      final angle = line.angle;
      if (angle != null) allAngles.add(angle);
    }
  }
  final rotation = _detectRotation(allAngles);

  // ── 3. Aplanar a _Line con coordenadas transformadas ────────────────────
  final lines = <_Line>[];
  for (final block in blocks) {
    for (final line in block.lines) {
      final bbox = line.boundingBox;
      if (bbox == null) continue;
      final (readTop, readLeft) = _transform(
        bbox.top, bbox.left, bbox.bottom, bbox.right,
        rotation, imageWidth, imageHeight,
      );
      final isRotated =
          rotation == _Rotation.deg90 || rotation == _Rotation.deg270;
      lines.add(_Line(
        text: line.text,
        readTop: readTop,
        readLeft: readLeft,
        readHeight: isRotated ? bbox.width : bbox.height,
        readWidth: isRotated ? bbox.height : bbox.width,
        lineCount: block.lines.length,
      ));
    }
  }

  if (lines.isEmpty) return '';

  // ── 4. Detectar columnas por clustering de centros horizontales ──────────
  final totalReadWidth = lines.map((l) => l.readLeft + l.readWidth).reduce(max);
  final columns = _clusterColumns(lines, totalReadWidth);

  // ── 5. Construir markdown según docType y cantidad de columnas ───────────
  return _buildMarkdown(columns, docType);
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
  final int lineCount;

  const _Line({
    required this.text,
    required this.readTop,
    required this.readLeft,
    required this.readHeight,
    required this.readWidth,
    required this.lineCount,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// DETECCIÓN DE ROTACIÓN
// ─────────────────────────────────────────────────────────────────────────────

_Rotation _detectRotation(List<double> angles) {
  if (angles.isEmpty) return _Rotation.deg0;

  final sorted = List<double>.from(angles)..sort();
  final median = sorted[sorted.length ~/ 2];

  if (median >= 315 || median < 45) return _Rotation.deg0;
  if (median >= 45 && median < 135) return _Rotation.deg90;
  if (median >= 135 && median < 225) return _Rotation.deg180;
  return _Rotation.deg270;
}

// ─────────────────────────────────────────────────────────────────────────────
// TRANSFORMACIÓN DE COORDENADAS
// ─────────────────────────────────────────────────────────────────────────────

(double readTop, double readLeft) _transform(
  double top, double left, double bottom, double right,
  _Rotation rotation, double imgW, double imgH,
) {
  switch (rotation) {
    case _Rotation.deg0:
      return (top, left);
    case _Rotation.deg90:
      return (left, imgH - bottom);
    case _Rotation.deg180:
      return (imgH - bottom, imgW - right);
    case _Rotation.deg270:
      return (imgW - right, top);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CLUSTERING DE COLUMNAS
//
// FIX 2a — Referencia: centro del bbox (readLeft + readWidth/2).
// FIX 2b — Densidad mínima: clusters con < _kMinLinesPerColumn líneas
//           se colapsan a la columna válida más cercana (eliminación de
//           columnas fantasma por ruido: logos, números sueltos, etc.).
// ─────────────────────────────────────────────────────────────────────────────

double _centerX(_Line l) => l.readLeft + l.readWidth / 2;

List<List<_Line>> _clusterColumns(List<_Line> lines, double totalWidth) {
  if (totalWidth <= 0) return [lines];

  // Ordenar por centro horizontal
  final sorted = List<_Line>.from(lines)
    ..sort((a, b) => _centerX(a).compareTo(_centerX(b)));

  final threshold = totalWidth * _kColumnGapThreshold;
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

  // Asignación inicial: cada línea → columna de centro más cercano
  final rawColumns = List.generate(columnCenters.length, (_) => <_Line>[]);
  for (final line in lines) {
    int best = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < columnCenters.length; i++) {
      final dist = (_centerX(line) - columnCenters[i]).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = i;
      }
    }
    rawColumns[best].add(line);
  }

  // FIX 2b — Eliminar columnas fantasma por densidad insuficiente.
  // Las líneas huérfanas se reasignan a la columna válida más cercana.
  final validIndices = <int>[];
  for (int i = 0; i < rawColumns.length; i++) {
    if (rawColumns[i].length >= _kMinLinesPerColumn) validIndices.add(i);
  }

  // Si ninguna columna supera el mínimo (doc muy corto), devolver todas sin filtrar
  final columns = validIndices.isEmpty
      ? rawColumns
      : List.generate(validIndices.length, (i) => List<_Line>.from(rawColumns[validIndices[i]]));

  // Reasignar huérfanas (columnas descartadas) a la columna válida más cercana
  if (validIndices.isNotEmpty && validIndices.length < rawColumns.length) {
    final validCenters = validIndices.map((i) => columnCenters[i]).toList();
    for (int i = 0; i < rawColumns.length; i++) {
      if (validIndices.contains(i)) continue;
      for (final line in rawColumns[i]) {
        int best = 0;
        double bestDist = double.infinity;
        for (int j = 0; j < validCenters.length; j++) {
          final dist = (_centerX(line) - validCenters[j]).abs();
          if (dist < bestDist) {
            bestDist = dist;
            best = j;
          }
        }
        columns[best].add(line);
      }
    }
  }

  // Ordenar cada columna por readTop
  for (final col in columns) {
    col.sort((a, b) => a.readTop.compareTo(b.readTop));
  }

  return columns;
}

// ─────────────────────────────────────────────────────────────────────────────
// CONSTRUCCIÓN DE MARKDOWN
// ─────────────────────────────────────────────────────────────────────────────

String _buildMarkdown(List<List<_Line>> columns, DocumentType docType) {
  final buffer = StringBuffer();

  // Percentiles de readHeight sobre todas las líneas → umbrales relativos
  final heights = columns.expand((c) => c).map((l) => l.readHeight).toList()
    ..sort();
  final p50 = _percentile(heights, 0.50);
  final p75 = _percentile(heights, 0.75);

  final useTable = columns.length > 1 &&
      (docType == DocumentType.factura || docType == DocumentType.recibo);

  if (useTable) {
    _buildTableMarkdown(buffer, columns, p50: p50, p75: p75);
  } else {
    for (int i = 0; i < columns.length; i++) {
      if (i > 0) {
        buffer.writeln();
        buffer.writeln('---');
        buffer.writeln();
      }
      _appendColumnMarkdown(buffer, columns[i], p50: p50, p75: p75);
    }
  }

  return buffer.toString().trim();
}

double _percentile(List<double> sorted, double p) {
  if (sorted.isEmpty) return 0;
  final index = (p * (sorted.length - 1)).round();
  return sorted[index];
}

// ─────────────────────────────────────────────────────────────────────────────
// FORMATO TABLA (factura / recibo)
//
// FIX 3 — Anchor: la columna con más líneas, no necesariamente la columna 0.
//          Evita filas huérfanas cuando la columna izquierda es más corta.
// ─────────────────────────────────────────────────────────────────────────────

void _buildTableMarkdown(
  StringBuffer buffer,
  List<List<_Line>> columns, {
  required double p50,
  required double p75,
}) {
  final allLines = columns.expand((c) => c).toList();
  final avgH =
      allLines.map((l) => l.readHeight).reduce((a, b) => a + b) / allLines.length;
  final rowTolerance = avgH * 0.8;

  // FIX 3: usar la columna con más líneas como ancla de filas
  int anchorIndex = 0;
  for (int i = 1; i < columns.length; i++) {
    if (columns[i].length > columns[anchorIndex].length) anchorIndex = i;
  }
  // Reordenar: ancla primero, resto en orden original
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
    final cells = row.map((l) => l != null ? _formatText(l) : '').toList();
    buffer.writeln(cells.join(' | '));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORMATO SECUENCIAL (documento / folleto / manuscrito)
// ─────────────────────────────────────────────────────────────────────────────

void _appendColumnMarkdown(
  StringBuffer buffer,
  List<_Line> lines, {
  required double p50,
  required double p75,
}) {
  for (final line in lines) {
    buffer.writeln(_formatLine(line, p50: p50, p75: p75));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// JERARQUÍA VISUAL
// Todo mayúsculas + readHeight relativo al documento → nivel de heading.
// ─────────────────────────────────────────────────────────────────────────────

String _formatLine(_Line line, {required double p50, required double p75}) {
  final text = line.text.trim();
  if (text.isEmpty) return '';

  if (text.startsWith('•') || text.startsWith('-')) {
    final content = text.replaceFirst(RegExp(r'^[•\-]\s*'), '');
    return '- $content';
  }

  final isAllCaps =
      text == text.toUpperCase() && text.contains(RegExp(r'[A-ZÁÉÍÓÚÑ]'));

  if (isAllCaps) {
    if (line.readHeight >= p75) return '# $text';
    if (line.readHeight >= p50) return '## $text';
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
