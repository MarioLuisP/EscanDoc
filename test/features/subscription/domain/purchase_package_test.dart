import 'package:flutter_test/flutter_test.dart';
import 'package:escandoc/features/subscription/domain/purchase_package.dart';

void main() {
  const monthly = PurchasePackage(
    plan: PurchasePlan.monthly,
    productId: 'pro_mensual',
    priceString: r'$2.99',
  );
  const lifetime = PurchasePackage(
    plan: PurchasePlan.lifetime,
    productId: 'pro_lifetime',
    priceString: r'$49.99',
  );

  group('PurchasePackage', () {
    test('igualdad por valor', () {
      const same = PurchasePackage(
        plan: PurchasePlan.monthly,
        productId: 'pro_mensual',
        priceString: r'$2.99',
      );
      expect(monthly, equals(same));
      expect(monthly.hashCode, equals(same.hashCode));
      expect(monthly, isNot(equals(lifetime)));
    });
  });

  group('Offering.packageFor', () {
    const offering = Offering(packages: [monthly, lifetime]);

    test('devuelve el paquete del plan pedido', () {
      expect(offering.packageFor(PurchasePlan.lifetime), equals(lifetime));
      expect(offering.packageFor(PurchasePlan.monthly), equals(monthly));
    });

    test('devuelve null si el plan no está en el offering', () {
      expect(offering.packageFor(PurchasePlan.annual), isNull);
    });
  });
}
