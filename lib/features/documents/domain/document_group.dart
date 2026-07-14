import 'package:escandoc/features/documents/data/models/document_model.dart';

/// Detección de grupos de páginas de un mismo PDF multipágina.
///
/// Value/service puro (sin Flutter). No existe un "grupo" en la BD: las páginas
/// de un PDF importado se guardan como documentos sueltos. El grupo se infiere
/// por dos señales combinadas:
///   1. Título con patrón `base_N` (ej. "tutorial_1", "tutorial_2"…).
///   2. `createdAt` dentro de la misma ráfaga de import (ventana [window]).
///
/// Combinarlas evita falsos positivos: un doc suelto "cosa_3" de otro día no se
/// agrupa con un "cosa_1" importado hoy. Verificado en device: las páginas de un
/// mismo import comparten `baseTime` (ImportProvider lo captura una sola vez) y
/// difieren en milisegundos, así que la ventana no parte un PDF real.
class DocumentGroup {
  DocumentGroup._();

  /// Tolerancia temporal para considerar dos páginas del mismo import.
  static const Duration window = Duration(seconds: 30);

  static final RegExp _pattern = RegExp(r'^(.+)_(\d+)$');

  /// Prefijo `base` de un título con patrón `base_N`, o `null` si no matchea.
  static String? baseOf(String title) => _pattern.firstMatch(title)?.group(1);

  /// Número de página `N` de un título `base_N`, o `null` si no matchea.
  static int? pageNumberOf(String title) {
    final m = _pattern.firstMatch(title);
    if (m == null) return null;
    return int.tryParse(m.group(2)!);
  }

  /// Devuelve las páginas hermanas del mismo grupo que [seed], incluido [seed],
  /// ordenadas por número de página (numérico, no lexicográfico).
  ///
  /// Si [seed] no pertenece a un grupo (título sin patrón `_N`, o sin hermanos
  /// dentro de [window]), devuelve `[seed]`.
  static List<DocumentModel> membersOf(
      List<DocumentModel> all, DocumentModel seed) {
    final base = baseOf(seed.title);
    if (base == null) return [seed];

    final members = all.where((doc) {
      if (baseOf(doc.title) != base) return false;
      return doc.createdAt.difference(seed.createdAt).abs() <= window;
    }).toList();

    members.sort((a, b) {
      final na = pageNumberOf(a.title) ?? 0;
      final nb = pageNumberOf(b.title) ?? 0;
      return na.compareTo(nb);
    });

    // `seed` siempre matchea su propia base y diff 0, así que está incluido.
    return members;
  }

  /// `true` si [seed] tiene al menos un hermano de grupo en [all].
  static bool isGrouped(List<DocumentModel> all, DocumentModel seed) =>
      membersOf(all, seed).length > 1;
}
