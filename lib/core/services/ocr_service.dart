import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:escandoc/core/services/ocr_analysis.dart';
import 'package:escandoc/core/services/blocks_to_markdown.dart';

/// Interface para servicio de OCR (permite mocking en tests)
abstract class OCRService {
  Future<OcrAnalysis> extractAnalysis(File imageFile, {String docType = 'documento'});
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
  Future<OcrAnalysis> extractAnalysis(File imageFile, {String docType = 'documento'}) async {
    try {
      if (!imageFile.existsSync() || imageFile.path.isEmpty) {
        return OcrAnalysis.empty;
      }

      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // DEBUG: log estructura completa de ML Kit
      _logOCRStructure(recognizedText);

      // Recopilar todas las líneas para métricas
      final allLines = recognizedText.blocks
          .expand((block) => block.lines)
          .toList();

      // Promedio de confianza
      final avgConf = allLines.isEmpty
          ? 0.0
          : allLines.map((l) => l.confidence ?? 0.0).reduce((a, b) => a + b) /
              allLines.length;

      // Top-5 líneas por confianza (solo las que tienen texto útil)
      final sortedLines = List.of(allLines)
        ..sort((a, b) =>
            (b.confidence ?? 0.0).compareTo(a.confidence ?? 0.0));
      final topConfidenceText = sortedLines
          .where((l) => l.text.trim().length > 2)
          .take(5)
          .map((l) => l.text.trim())
          .join(' ');

      // Convertir bloques estructurados a Markdown
      final markdown = blocksToMarkdown(
        recognizedText.blocks,
        documentTypeFromString(docType),
      );

      // Detectar rotación dominante para corrección post-OCR
      final allAngles = allLines.map((l) => l.angle).whereType<double>().toList();
      final detected = detectOrientationDegrees(allAngles);
      final rotationCorrection = (360 - detected) % 360;

      return OcrAnalysis(
        text: markdown,
        blockCount: recognizedText.blocks.length,
        avgConfidence: avgConf,
        topConfidenceText: topConfidenceText,
        detectedRotationDegrees: rotationCorrection,
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
    print('BLOQUES: ${result.blocks.length}');
    print('═══════════════════════════════════════');

    // Para ver texto plano + jerarquía completa (bloques/líneas/elementos),
    // descomentar desde aquí hasta el final de la función:
    //
    // print('OCR DEBUG - texto plano completo:');
    // print(result.text);
    // print('───────────────────────────────────────');
    // for (var bi = 0; bi < result.blocks.length; bi++) {
    //   final block = result.blocks[bi];
    //   print('');
    //   print('  ┌─ BLOQUE $bi ─────────────────────────');
    //   print('  │  texto  : "${block.text}"');
    //   print('  │  bbox   : ${block.boundingBox}');
    //   print('  │  ángulo : ${block.recognizedLanguages}');
    //   print('  │  líneas : ${block.lines.length}');
    //   for (var li = 0; li < block.lines.length; li++) {
    //     final line = block.lines[li];
    //     print('  │');
    //     print('  │  ├─ LÍNEA $li ─────────────────────');
    //     print('  │  │  texto      : "${line.text}"');
    //     print('  │  │  bbox       : ${line.boundingBox}');
    //     print('  │  │  confianza  : ${line.confidence}');
    //     print('  │  │  ángulo     : ${line.angle}');
    //     print('  │  │  elementos  : ${line.elements.length}');
    //     for (var ei = 0; ei < line.elements.length; ei++) {
    //       final elem = line.elements[ei];
    //       print('  │  │');
    //       print('  │  │  └─ ELEM $ei: "${elem.text}"');
    //       print('  │  │     bbox     : ${elem.boundingBox}');
    //       print('  │  │     confianza: ${elem.confidence}');
    //       print('  │  │     ángulo   : ${elem.angle}');
    //     }
    //   }
    //   print('  └───────────────────────────────────────');
    // }
  }
}
