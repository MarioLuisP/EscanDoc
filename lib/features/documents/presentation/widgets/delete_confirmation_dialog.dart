import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Diálogo de confirmación para eliminar un documento.
/// Estilo consistente con el modal de eliminar vencimiento.
class DeleteConfirmationDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const DeleteConfirmationDialog({
    super.key,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFFDFAF4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'delete_confirm_title'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'delete_confirm_message'.tr(),
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _DialogButton(
                    label: 'delete_no_button'.tr(),
                    onTap: onCancel,
                    gradientColors: const [Color(0xFFFDFAF4), Color(0xFFE0D4BC)],
                    textColor: const Color(0xFF5A4A30),
                    shadowColor: const Color(0xFF9A8060),
                    border: Border.all(color: const Color(0xFFBBAA88), width: 1.5),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DialogButton(
                    label: 'delete_yes_button'.tr(),
                    onTap: onConfirm,
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
    );
  }

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DeleteConfirmationDialog(
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final List<Color> gradientColors;
  final Color textColor;
  final Color shadowColor;
  final BoxBorder? border;

  const _DialogButton({
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
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
