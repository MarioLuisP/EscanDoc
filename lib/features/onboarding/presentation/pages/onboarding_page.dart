import 'package:flutter/material.dart';

/// Página de onboarding (tutorial inicial)
/// TODO: Implementar en Fase 1
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Onboarding')),
      body: const Center(
        child: Text('Onboarding Page - TODO'),
      ),
    );
  }
}
