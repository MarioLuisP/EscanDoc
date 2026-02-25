import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:escandoc/features/onboarding/domain/usecases/check_onboarding_status.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CheckOnboardingStatus', () {
    test('debe retornar false si nunca completó onboarding', () async {
      // Arrange - Sin valor guardado
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final useCase = CheckOnboardingStatus(prefs);

      // Act
      final result = await useCase.call();

      // Assert
      expect(result, false);
    });

    test('debe retornar true si ya completó onboarding', () async {
      // Arrange - Con valor guardado
      SharedPreferences.setMockInitialValues({
        'onboarding_completed': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final useCase = CheckOnboardingStatus(prefs);

      // Act
      final result = await useCase.call();

      // Assert
      expect(result, true);
    });

    test('debe retornar false si valor es false explícitamente', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'onboarding_completed': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final useCase = CheckOnboardingStatus(prefs);

      // Act
      final result = await useCase.call();

      // Assert
      expect(result, false);
    });
  });
}
