import 'package:easy_localization/easy_localization.dart';
import 'package:escandoc/core/services/notification_prompt_service.dart';
import 'package:escandoc/core/services/notification_service.dart';
import 'package:escandoc/core/widgets/notification_permission_dialog.dart';
import 'package:escandoc/features/documents/presentation/providers/documents_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Página de configuración — accesible desde el menú ☰ del home.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool? _notifEnabled;

  @override
  void initState() {
    super.initState();
    _loadNotifState();
  }

  Future<void> _loadNotifState() async {
    final enabled = await NotificationPromptService.isEnabled();
    if (mounted) setState(() => _notifEnabled = enabled);
  }

  Future<void> _toggleNotifications(bool value) async {
    final provider = context.read<DocumentsProvider>();
    if (value) {
      final shouldAsk = await NotificationPromptService.shouldShow();
      if (shouldAsk) {
        if (!mounted) return;
        await NotificationPermissionDialog.showIfNeeded(context);
        final nowEnabled = await NotificationPromptService.isEnabled();
        if (!nowEnabled) return;
      }
      await provider.enableNotifications();
    } else {
      final confirmed = await _confirmDisable();
      if (!confirmed) return;
      await provider.disableNotifications();
    }
    final nowEnabled = await NotificationPromptService.isEnabled();
    if (mounted) setState(() => _notifEnabled = nowEnabled);
  }

  Future<bool> _confirmDisable() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFFFDFAF4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'settings_notif_disable_title'.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'settings_notif_disable_body'.tr(),
                style: const TextStyle(fontSize: 15, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _StyledButton(
                      label: 'cancel_button'.tr(),
                      onTap: () => Navigator.pop(ctx, false),
                      gradientColors: const [Color(0xFFFDFAF4), Color(0xFFE0D4BC)],
                      textColor: const Color(0xFF5A4A30),
                      shadowColor: const Color(0xFF9A8060),
                      border: Border.all(color: const Color(0xFFBBAA88), width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StyledButton(
                      label: 'settings_notif_disable_confirm'.tr(),
                      onTap: () => Navigator.pop(ctx, true),
                      gradientColors: [Colors.red[400]!, Colors.red[800]!],
                      textColor: Colors.white,
                      shadowColor: Colors.red[900]!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    EasyLocalization.of(context)?.locale;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Expanded(child: _buildContent(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8),
        border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 26),
            color: Colors.black87,
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'settings_title'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final currentLocale = context.locale.languageCode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Idioma
          _buildCard(
            child: Row(
              children: [
                const Icon(Icons.language, size: 22, color: Color(0xFF388E3C)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'settings_language'.tr(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                _buildLanguageDropdown(context, currentLocale),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Avisos de vencimiento
          _buildCard(
            child: Row(
              children: [
                const Icon(Icons.notifications_outlined,
                    size: 22, color: Color(0xFF388E3C)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'settings_notif_title'.tr(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      if (_notifEnabled != null)
                        Text(
                          _notifEnabled!
                              ? 'settings_notif_enabled'.tr()
                              : 'settings_notif_disabled'.tr(),
                          style: TextStyle(
                            fontSize: 13,
                            color: _notifEnabled!
                                ? const Color(0xFF388E3C)
                                : Colors.black38,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_notifEnabled == null)
                  const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Switch(
                    value: _notifEnabled!,
                    activeThumbColor: const Color(0xFF388E3C),
                    activeTrackColor: const Color(0xFF388E3C).withValues(alpha: 0.4),
                    onChanged: _toggleNotifications,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Botón de prueba provisorio
          _buildCard(
            child: Row(
              children: [
                const Icon(Icons.science_outlined,
                    size: 22, color: Color(0xFF388E3C)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'settings_test_notif_title'.tr(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await NotificationService.scheduleTestNotification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('settings_test_notif_success'.tr()),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  child: Text(
                    'settings_test_notif_button'.tr(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF388E3C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            offset: const Offset(0, 3),
            blurRadius: 8,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: child,
      ),
    );
  }

  Widget _buildLanguageDropdown(BuildContext context, String currentLocale) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFDFAF4), Color(0xFFE0D4BC)],
        ),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: const Color(0xFFBBAA88), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9A8060).withValues(alpha: 0.35),
            offset: const Offset(0, 3),
            blurRadius: 6,
            spreadRadius: -1,
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentLocale,
          isDense: true,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF5A4A30),
          ),
          dropdownColor: const Color(0xFFFDFAF4),
          borderRadius: BorderRadius.circular(12),
          items: [
            DropdownMenuItem(value: 'es', child: Text('language_es'.tr())),
            DropdownMenuItem(value: 'en', child: Text('language_en'.tr())),
          ],
          onChanged: (code) {
            if (code != null) context.setLocale(Locale(code));
          },
        ),
      ),
    );
  }
}

class _StyledButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final List<Color> gradientColors;
  final Color textColor;
  final Color shadowColor;
  final BoxBorder? border;

  const _StyledButton({
    required this.label,
    required this.onTap,
    required this.gradientColors,
    required this.textColor,
    required this.shadowColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(50),
        border: border,
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.50),
            offset: const Offset(0, 4),
            blurRadius: 8,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          splashColor: Colors.white24,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
