import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:escandoc/core/services/speech_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

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
      // 1. Solicitar permisos de micrófono
      debugPrint('[SpeechService] Solicitando permisos de micrófono...');
      try {
        final status = await Permission.microphone.request();

        if (!status.isGranted) {
          debugPrint('[SpeechService] Permiso de micrófono denegado: $status');
          _isInitialized = false;
          return false;
        }
        debugPrint('[SpeechService] Permiso de micrófono otorgado');
      } catch (e) {
        // En entorno de tests, permission_handler no está disponible
        // Continuamos sin verificar permisos
        debugPrint('[SpeechService] No se pudo verificar permisos (probablemente tests): $e');
      }

      // 2. Inicializar speech_to_text
      debugPrint('[SpeechService] Inicializando speech_to_text...');
      _isInitialized = await _speech.initialize(
        onError: (error) {
          debugPrint('[SpeechService] Error: ${error.errorMsg}');
        },
        onStatus: (status) {
          debugPrint('[SpeechService] Status: $status');
        },
      );
      debugPrint('[SpeechService] Inicializado: $_isInitialized');
      return _isInitialized;
    } catch (e) {
      debugPrint('[SpeechService] ERROR al inicializar: $e');
      _isInitialized = false;
      return false;
    }
  }

  @override
  Future<String?> listen({int timeoutSeconds = 5}) async {
    if (!_isInitialized) {
      debugPrint('[SpeechService] ERROR: Servicio no inicializado');
      return null;
    }

    debugPrint('[SpeechService] Iniciando escucha (timeout: ${timeoutSeconds}s)...');
    _lastRecognizedText = null;
    final completer = Completer<String?>();

    try {
      // Iniciar escucha con locale español
      await _speech.listen(
        onResult: (result) {
          debugPrint('[SpeechService] Resultado: "${result.recognizedWords}" (final: ${result.finalResult})');
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

      debugPrint('[SpeechService] Escuchando...');

      // Timeout: esperar hasta que termine la escucha
      final result = await completer.future.timeout(
        Duration(seconds: timeoutSeconds + 1),
        onTimeout: () {
          debugPrint('[SpeechService] Timeout alcanzado. Último texto: "$_lastRecognizedText"');
          // Si no hubo resultado final, retornar el último texto reconocido
          return _lastRecognizedText;
        },
      );

      // Detener escucha si aún está activa
      if (_speech.isListening) {
        debugPrint('[SpeechService] Deteniendo escucha...');
        await _speech.stop();
      }

      debugPrint('[SpeechService] Resultado final: "$result"');
      return result;
    } catch (e, stackTrace) {
      // Detener escucha en caso de error
      debugPrint('[SpeechService] ERROR durante escucha: $e');
      debugPrint('[SpeechService] StackTrace: $stackTrace');
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
