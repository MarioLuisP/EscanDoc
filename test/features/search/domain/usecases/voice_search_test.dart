import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/search/domain/usecases/voice_search.dart';
import 'package:escandoc/core/services/speech_service.dart';

// Mock del service
class MockSpeechService extends Mock implements SpeechService {}

void main() {
  late VoiceSearch useCase;
  late MockSpeechService mockSpeechService;

  setUp(() {
    mockSpeechService = MockSpeechService();
    useCase = VoiceSearch(speechService: mockSpeechService);
  });

  group('VoiceSearch UseCase', () {
    test('Debe transcribir voz correctamente', () async {
      // Arrange
      const expectedText = 'factura edesur';
      when(() => mockSpeechService.listen(timeoutSeconds: 5))
          .thenAnswer((_) async => expectedText);

      // Act
      final result = await useCase.execute();

      // Assert
      expect(result, expectedText);
      verify(() => mockSpeechService.listen(timeoutSeconds: 5)).called(1);
    });

    test('Debe retornar null si no entiende', () async {
      // Arrange
      when(() => mockSpeechService.listen(timeoutSeconds: 5))
          .thenAnswer((_) async => null);

      // Act
      final result = await useCase.execute();

      // Assert
      expect(result, isNull);
      verify(() => mockSpeechService.listen(timeoutSeconds: 5)).called(1);
    });

    test('Debe retornar null si timeout (5 seg)', () async {
      // Arrange
      when(() => mockSpeechService.listen(timeoutSeconds: 5))
          .thenAnswer((_) async => null);

      // Act
      final result = await useCase.execute();

      // Assert
      expect(result, isNull);
      verify(() => mockSpeechService.listen(timeoutSeconds: 5)).called(1);
    });

    test('Debe manejar permiso denegado', () async {
      // Arrange
      when(() => mockSpeechService.listen(timeoutSeconds: 5))
          .thenThrow(Exception('Permission denied'));

      // Act & Assert
      expect(
        () => useCase.execute(),
        throwsException,
      );
    });

    test('Debe usar timeout de 5 segundos por defecto', () async {
      // Arrange
      when(() => mockSpeechService.listen(timeoutSeconds: 5))
          .thenAnswer((_) async => 'test');

      // Act
      await useCase.execute();

      // Assert
      verify(() => mockSpeechService.listen(timeoutSeconds: 5)).called(1);
    });

    test('Debe retornar texto vacío como válido', () async {
      // Arrange
      when(() => mockSpeechService.listen(timeoutSeconds: 5))
          .thenAnswer((_) async => '');

      // Act
      final result = await useCase.execute();

      // Assert
      expect(result, '');
      verify(() => mockSpeechService.listen(timeoutSeconds: 5)).called(1);
    });

    test('Debe trimear espacios del texto reconocido', () async {
      // Arrange
      const textWithSpaces = '  factura edesur  ';
      when(() => mockSpeechService.listen(timeoutSeconds: 5))
          .thenAnswer((_) async => textWithSpaces);

      // Act
      final result = await useCase.execute();

      // Assert
      expect(result, textWithSpaces.trim());
      verify(() => mockSpeechService.listen(timeoutSeconds: 5)).called(1);
    });
  });
}
