import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Botón de búsqueda por voz con tamaño accesible
class VoiceButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isListening;

  const VoiceButton({
    super.key,
    required this.onPressed,
    this.isListening = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64, // Más grande que 32x32dp para mejor accesibilidad
      height: 64,
      margin: const EdgeInsets.all(16),
      child: FloatingActionButton(
        onPressed: isListening ? null : onPressed,
        tooltip: 'search_voice_button'.tr(),
        backgroundColor: isListening
            ? Colors.grey[400]
            : Theme.of(context).primaryColor,
        child: Icon(
          isListening ? Icons.mic : Icons.mic_none,
          size: 32, // 32x32dp según spec
          color: Colors.white,
        ),
      ),
    );
  }
}
