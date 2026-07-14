/// Features que requieren entitlement `pro` para usarse.
///
/// El free tier tiene **todas las features funcionales** (escáner, OCR,
/// clasificador, notas, vencimientos). Solo estas quedan detrás del paywall
/// (ver `.context/67_monetizacion.md` §9).
enum PremiumFeature {
  /// Importar / OCR de PDF multipágina.
  multipagePdf,

  /// Exportar documentos en lote.
  batchExport,
}
