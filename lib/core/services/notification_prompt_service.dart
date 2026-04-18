import 'package:shared_preferences/shared_preferences.dart';

/// Controla el modal de permisos (máx 3 intentos) y el estado enabled/disabled.
class NotificationPromptService {
  static const _countKey = 'notif_prompt_count';
  static const _enabledKey = 'notif_enabled';

  // ── Prompt ──────────────────────────────────────────────────────────────────

  /// true si quedan intentos disponibles (onboarding + 2 vencimientos = 3 total)
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_countKey) ?? 0) < 3;
  }

  static Future<void> recordDeclined() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_countKey) ?? 0;
    await prefs.setInt(_countKey, current + 1);
  }

  /// Activa notificaciones y cierra los prompts permanentemente.
  static Future<void> recordGranted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_countKey, 3);
    await prefs.setBool(_enabledKey, true);
  }

  // ── Enabled/Disabled ────────────────────────────────────────────────────────

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true; // ON por defecto
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }
}
