/// Servicio de reconocimiento de voz
///
/// Wrapper del paquete speech_to_text para búsqueda por voz offline.
abstract class SpeechService {
  /// Inicializa el servicio de reconocimiento de voz
  ///
  /// Retorna true si se inicializó correctamente.
  /// Puede lanzar excepción si los permisos son denegados.
  Future<bool> initialize();

  /// Escucha el audio del usuario y retorna el texto reconocido
  ///
  /// [timeoutSeconds]: Tiempo máximo de escucha (default 5 segundos)
  ///
  /// Retorna:
  /// - String con texto reconocido si tiene éxito
  /// - null si timeout o no entiende el audio
  ///
  /// Lanza excepción si hay error de permisos.
  Future<String?> listen({int timeoutSeconds = 5});

  /// Libera recursos del servicio
  void dispose();
}
