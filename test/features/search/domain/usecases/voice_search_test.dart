import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/search/domain/usecases/voice_search.dart';
import 'package:escandoc/core/services/speech_service.dart';

// Mock del service
class MockSpeechService extends Mock implements SpeechService {}

void main() {
  late VoiceSearch useCase;
  late MockSpeechService mockSpeechService;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    mockSpeechService = MockSpeechService();
    useCase = VoiceSearch(speechService: mockSpeechService);

    // Setup default mocks para permisos e inicialización
    when(() => mockSpeechService.initialize())
        .thenAnswer((_) async => true);
    // Stub por defecto para listen — evita MissingStubError en verifyNever
    when(() => mockSpeechService.listen(timeoutSeconds: any(named: 'timeoutSeconds')))
        .thenAnswer((_) async => null);
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
      verify(() => mockSpeechService.initialize()).called(1);
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
      verify(() => mockSpeechService.initialize()).called(1);
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
      verify(() => mockSpeechService.initialize()).called(1);
      verify(() => mockSpeechService.listen(timeoutSeconds: 5)).called(1);
    });

    test('Debe retornar null si inicialización falla', () async {
      // Arrange - Simular que initialize() retorna false
      when(() => mockSpeechService.initialize())
          .thenAnswer((_) async => false);

      // Act
      final result = await useCase.execute();

      // Assert
      expect(result, isNull);
      verify(() => mockSpeechService.initialize()).called(1);
      verifyNever(() => mockSpeechService.listen(timeoutSeconds: any(named: 'timeoutSeconds')));
    });

    test('Debe usar timeout de 5 segundos por defecto', () async {
      // Arrange
      when(() => mockSpeechService.listen(timeoutSeconds: 5))
          .thenAnswer((_) async => 'test');

      // Act
      await useCase.execute();

      // Assert
      verify(() => mockSpeechService.initialize()).called(1);
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
      verify(() => mockSpeechService.initialize()).called(1);
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
      verify(() => mockSpeechService.initialize()).called(1);
      verify(() => mockSpeechService.listen(timeoutSeconds: 5)).called(1);
    });
  });
}
