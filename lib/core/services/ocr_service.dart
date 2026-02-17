import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:escandoc/core/services/ocr_analysis.dart';

/// Interface para servicio de OCR (permite mocking en tests)
abstract class OCRService {
  Future<OcrAnalysis> extractAnalysis(File imageFile);
  void dispose();
}

/// Implementación de OCR usando Google ML Kit Text Recognition
///
/// Características:
/// - Funciona offline (no requiere API key)
/// - Maneja errores sin lanzar excepciones
/// - Retorna [OcrAnalysis.empty] si falla
class OCRServiceImpl implements OCRService {
  final TextRecognizer _textRecognizer;

  OCRServiceImpl()
      : _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Extrae texto e métricas de calidad de una imagen usando ML Kit
  ///
  /// Retorna [OcrAnalysis.empty] si:
  /// - El archivo no existe
  /// - La imagen es inválida
  /// - OCR falla por cualquier razón
  @override
  Future<OcrAnalysis> extractAnalysis(File imageFile) async {
    try {
      if (!imageFile.existsSync() || imageFile.path.isEmpty) {
        return OcrAnalysis.empty;
      }

      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // DEBUG: log estructura completa de ML Kit
      _logOCRStructure(recognizedText);

      // Calcular promedio de confianza de todas las líneas
      final allConfidences = recognizedText.blocks
          .expand((block) => block.lines)
          .map((line) => line.confidence ?? 0.0)
          .toList();

      final avgConf = allConfidences.isEmpty
          ? 0.0
          : allConfidences.reduce((a, b) => a + b) / allConfidences.length;

      return OcrAnalysis(
        text: recognizedText.text,
        blockCount: recognizedText.blocks.length,
        avgConfidence: avgConf,
      );
    } catch (e) {
      return OcrAnalysis.empty;
    }
  }

  /// Libera recursos de ML Kit
  @override
  void dispose() {
    _textRecognizer.close();
  }

  /// DEBUG: imprime la jerarquía completa que devuelve ML Kit
  void _logOCRStructure(RecognizedText result) {
    // ignore_for_file: avoid_print
    print('═══════════════════════════════════════');
    print('OCR DEBUG - texto plano completo:');
    print(result.text);
    print('───────────────────────────────────────');
    print('BLOQUES: ${result.blocks.length}');

    for (var bi = 0; bi < result.blocks.length; bi++) {
      final block = result.blocks[bi];
      print('');
      print('  ┌─ BLOQUE $bi ─────────────────────────');
      print('  │  texto  : "${block.text}"');
      print('  │  bbox   : ${block.boundingBox}');
      print('  │  ángulo : ${block.recognizedLanguages}');
      print('  │  líneas : ${block.lines.length}');

      for (var li = 0; li < block.lines.length; li++) {
        final line = block.lines[li];
        print('  │');
        print('  │  ├─ LÍNEA $li ─────────────────────');
        print('  │  │  texto      : "${line.text}"');
        print('  │  │  bbox       : ${line.boundingBox}');
        print('  │  │  confianza  : ${line.confidence}');
        print('  │  │  ángulo     : ${line.angle}');
        print('  │  │  elementos  : ${line.elements.length}');

        for (var ei = 0; ei < line.elements.length; ei++) {
          final elem = line.elements[ei];
          print('  │  │');
          print('  │  │  └─ ELEM $ei: "${elem.text}"');
          print('  │  │     bbox     : ${elem.boundingBox}');
          print('  │  │     confianza: ${elem.confidence}');
          print('  │  │     ángulo   : ${elem.angle}');
        }
      }
      print('  └───────────────────────────────────────');
    }

    print('═══════════════════════════════════════');
  }
}
