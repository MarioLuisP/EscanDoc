import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Interface para servicio de OCR (permite mocking en tests)
abstract class OCRService {
  Future<String> extractText(File imageFile);
  void dispose();
}

/// Implementación de OCR usando Google ML Kit Text Recognition
///
/// Características:
/// - Funciona offline (no requiere API key)
/// - Maneja errores sin lanzar excepciones
/// - Retorna string vacío si falla
class OCRServiceImpl implements OCRService {
  final TextRecognizer _textRecognizer;

  OCRServiceImpl()
      : _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Extrae texto de una imagen usando ML Kit
  ///
  /// Retorna string vacío si:
  /// - El archivo no existe
  /// - La imagen es inválida
  /// - OCR falla por cualquier razón
  @override
  Future<String> extractText(File imageFile) async {
    try {
      // Validar que el archivo existe
      if (!imageFile.existsSync()) {
        return '';
      }

      // Validar path no vacío
      if (imageFile.path.isEmpty) {
        return '';
      }

      // Procesar imagen
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      return recognizedText.text;
    } catch (e) {
      // Error de OCR: retornar vacío sin lanzar excepción
      return '';
    }
  }

  /// Libera recursos de ML Kit
  @override
  void dispose() {
    _textRecognizer.close();
  }
}
