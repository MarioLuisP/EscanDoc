import 'package:shared_preferences/shared_preferences.dart';

/// UseCase para verificar si el usuario ya completó el onboarding
///
/// Retorna:
/// - true: Ya completó el tutorial
/// - false: Primera vez o no completó
class CheckOnboardingStatus {
  final SharedPreferences _prefs;

  CheckOnboardingStatus(this._prefs);

  Future<bool> call() async {
    return _prefs.getBool('onboarding_completed') ?? false;
  }
}
