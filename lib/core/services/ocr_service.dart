import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:escandoc/core/services/ocr_analysis.dart';
import 'package:escandoc/core/services/blocks_to_markdown.dart';
import 'package:escandoc/core/services/document_orientation_service.dart';

/// Interface para servicio de OCR (permite mocking en tests)
abstract class OCRService {
  Future<OcrAnalysis> extractAnalysis(File imageFile, {String docType = 'documento'});

  /// Regenera el markdown del último OCR con un [docType] distinto.
  ///
  /// Útil cuando el refinamiento cambia el tipo después de que el markdown
  /// ya fue generado (ej: documento → recibo necesita formato tabla).
  /// Retorna '' si no hay OCR previo o si la imagen estaba rotada.
  String rebuildMarkdown(String docType);

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
  List<OcrBlock> _lastOcrBlocks = [];
  int _lastDetectedDegrees = 0;

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
      final recognizedText = await _textRecognizer
          .processImage(inputImage)
          .timeout(const Duration(seconds: 30));
      _lastOcrBlocks = _toOcrBlocks(recognizedText.blocks);

      // DEBUG: log estructura completa de ML Kit (descomentar para diagnóstico)
      // _logOCRStructure(recognizedText);

      // Aspect ratio desde bboxes (altura/ancho del área total reconocida)
      double imageAspectRatio = 0.0;
      if (_lastOcrBlocks.isNotEmpty) {
        final ocrLines = _lastOcrBlocks.expand((b) => b.lines).toList();
        final minTop    = ocrLines.map((l) => l.top).reduce((a, b) => a < b ? a : b);
        final maxBottom = ocrLines.map((l) => l.bottom).reduce((a, b) => a > b ? a : b);
        final minLeft   = ocrLines.map((l) => l.left).reduce((a, b) => a < b ? a : b);
        final maxRight  = ocrLines.map((l) => l.right).reduce((a, b) => a > b ? a : b);
        final h = maxBottom - minTop;
        final w = maxRight - minLeft;
        imageAspectRatio = w > 0 ? h / w : 0.0;
      }

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

      // Detectar rotación dominante para corrección post-OCR
      final allAngles = allLines.map((l) => l.angle).whereType<double>().toList();
      final detected = detectOrientationDegrees(allAngles);
      _lastDetectedDegrees = detected;
      final rotationCorrection = (360 - detected) % 360;

      // Generar markdown solo si la imagen ya está orientada correctamente.
      // Si hay rotación, ProcessOCR rotará el JPG y hará un 2do OCR —
      // este markdown se descartaría de todos modos.
      final markdown = rotationCorrection == 0
          ? blocksToMarkdown(_lastOcrBlocks, documentTypeFromString(docType), detected)
          : '';

      return OcrAnalysis(
        text: markdown,
        blockCount: recognizedText.blocks.length,
        avgConfidence: avgConf,
        topConfidenceText: topConfidenceText,
        detectedRotationDegrees: rotationCorrection,
        imageAspectRatio: imageAspectRatio,
      );
    } catch (e) {
      return OcrAnalysis.empty;
    }
  }

  @override
  String rebuildMarkdown(String docType) {
    if (_lastOcrBlocks.isEmpty) return '';
    return blocksToMarkdown(
      _lastOcrBlocks,
      documentTypeFromString(docType),
      _lastDetectedDegrees,
    );
  }

  /// Convierte bloques de ML Kit al DTO interno, desacoplando de google_mlkit.
  List<OcrBlock> _toOcrBlocks(List<TextBlock> blocks) => blocks.map((b) =>
    OcrBlock(
      lines: b.lines.map((l) => OcrLine(
        text:   l.text,
        left:   l.boundingBox.left,
        top:    l.boundingBox.top,
        right:  l.boundingBox.right,
        bottom: l.boundingBox.bottom,
      )).toList(),
    ),
  ).toList();

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

    print('OCR DEBUG - texto plano completo:');
    print(result.text);
    print('───────────────────────────────────────');
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
  }
}
