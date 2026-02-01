import 'package:flutter/material.dart';

/// Widget reutilizable para cada paso del onboarding
///
/// Muestra: título, descripción e ícono centrados
class OnboardingStep extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const OnboardingStep({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ícono grande
          Icon(
            icon,
            size: 120,
            color: Theme.of(context).primaryColor,
          ),

          const SizedBox(height: 48),

          // Título grande
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Descripción
          Text(
            description,
            style: const TextStyle(
              fontSize: 18,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
