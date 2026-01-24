import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Diálogo de confirmación para eliminar documentos
/// Botones grandes y claros para personas mayores (mínimo 120x60dp)
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
    return AlertDialog(
      // Título grande y legible
      title: Text(
        'delete_confirm_title'.tr(),
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),

      // Mensaje de confirmación
      content: Text(
        'delete_confirm_message'.tr(),
        style: const TextStyle(fontSize: 18),
      ),

      // Botones grandes (sin ActionButtons pequeños)
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      actionsPadding: const EdgeInsets.all(16),
      actions: [
        // Botón CANCELAR (gris)
        SizedBox(
          width: double.infinity,
          height: 60, // Mínimo 60dp de altura
          child: OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.grey, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'delete_no_button'.tr(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Botón ELIMINAR (rojo)
        SizedBox(
          width: double.infinity,
          height: 60, // Mínimo 60dp de altura
          child: ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'delete_yes_button'.tr(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Método helper para mostrar el diálogo
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // No cerrar tocando afuera (seguridad)
      builder: (context) => DeleteConfirmationDialog(
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }
}
