import 'package:escandoc/features/subscription/domain/entitlement.dart';
import 'package:escandoc/features/subscription/domain/purchase_package.dart';

/// Abstracción del proveedor de pagos (implementada sobre RevenueCat en data).
///
/// El dominio no conoce RevenueCat: habla en términos de [Entitlement] y
/// [Offering]. Esto mantiene la lógica de negocio testeable y permite cambiar
/// de proveedor sin tocar UseCases ni providers.
///
/// La implementación cachea el entitlement localmente para que la app arranque
/// offline sabiendo si el usuario es pro (ver `.context/67_monetizacion.md` §10,
/// Fase 2).
abstract class PurchaseRepository {
  /// Entitlement actual del usuario. Debe resolver rápido y offline usando la
  /// caché local; refresca contra la store en segundo plano si hay red.
  Future<Entitlement> getEntitlement();

  /// Paquetes disponibles para comprar, o null si la store no los devolvió
  /// (sin red, productos no configurados, etc.).
  Future<Offering?> getOfferings();

  /// Inicia la compra de [package] a través de la store.
  ///
  /// Retorna el [Entitlement] resultante (`pro` si la compra fue exitosa).
  /// Lanza si el usuario cancela o la store rechaza la operación.
  Future<Entitlement> purchase(PurchasePackage package);

  /// Restaura compras previas del usuario (crítico para el mayor que cambia de
  /// teléfono). Retorna el [Entitlement] resultante.
  Future<Entitlement> restore();
}
