import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Pastilla "Pág. N" para páginas de un PDF multipágina.
///
/// Vive en la línea de la fecha (no en el título), así el número queda fuera del
/// recorte con "…" del título largo. Tono olivo suave, consistente con la paleta.
/// Solo se muestra cuando el documento es realmente parte de un grupo (el
/// llamador decide con `DocumentGroup`).
class PageNumberChip extends StatelessWidget {
  final int page;
  const PageNumberChip({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0DC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC3D0A0), width: 1),
      ),
      child: Text(
        'page_label'.tr(args: [page.toString()]),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4A6A28),
        ),
      ),
    );
  }
}
