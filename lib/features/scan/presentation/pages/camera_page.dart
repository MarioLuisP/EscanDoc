import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Página de captura de documento con cámara
/// TODO: Implementar en Fase 1
class CameraPage extends StatelessWidget {
  const CameraPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('scan_document_title'.tr())),
      body: const Center(
        child: Text('Camera Page - TODO'),
      ),
    );
  }
}
