/// Rango de páginas (1-based, inclusivo) a importar de un PDF.
///
/// Value object puro (sin Flutter). Normaliza y corrige la entrada del usuario
/// para que nunca produzca un rango inválido:
/// - si `from > to`, los intercambia
/// - recorta ambos extremos a `[1, total]`
///
/// Así la UI puede ofrecer "traer todas" o un rango a medida sin validar a mano,
/// y el import nunca pide una página inexistente.
class PdfPageRange {
  /// Primera página del rango (1-based, inclusiva).
  final int from;

  /// Última página del rango (1-based, inclusiva).
  final int to;

  const PdfPageRange._(this.from, this.to);

  /// Todas las páginas: `1..total`. Si `total < 1`, cae a una sola página.
  factory PdfPageRange.all(int total) {
    final t = total < 1 ? 1 : total;
    return PdfPageRange._(1, t);
  }

  /// Rango a medida, corrigiendo la entrada:
  /// intercambia si `from > to` y recorta ambos a `[1, total]`.
  factory PdfPageRange.clamp(int from, int to, int total) {
    final t = total < 1 ? 1 : total;
    var lo = from;
    var hi = to;
    if (lo > hi) {
      final tmp = lo;
      lo = hi;
      hi = tmp;
    }
    lo = lo.clamp(1, t);
    hi = hi.clamp(1, t);
    return PdfPageRange._(lo, hi);
  }

  /// Cantidad de páginas del rango.
  int get count => to - from + 1;

  /// `true` si el rango es una sola página.
  bool get isSingle => count == 1;

  /// Índices 0-based de las páginas del rango, para `renderPageToJpg`.
  ///
  /// Ej: rango 3..5 → `[2, 3, 4]`.
  List<int> get pageIndices => List.generate(count, (i) => (from - 1) + i);

  @override
  bool operator ==(Object other) =>
      other is PdfPageRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'PdfPageRange($from-$to)';
}
