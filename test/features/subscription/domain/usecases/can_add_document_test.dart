import 'package:flutter_test/flutter_test.dart';
import 'package:escandoc/features/subscription/domain/entitlement.dart';
import 'package:escandoc/features/subscription/domain/usecases/can_add_document.dart';

void main() {
  const useCase = CanAddDocument();

  group('CanAddDocument', () {
    group('entitlement pro (ilimitado)', () {
      test('permite guardar aunque esté por encima del límite free', () {
        expect(useCase(0, Entitlement.pro), isTrue);
        expect(useCase(15, Entitlement.pro), isTrue);
        expect(useCase(9999, Entitlement.pro), isTrue);
      });
    });

    group('entitlement free (límite de 15)', () {
      test('permite guardar con 0 documentos', () {
        expect(useCase(0, Entitlement.free), isTrue);
      });

      test('permite guardar con 14 documentos (el guardado hace el nº 15)', () {
        expect(useCase(14, Entitlement.free), isTrue);
      });

      test('bloquea al tener 15 documentos (el nº 16 dispara el paywall)', () {
        expect(useCase(15, Entitlement.free), isFalse);
      });

      test('bloquea con más de 15 documentos', () {
        expect(useCase(16, Entitlement.free), isFalse);
        expect(useCase(100, Entitlement.free), isFalse);
      });

      test('usa la constante FreeTierLimits.maxDocuments como umbral', () {
        // En el límite exacto - 1 permite; en el límite bloquea.
        expect(useCase(FreeTierLimits.maxDocuments - 1, Entitlement.free), isTrue);
        expect(useCase(FreeTierLimits.maxDocuments, Entitlement.free), isFalse);
      });
    });
  });
}
