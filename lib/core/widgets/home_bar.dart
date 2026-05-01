import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Barra fija inferior con botón "Inicio" para pantallas secundarias.
/// Se usa como bottomNavigationBar del Scaffold.
class HomeBar extends StatelessWidget {
  const HomeBar({super.key});

  @override
  Widget build(BuildContext context) {
    EasyLocalization.of(context)?.locale;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8),
        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(56, 10, 56, 14),
          child: _HomeButton(
            onTap: () => Navigator.popUntil(
              context,
              ModalRoute.withName('/home'),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  final VoidCallback onTap;
  const _HomeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF3F5EC), Color(0xFFD8E0C0)],
        ),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: const Color(0xFFA2B882), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A8A50).withValues(alpha: 0.40),
            offset: const Offset(0, 3),
            blurRadius: 6,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          splashColor: const Color(0xFFA2B882).withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.home_outlined, size: 18, color: Color(0xFF4A6A28)),
                const SizedBox(width: 6),
                Text(
                  'go_home'.tr(),
                  style: const TextStyle(
                    fontSize: 17,
                    color: Color(0xFF4A6A28),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
