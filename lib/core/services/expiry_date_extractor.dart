import 'package:flutter/foundation.dart';

/// Candidato a fecha de vencimiento
class _ExpiryCandidate {
  final DateTime date;
  int confidence;
  final String source;

  _ExpiryCandidate({
    required this.date,
    required this.confidence,
    required this.source,
  });
}

/// Extrae la fecha de vencimiento más relevante de un texto OCR.
///
/// Diseñado para documentos argentinos: facturas (con 2° y 3° vencimiento),
/// DNI, pasaportes, seguros, tarjetas, etc.
///
/// Lógica de selección:
///   1. Extrae todas las fechas con un score de confianza.
///   2. Filtra solo las fechas futuras (o hoy).
///   3. De las que quedan, elige la de mayor confianza.
///      En caso de empate de confianza, elige la más cercana a hoy.
///      → Esto hace que en una factura con 1°/2°/3° vencimiento se tome
///        siempre el vencimiento vigente más próximo.
class ExpiryDateExtractor {
  // ─── Meses en español ────────────────────────────────────────────────────

  static const Map<String, int> _meses = {
    'enero': 1,   'ene': 1,
    'febrero': 2, 'feb': 2,
    'marzo': 3,   'mar': 3,
    'abril': 4,   'abr': 4,
    'mayo': 5,    'may': 5,
    'junio': 6,   'jun': 6,
    'julio': 7,   'jul': 7,
    'agosto': 8,  'ago': 8,
    'septiembre': 9, 'sep': 9, 'sept': 9,
    'octubre': 10,   'oct': 10,
    'noviembre': 11, 'nov': 11,
    'diciembre': 12, 'dic': 12,
  };

  // ─── Keywords que indican vencimiento ────────────────────────────────────

  static final List<RegExp> _keywordsVencimiento = [
    RegExp(r'vencimiento\s*:?', caseSensitive: false),
    RegExp(r'vto\.?\s*:?', caseSensitive: false),
    RegExp(r'vence\s*:?', caseSensitive: false),
    RegExp(r'válido\s+hasta\s*:?', caseSensitive: false),
    RegExp(r'valido\s+hasta\s*:?', caseSensitive: false),
    RegExp(r'válida\s+hasta\s*:?', caseSensitive: false),
    RegExp(r'valida\s+hasta\s*:?', caseSensitive: false),
    RegExp(r'pagar\s+antes\s+de\s*:?', caseSensitive: false),
    RegExp(r'fecha\s+de\s+venc\w*\s*:?', caseSensitive: false),
    RegExp(r'due\s+date\s*:?', caseSensitive: false),
    RegExp(r'expir\w*\s*:?', caseSensitive: false),
    RegExp(r'2°\s*venc\w*', caseSensitive: false),
    RegExp(r'3°\s*venc\w*', caseSensitive: false),
    RegExp(r'segundo\s+venc\w*', caseSensitive: false),
    RegExp(r'tercer\s+venc\w*', caseSensitive: false),
  ];

  // ─── Palabras que indican que NO es una fecha de vencimiento ─────────────

  static const List<String> _palabrasBasura = [
    'cft', 'tna', 'tea',
    'visa', 'mastercard', 'naranja',
    'cuotas', 'sin interés', 'sin interes',
    'calle', 'av.', 'avenida', 'pasaje',
    'tel', 'telefono', 'teléfono',
    'cuit', 'cuil',
  ];

  // ─── API pública ─────────────────────────────────────────────────────────

  /// Extrae la fecha de vencimiento más relevante del texto OCR.
  ///
  /// Incluye fechas pasadas (documento ya vencido) — la UI decide cómo mostrarlas.
  /// Para facturas con 1°/2°/3° vencimiento: si hay fechas futuras, toma la más
  /// próxima. Si todas son pasadas, toma la más reciente (la menos vencida).
  ///
  /// Retorna null si no hay ninguna con confianza suficiente.
  DateTime? extractExpiryDate(String ocrText) {
    if (ocrText.trim().isEmpty) return null;

    final candidates = _extractAllCandidates(ocrText);
    if (candidates.isEmpty) {
      debugPrint('[ExpiryExtractor] Sin candidatos');
      return null;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Separar futuras y pasadas
    final future = candidates.where((c) => !c.date.isBefore(today)).toList();
    final past   = candidates.where((c) => c.date.isBefore(today)).toList();

    List<_ExpiryCandidate> pool;
    if (future.isNotEmpty) {
      // Hay fechas futuras → usar solo esas (ignorar las pasadas)
      // Orden: confianza DESC, luego fecha ASC (más próxima primero)
      pool = future
        ..sort((a, b) {
          final c = b.confidence.compareTo(a.confidence);
          return c != 0 ? c : a.date.compareTo(b.date);
        });
    } else {
      // Todas pasadas → tomar la más reciente (menos vencida)
      pool = past..sort((a, b) => b.date.compareTo(a.date));
      debugPrint('[ExpiryExtractor] Solo fechas pasadas: ${past.length}');
    }

    final best = pool.first;
    debugPrint('[ExpiryExtractor] Mejor candidato: ${best.date} (conf: ${best.confidence}, fuente: ${best.source})');

    if (best.confidence < 40) {
      debugPrint('[ExpiryExtractor] Confianza insuficiente (${best.confidence} < 40)');
      return null;
    }

    return best.date;
  }

  // ─── Extracción de candidatos ─────────────────────────────────────────────

  List<_ExpiryCandidate> _extractAllCandidates(String text) {
    final candidates = <_ExpiryCandidate>[];

    candidates.addAll(_extractNumericDates(text));
    candidates.addAll(_extractLongFormatDates(text));
    candidates.addAll(_extractMonthYearDates(text));

    // Boost de confianza si hay keyword de vencimiento cerca
    _applyKeywordBoost(text, candidates);

    // Boost por repetición
    _applyRepetitionBoost(candidates);

    // Eliminar duplicados (misma fecha → quedarse con la de mayor confianza)
    return _deduplicate(candidates);
  }

  // ─── Patrones numéricos: DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD, DD/MM/YY ───

  List<_ExpiryCandidate> _extractNumericDates(String text) {
    final candidates = <_ExpiryCandidate>[];

    // DD/MM/YYYY o DD-MM-YYYY
    final patDMY = RegExp(r'\b(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})\b');
    for (final m in patDMY.allMatches(text)) {
      if (_nearBasura(text, m.start, m.end)) continue;
      final d = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      var y = int.parse(m.group(3)!);
      if (y < 100) y += 2000;

      final date = _tryDate(d, mo, y);
      if (date != null) {
        candidates.add(_ExpiryCandidate(date: date, confidence: 55, source: 'DD/MM/YYYY'));
      }
    }

    // YYYY-MM-DD (ISO)
    final patISO = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b');
    for (final m in patISO.allMatches(text)) {
      if (_nearBasura(text, m.start, m.end)) continue;
      final date = _tryDate(int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
      if (date != null) {
        candidates.add(_ExpiryCandidate(date: date, confidence: 55, source: 'YYYY-MM-DD'));
      }
    }

    return candidates;
  }

  // ─── Patrones texto: "15 de marzo de 2028", "15 marzo 2028" ─────────────

  List<_ExpiryCandidate> _extractLongFormatDates(String text) {
    final candidates = <_ExpiryCandidate>[];
    final textLower = text.toLowerCase();

    for (final entry in _meses.entries) {
      final mes = entry.key;
      final mesNum = entry.value;

      // "15 de marzo de 2028" o "15 de marzo 2028" o "15 marzo 2028"
      final pat = RegExp(
        r'\b(\d{1,2})\s+(?:de\s+)?' + mes + r'(?:\s+(?:de\s+)?(\d{4}))?\b',
        caseSensitive: false,
      );
      for (final m in pat.allMatches(textLower)) {
        if (_nearBasura(text, m.start, m.end)) continue;
        final d = int.parse(m.group(1)!);
        final y = m.group(2) != null ? int.parse(m.group(2)!) : DateTime.now().year;
        final date = _tryDate(d, mesNum, y);
        if (date != null) {
          candidates.add(_ExpiryCandidate(date: date, confidence: 60, source: '$d $mes'));
        }
      }
    }

    return candidates;
  }

  // ─── Patrones mes/año: "03/2028", "03/28", "MAR 2028", "MARZO 2028" ─────

  List<_ExpiryCandidate> _extractMonthYearDates(String text) {
    final candidates = <_ExpiryCandidate>[];
    final textLower = text.toLowerCase();

    // MM/YYYY o MM/YY (día = último del mes → vencimiento al final)
    final patMY = RegExp(r'\b(\d{1,2})/(\d{2,4})\b');
    for (final m in patMY.allMatches(text)) {
      if (_nearBasura(text, m.start, m.end)) continue;
      final mo = int.parse(m.group(1)!);
      var y = int.parse(m.group(2)!);
      if (y < 100) y += 2000;
      if (mo < 1 || mo > 12) continue;
      // Último día del mes
      final lastDay = DateTime(y, mo + 1, 0).day;
      final date = _tryDate(lastDay, mo, y);
      if (date != null) {
        candidates.add(_ExpiryCandidate(date: date, confidence: 45, source: 'MM/YYYY'));
      }
    }

    // "MAR 2028" o "MARZO 2028" (sin día → día 1 del mes)
    for (final entry in _meses.entries) {
      final pat = RegExp(r'\b' + entry.key + r'\s+(\d{4})\b', caseSensitive: false);
      for (final m in pat.allMatches(textLower)) {
        if (_nearBasura(text, m.start, m.end)) continue;
        final y = int.parse(m.group(1)!);
        final date = _tryDate(1, entry.value, y);
        if (date != null) {
          candidates.add(_ExpiryCandidate(date: date, confidence: 45, source: '${entry.key} YYYY'));
        }
      }
    }

    return candidates;
  }

  // ─── Boost de confianza por keyword de vencimiento ───────────────────────

  void _applyKeywordBoost(String text, List<_ExpiryCandidate> candidates) {
    // Encontrar posiciones de keywords
    final keywordPositions = <int>[];
    for (final kw in _keywordsVencimiento) {
      for (final m in kw.allMatches(text)) {
        keywordPositions.add(m.start);
      }
    }

    if (keywordPositions.isEmpty) return;

    // Para cada candidato, ver si hay keyword a ≤120 chars de distancia
    for (final candidate in candidates) {
      // Aproximar posición del candidato buscando su fecha en el texto
      final dateStr = '${candidate.date.day}/${candidate.date.month}';
      final pos = text.indexOf(dateStr);
      if (pos == -1) continue;

      for (final kwPos in keywordPositions) {
        if ((pos - kwPos).abs() <= 120) {
          candidate.confidence += 40;
          debugPrint('[ExpiryExtractor] Boost por keyword: ${candidate.date} (+40)');
          break;
        }
      }
    }
  }

  // ─── Boost por repetición ─────────────────────────────────────────────────

  void _applyRepetitionBoost(List<_ExpiryCandidate> candidates) {
    final counts = <String, int>{};
    for (final c in candidates) {
      final key = '${c.date.year}-${c.date.month}-${c.date.day}';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    for (final c in candidates) {
      final key = '${c.date.year}-${c.date.month}-${c.date.day}';
      final count = counts[key] ?? 1;
      if (count > 1) {
        c.confidence += (count - 1) * 15;
      }
    }
  }

  // ─── Deduplicación ───────────────────────────────────────────────────────

  List<_ExpiryCandidate> _deduplicate(List<_ExpiryCandidate> candidates) {
    final map = <String, _ExpiryCandidate>{};
    for (final c in candidates) {
      final key = '${c.date.year}-${c.date.month}-${c.date.day}';
      if (!map.containsKey(key) || c.confidence > map[key]!.confidence) {
        map[key] = c;
      }
    }
    return map.values.toList();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Construye un DateTime validando día/mes/año. Retorna null si inválido.
  /// Acepta fechas hasta 15 años en el futuro (pasaportes, seguros largos).
  DateTime? _tryDate(int day, int month, int year) {
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    if (year < 2000 || year > DateTime.now().year + 15) return null;
    try {
      final date = DateTime(year, month, day);
      // Verificar que no hubo overflow (ej: 31 de febrero)
      if (date.month != month) return null;
      return date;
    } catch (_) {
      return null;
    }
  }

  /// Verifica si el texto alrededor de la fecha es "basura" (no vencimiento).
  bool _nearBasura(String text, int start, int end) {
    final windowStart = (start - 40).clamp(0, text.length);
    final windowEnd = (end + 40).clamp(0, text.length);
    final window = text.substring(windowStart, windowEnd).toLowerCase();
    for (final word in _palabrasBasura) {
      if (window.contains(word)) return true;
    }
    return false;
  }
}
