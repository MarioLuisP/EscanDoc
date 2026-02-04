// ═══════════════════════════════════════════════════════════════════════════
// SPIKE TÉCNICO - Código temporal descartable (Épica 6 - Etapa 0 - Plan B)
// ═══════════════════════════════════════════════════════════════════════════
// NO seguir arquitectura Clean aquí - es solo para validación técnica
// Decisión GO/NO-GO basada en esta prueba
// Probando: cunning_document_scanner (MLKit)
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';

class ScannerSpikePage extends StatefulWidget {
  const ScannerSpikePage({super.key});

  @override
  State<ScannerSpikePage> createState() => _ScannerSpikePageState();
}

class _ScannerSpikePageState extends State<ScannerSpikePage> {
  Uint8List? _scannedImage;
  String _debugInfo = '';
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    // Auto-iniciar scanner al abrir la página
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScanning();
    });
  }

  Future<void> _startScanning() async {
    setState(() {
      _isScanning = true;
      _debugInfo = 'Iniciando scanner...';
    });

    try {
      debugPrint('🧪 [SPIKE] Iniciando cunning_document_scanner...');

      final pictures = await CunningDocumentScanner.getPictures(
        noOfPages: 1, // Solo una página
        isGalleryImportAllowed: false, // Solo cámara
      ) ?? [];

      if (!mounted) return;

      if (pictures.isEmpty) {
        // Usuario canceló
        debugPrint('⚠️ [SPIKE] Usuario canceló el escaneo');
        Navigator.pop(context);
        return;
      }

      final imagePath = pictures.first;
      debugPrint('✅ [SPIKE] Imagen capturada: $imagePath');

      // Leer archivo y convertir a bytes
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();

      setState(() {
        _scannedImage = imageBytes;
        _isScanning = false;
        _debugInfo = '''
📸 IMAGEN CAPTURADA (CUNNING + MLKit)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Path: $imagePath
✅ Tamaño: ${(imageBytes.length / 1024 / 1024).toStringAsFixed(2)} MB
✅ Bytes: ${imageBytes.length}
✅ Tecnología: MLKit (Android) / VisionKit (iOS)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Validar:
1. ¿La imagen está recortada correctamente?
2. ¿Se ve clara y legible?
3. ¿Crop fácil de ajustar?
4. ¿Tiempo aceptable?
      ''';
      });

      debugPrint('✅ [SPIKE] Imagen procesada: ${imageBytes.length} bytes');
    } catch (e) {
      debugPrint('❌ [SPIKE] Error: $e');
      if (!mounted) return;

      setState(() {
        _isScanning = false;
        _debugInfo = 'Error: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al escanear: $e'),
          backgroundColor: Colors.red,
        ),
      );

      // Volver atrás si hay error
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isScanning
            ? _buildLoadingView()
            : _scannedImage != null
                ? _buildResultView()
                : _buildErrorView(),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Colors.white,
          ),
          const SizedBox(height: 24),
          Text(
            _debugInfo,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            _debugInfo,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            label: const Text('CERRAR'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.orange[700],
          child: const Text(
            '🧪 SPIKE: Cunning Scanner (MLKit)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // Image preview
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.orange[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                _scannedImage!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),

        // Debug info
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _debugInfo,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),

        // Actions
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _scannedImage = null;
                      _debugInfo = '';
                    });
                    _startScanning();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('REINTENTAR'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('FINALIZAR'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
