import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Página de configuración — accesible desde el menú ☰ del home.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
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

  // --- Header: ← "Configuración" centrado ---

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8),
        border:
            Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
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

  // --- Contenido ---

  Widget _buildContent(BuildContext context) {
    final currentLocale = context.locale.languageCode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              offset: const Offset(0, 3),
              blurRadius: 8,
              spreadRadius: -1,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            color: const Color(0xFF9A8060).withOpacity(0.35),
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
            DropdownMenuItem(
              value: 'es',
              child: Text('language_es'.tr()),
            ),
            DropdownMenuItem(
              value: 'en',
              child: Text('language_en'.tr()),
            ),
          ],
          onChanged: (code) {
            if (code != null) context.setLocale(Locale(code));
          },
        ),
      ),
    );
  }
}
