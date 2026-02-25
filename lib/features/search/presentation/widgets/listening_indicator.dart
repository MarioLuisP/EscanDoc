import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Indicador animado de escucha por voz
class ListeningIndicator extends StatelessWidget {
  const ListeningIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animación de onda sonora
          const SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _PulsingCircle(delay: 0),
                _PulsingCircle(delay: 400),
                _PulsingCircle(delay: 800),
                Icon(
                  Icons.mic,
                  size: 48,
                  color: Colors.white,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Texto "Escuchando..."
          Text(
            'search_listening'.tr(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Círculo pulsante para animación
class _PulsingCircle extends StatefulWidget {
  final int delay;

  const _PulsingCircle({required this.delay});

  @override
  State<_PulsingCircle> createState() => _PulsingCircleState();
}

class _PulsingCircleState extends State<_PulsingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Delay inicial
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 100 * _animation.value,
          height: 100 * _animation.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 1 - _animation.value),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}
