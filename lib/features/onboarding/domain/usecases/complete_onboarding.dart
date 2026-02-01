import 'package:shared_preferences/shared_preferences.dart';

/// UseCase para marcar el onboarding como completado
///
/// Guarda estado en SharedPreferences con clave 'onboarding_completed'
class CompleteOnboarding {
  final SharedPreferences _prefs;

  CompleteOnboarding(this._prefs);

  Future<void> call() async {
    await _prefs.setBool('onboarding_completed', true);
  }
}
