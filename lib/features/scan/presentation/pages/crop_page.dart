import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Página de recorte y ajuste de bordes del documento
/// TODO: Implementar en Fase 1
class CropPage extends StatelessWidget {
  const CropPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('adjust_document_title'.tr())),
      body: const Center(
        child: Text('Crop Page - TODO'),
      ),
    );
  }
}
