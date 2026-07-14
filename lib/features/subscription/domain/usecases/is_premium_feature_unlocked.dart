import 'package:escandoc/features/subscription/domain/entitlement.dart';
import 'package:escandoc/features/subscription/domain/premium_feature.dart';

/// UseCase: ¿está desbloqueada esta feature premium para este usuario?
///
/// Lógica pura (sin Flutter, sin repositorio). El gate de la capa de aplicación
/// consulta antes de dejar usar la feature; si retorna false, muestra el paywall.
///
/// Reglas de negocio:
/// - `pro` → todas las [PremiumFeature] desbloqueadas.
/// - `free` → ninguna feature premium disponible.
///
/// El parámetro [feature] existe para que enchufar una nueva feature premium
/// sea agregar un valor al enum, sin tocar los llamadores.
class IsPremiumFeatureUnlocked {
  const IsPremiumFeatureUnlocked();

  bool call(PremiumFeature feature, Entitlement entitlement) {
    return entitlement == Entitlement.pro;
  }
}
