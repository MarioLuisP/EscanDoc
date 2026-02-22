/// Preferencias del usuario.
///
/// TODO (onboarding): leer/escribir desde SharedPreferences.
/// Por ahora hardcodeado para desarrollo.
class UserPreferences {
  // ignore: avoid_field_initializers_in_const_classes
  static const String _hardcodedName = 'Mario';

  String get userName => _hardcodedName;
}
