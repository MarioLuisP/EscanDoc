import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:escandoc/features/onboarding/domain/usecases/complete_onboarding.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CompleteOnboarding', () {
    test('debe guardar estado de onboarding completado', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final useCase = CompleteOnboarding(prefs);

      // Act
      await useCase.call();

      // Assert
      final saved = prefs.getBool('onboarding_completed');
      expect(saved, true);
    });

    test('debe sobrescribir si ya existía valor', () async {
      // Arrange - Empezar con false
      SharedPreferences.setMockInitialValues({
        'onboarding_completed': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final useCase = CompleteOnboarding(prefs);

      // Act
      await useCase.call();

      // Assert
      final saved = prefs.getBool('onboarding_completed');
      expect(saved, true);
    });
  });
}
