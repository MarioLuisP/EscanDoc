import 'package:flutter_test/flutter_test.dart';
import 'package:escandoc/core/services/speech_service_impl.dart';

void main() {
  late SpeechServiceImpl service;

  setUp(() {
    service = SpeechServiceImpl();
  });

  tearDown(() {
    service.dispose();
  });

  group('SpeechService Tests', () {
    test('Debe crear instancia del servicio', () {
      // Assert
      expect(service, isNotNull);
    });

    test('Debe tener método initialize', () async {
      // Act - Solo verificamos que el método existe y retorna un Future<bool>
      final result = service.initialize();

      // Assert
      expect(result, isA<Future<bool>>());
    });

    test('Debe tener método listen con timeout', () async {
      // Act - Solo verificamos que el método existe y acepta timeout
      final result = service.listen(timeoutSeconds: 1);

      // Assert
      expect(result, isA<Future<String?>>());
    });

    test('Debe tener método dispose', () {
      // Act & Assert - Solo verificamos que el método existe y no lanza excepción
      expect(() => service.dispose(), returnsNormally);
    });

    test('Listen debe retornar null si no está inicializado', () async {
      // Act - Intentar escuchar sin inicializar
      final result = await service.listen(timeoutSeconds: 1);

      // Assert
      expect(result, isNull);
    });
  });
}
