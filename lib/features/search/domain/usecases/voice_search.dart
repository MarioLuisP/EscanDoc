import 'package:flutter/foundation.dart';
import 'package:escandoc/core/services/speech_service.dart';

/// UseCase para búsqueda por voz
///
/// Orquesta el reconocimiento de voz para convertir
/// audio en texto que se puede usar para búsqueda.
class VoiceSearch {
  final SpeechService speechService;

  const VoiceSearch({required this.speechService});

  /// Ejecuta el reconocimiento de voz
  ///
  /// Retorna el texto reconocido (trimmed) o null si:
  /// - El usuario no habla (timeout 5 segundos)
  /// - El servicio no entiende el audio
  /// - Ocurre un error de permisos o inicialización
  Future<String?> execute() async {
    try {
      // 1. Inicializar servicio de voz (incluye solicitud de permisos)
      debugPrint('[VoiceSearch] Inicializando servicio de voz...');
      final initialized = await speechService.initialize();

      if (!initialized) {
        debugPrint('[VoiceSearch] ERROR: No se pudo inicializar el servicio de voz');
        return null;
      }

      debugPrint('[VoiceSearch] Servicio de voz inicializado exitosamente');

      // 2. Escuchar audio del usuario
      debugPrint('[VoiceSearch] Iniciando escucha...');
      final text = await speechService.listen(timeoutSeconds: 5);

      debugPrint('[VoiceSearch] Texto reconocido: "$text"');

      if (text == null) {
        return null;
      }

      return text.trim();
    } catch (e, stackTrace) {
      debugPrint('[VoiceSearch] ERROR: $e');
      debugPrint('[VoiceSearch] StackTrace: $stackTrace');
      return null;
    }
  }
}
