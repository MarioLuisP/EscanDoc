import 'package:flutter_test/flutter_test.dart';
import 'package:escandoc/features/subscription/domain/entitlement.dart';
import 'package:escandoc/features/subscription/domain/premium_feature.dart';
import 'package:escandoc/features/subscription/domain/usecases/is_premium_feature_unlocked.dart';

void main() {
  const useCase = IsPremiumFeatureUnlocked();

  group('IsPremiumFeatureUnlocked', () {
    group('entitlement pro', () {
      test('desbloquea todas las features premium', () {
        for (final feature in PremiumFeature.values) {
          expect(
            useCase(feature, Entitlement.pro),
            isTrue,
            reason: '$feature debería estar desbloqueada para pro',
          );
        }
      });
    });

    group('entitlement free', () {
      test('bloquea PDF multipágina', () {
        expect(useCase(PremiumFeature.multipagePdf, Entitlement.free), isFalse);
      });

      test('bloquea export batch', () {
        expect(useCase(PremiumFeature.batchExport, Entitlement.free), isFalse);
      });

      test('bloquea todas las features premium', () {
        for (final feature in PremiumFeature.values) {
          expect(
            useCase(feature, Entitlement.free),
            isFalse,
            reason: '$feature debería estar bloqueada para free',
          );
        }
      });
    });
  });
}
