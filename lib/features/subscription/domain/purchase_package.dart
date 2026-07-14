/// Los tres planes que EscanDoc ofrece (ver `.context/67_monetizacion.md` §9).
///
/// El dominio los distingue solo para que la UI pueda armar la comparativa
/// "Ver planes"; para desbloquear features, los tres otorgan lo mismo (`pro`).
enum PurchasePlan {
  /// Suscripción mensual.
  monthly,

  /// Suscripción anual (~30% de ahorro sobre la mensual).
  annual,

  /// Pago único de por vida, sin vencimiento (el diferencial anti-suscripción).
  lifetime,
}

/// Un plan comprable, con su precio ya resuelto por la store.
///
/// Value object puro. El [priceString] viene **formateado y localizado por la
/// store** (símbolo de moneda, separadores, región), por eso es un String y no
/// un número: nunca calculamos precios en la app (§9 — "cero lógica propia de
/// precios"). El [productId] es el identificador del producto en Play / App Store.
class PurchasePackage {
  /// A qué plan corresponde este paquete.
  final PurchasePlan plan;

  /// Identificador del producto en la store (ej. `pro_lifetime`).
  final String productId;

  /// Precio ya formateado por la store (ej. `"$49.99"`, `"AR$ 49.999,00"`).
  final String priceString;

  const PurchasePackage({
    required this.plan,
    required this.productId,
    required this.priceString,
  });

  @override
  bool operator ==(Object other) =>
      other is PurchasePackage &&
      other.plan == plan &&
      other.productId == productId &&
      other.priceString == priceString;

  @override
  int get hashCode => Object.hash(plan, productId, priceString);

  @override
  String toString() =>
      'PurchasePackage($plan, $productId, $priceString)';
}

/// Conjunto de paquetes disponibles para mostrar al usuario (el "offering"
/// `default` de RevenueCat, ya traducido al dominio).
///
/// Que sea una lista permite que la UI del mayor use solo el [lifetime]
/// ("Desbloqueá todo") y la pantalla "Ver planes" muestre los tres.
class Offering {
  final List<PurchasePackage> packages;

  const Offering({required this.packages});

  /// El paquete de un plan puntual, o null si la store no lo devolvió.
  PurchasePackage? packageFor(PurchasePlan plan) {
    for (final p in packages) {
      if (p.plan == plan) return p;
    }
    return null;
  }
}
