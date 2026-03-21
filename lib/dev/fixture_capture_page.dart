// ARCHIVO TEMPORAL — solo para capturar fixtures de OCR.
// Eliminar una vez capturados los 7 documentos.

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../features/image_processing/format_converter/data/image_format_converter_impl.dart';
import '../features/image_processing/normalize_image/data/image_normalizer_service_impl.dart';

class FixtureCapturePage extends StatefulWidget {
  const FixtureCapturePage({super.key});

  @override
  State<FixtureCapturePage> createState() => _FixtureCapturePageState();
}

class _FixtureCapturePageState extends State<FixtureCapturePage> {
  final _nameController = TextEditingController();
  final _converter = ImageFormatConverterImpl();
  final _normalizer = ImageNormalizerServiceImpl();

  String _status = 'Listo';
  bool _busy = false;
  String? _savedFilePath;

  Future<void> _capture() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _status = 'Ingresá un nombre para el fixture');
      return;
    }

    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) return;

    setState(() {
      _busy = true;
      _status = 'Convirtiendo a JPG...';
    });

    try {
      // Paso 1 — Convertir a JPG
      final jpgPath = await _converter.convertToJpg(result.files.single.path!);

      setState(() => _status = 'Normalizando (resize A4 + compress)...');

      // Paso 3a — Normalizar (mismo que el pipeline real)
      final resizedPath = await _normalizer.resizeToA4IfNeeded(jpgPath);
      final normalizedPath = await _normalizer.normalizeImage(resizedPath, 850 * 1024);

      setState(() => _status = 'Ejecutando OCR...');

      // OCR directo con ML Kit
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final inputImage = InputImage.fromFilePath(normalizedPath);
      final recognized = await recognizer.processImage(inputImage);
      await recognizer.close();

      final blockCount = recognized.blocks.length;
      setState(() => _status = 'Serializando $blockCount bloques...');

      // Serializar — solo los datos que usa blocksToMarkdown
      final blocksJson = recognized.blocks.map((b) => {
        'text': b.text,
        'lines': b.lines.map((l) => {
          'text': l.text,
          'confidence': l.confidence,
          'angle': l.angle,
          'bbox': {
            'left': l.boundingBox.left,
            'top': l.boundingBox.top,
            'right': l.boundingBox.right,
            'bottom': l.boundingBox.bottom,
          },
        }).toList(),
      }).toList();

      final json = jsonEncode({
        'fixtureName': name,
        'blockCount': blockCount,
        'blocks': blocksJson,
      });

      // Guardar en internal storage
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/fixture_$name.json');
      await file.writeAsString(json, flush: true);

      setState(() {
        _savedFilePath = file.path;
        _status = '✅ $blockCount bloques → fixture_$name.json\nPresioná Compartir para exportarlo.';
      });
    } catch (e) {
      setState(() => _status = '❌ Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('[DEV] Capturar Fixture OCR')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del fixture',
                hintText: 'ej: horario, factura_luz, ticket_super',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _busy ? null : _capture,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Seleccionar imagen y capturar'),
            ),
            const SizedBox(height: 24),
            Text(
              _status,
              style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
            ),
            if (_savedFilePath != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Compartir JSON'),
                onPressed: () => SharePlus.instance.share(
                  ShareParams(files: [XFile(_savedFilePath!)]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
