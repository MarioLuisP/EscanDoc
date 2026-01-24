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
  /// - Ocurre un error de permisos (lanza excepción)
  Future<String?> execute() async {
    final text = await speechService.listen(timeoutSeconds: 5);

    if (text == null) {
      return null;
    }

    return text.trim();
  }
}
