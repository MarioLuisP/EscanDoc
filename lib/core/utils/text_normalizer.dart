/// Normalización de texto para búsqueda: minúsculas + tildes → base.
/// "Nótas" → "notas", "REUNIÓN" → "reunion"
///
/// Usado tanto en [DocumentRepository] (al escribir shadow columns)
/// como en [SearchRepositoryImpl] (al normalizar la query del usuario).
class TextNormalizer {
  TextNormalizer._();

  static String normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp('[áàâãäå]'), 'a')
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[íìîï]'), 'i')
        .replaceAll(RegExp('[óòôõö]'), 'o')
        .replaceAll(RegExp('[úùûü]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('ç', 'c');
  }
}
