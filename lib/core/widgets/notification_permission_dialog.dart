import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../services/notification_prompt_service.dart';
import '../services/notification_service.dart';

/// Modal explicativo de permisos de notificaciones.
/// Uso: `await NotificationPermissionDialog.showIfNeeded(context);`
class NotificationPermissionDialog {
  static Future<void> showIfNeeded(BuildContext context) async {
    final should = await NotificationPromptService.shouldShow();
    if (!should || !context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DialogContent(),
    );
  }
}

class _DialogContent extends StatelessWidget {
  const _DialogContent();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFFDFAF4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_active_outlined,
                size: 44, color: Color(0xFF388E3C)),
            const SizedBox(height: 14),
            Text(
              'notif_prompt_title'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'notif_prompt_body'.tr(),
              style: const TextStyle(fontSize: 15, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _StyledButton(
                    label: 'notif_prompt_later'.tr(),
                    onTap: () async {
                      await NotificationPromptService.recordDeclined();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    gradientColors: const [Color(0xFFFDFAF4), Color(0xFFE0D4BC)],
                    textColor: const Color(0xFF5A4A30),
                    shadowColor: const Color(0xFF9A8060),
                    border: Border.all(color: const Color(0xFFBBAA88), width: 1.5),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StyledButton(
                    label: 'notif_prompt_activate'.tr(),
                    onTap: () async {
                      await NotificationPromptService.recordGranted();
                      await NotificationService.requestPermission();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    gradientColors: const [Color(0xFF66BB6A), Color(0xFF2E7D32)],
                    textColor: Colors.white,
                    shadowColor: const Color(0xFF1B5E20),
                  ),
                ),
              ],
            ),
          ],
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
