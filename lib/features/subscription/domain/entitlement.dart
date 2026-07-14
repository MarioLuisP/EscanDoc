/// Nivel de acceso del usuario. Determina qué está desbloqueado.
///
/// Value object puro (sin Flutter, sin RevenueCat). El mapeo desde el proveedor
/// de pagos vive en la capa de data; el dominio solo conoce estos dos estados.
enum Entitlement {
  /// Sin compra activa. Sujeto al límite del free tier ([FreeTierLimits]).
  free,

  /// Con compra activa (mensual, anual o de por vida). Todo desbloqueado.
  ///
  /// El dominio no distingue entre los tres planes: todos otorgan el mismo
  /// acceso. La diferencia comercial (recurrencia, precio) es de la store.
  pro,
}

/// Límites del plan gratuito. Fuente de verdad única del free tier.
///
/// El "momento upgrade" es contextual: el paywall aparece solo al chocar con
/// uno de estos límites (ver `.context/67_monetizacion.md` §8).
class FreeTierLimits {
  const FreeTierLimits._();

  /// Máximo de documentos que un usuario free puede tener guardados.
  ///
  /// Al llegar a este número, guardar el siguiente dispara el paywall.
  /// Qué "cuenta" como documento (notas, páginas de un PDF) lo decide el gate
  /// en la capa de aplicación, no el dominio.
  static const int maxDocuments = 15;
}
