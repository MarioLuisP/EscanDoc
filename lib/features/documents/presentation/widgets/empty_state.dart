import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Widget que muestra estado vacío cuando no hay documentos
/// Diseño minimalista y accesible para personas mayores
class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícono grande y simple
            Icon(
              Icons.description_outlined,
              size: 120,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 24),

            // Texto principal (grande y legible)
            Text(
              'documents_empty'.tr(),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Subtítulo (instrucción clara)
            Text(
              'documents_empty_subtitle'.tr(),
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
