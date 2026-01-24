import 'dart:async';
import 'package:escandoc/core/services/speech_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Implementación del servicio de reconocimiento de voz usando speech_to_text
class SpeechServiceImpl implements SpeechService {
  final stt.SpeechToText _speech;
  String? _lastRecognizedText;
  bool _isInitialized = false;

  SpeechServiceImpl({stt.SpeechToText? speechToText})
      : _speech = speechToText ?? stt.SpeechToText();

  @override
  Future<bool> initialize() async {
    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          // Manejar errores silenciosamente
        },
        onStatus: (status) {
          // Manejar cambios de estado
        },
      );
      return _isInitialized;
    } catch (e) {
      _isInitialized = false;
      return false;
    }
  }

  @override
  Future<String?> listen({int timeoutSeconds = 5}) async {
    if (!_isInitialized) {
      return null;
    }

    _lastRecognizedText = null;
    final completer = Completer<String?>();

    try {
      // Iniciar escucha con locale español
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            _lastRecognizedText = result.recognizedWords;
            if (!completer.isCompleted) {
              completer.complete(_lastRecognizedText);
            }
          } else {
            _lastRecognizedText = result.recognizedWords;
          }
        },
        listenFor: Duration(seconds: timeoutSeconds),
        pauseFor: Duration(seconds: timeoutSeconds),
        localeId: 'es_ES',
      );

      // Timeout: esperar hasta que termine la escucha
      final result = await completer.future.timeout(
        Duration(seconds: timeoutSeconds + 1),
        onTimeout: () {
          // Si no hubo resultado final, retornar el último texto reconocido
          return _lastRecognizedText;
        },
      );

      // Detener escucha si aún está activa
      if (_speech.isListening) {
        await _speech.stop();
      }

      return result;
    } catch (e) {
      // Detener escucha en caso de error
      if (_speech.isListening) {
        await _speech.stop();
      }
      return null;
    }
  }

  @override
  void dispose() {
    _speech.stop();
  }
}
