import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:escandoc/core/widgets/notification_permission_dialog.dart';
import 'package:escandoc/features/onboarding/domain/usecases/complete_onboarding.dart';
import 'package:escandoc/features/onboarding/presentation/widgets/onboarding_step.dart';

/// Página de onboarding (tutorial inicial de 3 pasos)
///
/// HU-013: Tutorial inicial obligatorio
/// - Primera vez muestra tutorial
/// - 3 pantallas: Escanear, Buscar, Notas
/// - Al completar, guarda estado y va a home
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // PageView con 3 pasos
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  // Paso 1: Escanear
                  OnboardingStep(
                    title: 'onboarding_step1_title'.tr(),
                    description: 'onboarding_step1_desc'.tr(),
                    icon: Icons.camera_alt,
                  ),

                  // Paso 2: Buscar
                  OnboardingStep(
                    title: 'onboarding_step2_title'.tr(),
                    description: 'onboarding_step2_desc'.tr(),
                    icon: Icons.search,
                  ),

                  // Paso 3: Notas
                  OnboardingStep(
                    title: 'onboarding_step3_title'.tr(),
                    description: 'onboarding_step3_desc'.tr(),
                    icon: Icons.note_add,
                  ),
                ],
              ),
            ),

            // Indicadores de página
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade300,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Botón SIGUIENTE o EMPEZAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _handleButtonPress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: Text(
                    _currentPage < 2
                        ? 'onboarding_next'.tr()
                        : 'onboarding_done'.tr(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  /// Maneja el botón SIGUIENTE o EMPEZAR
  void _handleButtonPress() {
    if (_currentPage < 2) {
      // Avanzar a siguiente página
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Completar onboarding y navegar a home
      _completeOnboarding();
    }
  }

  /// Marca onboarding como completado y navega a home
  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final useCase = CompleteOnboarding(prefs);
    await useCase.call();

    if (!mounted) return;
    await NotificationPermissionDialog.showIfNeeded(context);

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }
}
