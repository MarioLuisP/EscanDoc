import 'package:escandoc/features/subscription/domain/entitlement.dart';

/// UseCase: ¿puede el usuario guardar un documento más?
///
/// Lógica pura (sin Flutter, sin repositorio). El gate de la capa de aplicación
/// le pasa el conteo actual y el entitlement, y decide entre guardar o mostrar
/// el paywall según la respuesta.
///
/// Reglas de negocio:
/// - `pro` → siempre puede (documentos ilimitados).
/// - `free` → puede solo si tiene **menos** de [FreeTierLimits.maxDocuments].
///   Al llegar al límite, el siguiente guardado dispara el paywall.
class CanAddDocument {
  const CanAddDocument();

  /// [currentCount] documentos que el usuario ya tiene guardados.
  bool call(int currentCount, Entitlement entitlement) {
    if (entitlement == Entitlement.pro) return true;
    return currentCount < FreeTierLimits.maxDocuments;
  }
}
