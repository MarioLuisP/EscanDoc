import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:escandoc/core/services/speech_service_impl.dart';

// Mock de SpeechToText
class MockSpeechToText extends Mock implements stt.SpeechToText {}

void main() {
  late SpeechServiceImpl service;
  late MockSpeechToText mockSpeech;

  setUp(() {
    mockSpeech = MockSpeechToText();
    service = SpeechServiceImpl(speechToText: mockSpeech);
  });

  group('SpeechService Tests', () {
    test('Debe inicializar SpeechToText correctamente', () async {
      // Arrange
      when(() => mockSpeech.initialize(
            onError: any(named: 'onError'),
            onStatus: any(named: 'onStatus'),
          )).thenAnswer((_) async => true);

      // Act
      final result = await service.initialize();

      // Assert
      expect(result, isTrue);
      verify(() => mockSpeech.initialize(
            onError: any(named: 'onError'),
            onStatus: any(named: 'onStatus'),
          )).called(1);
    });

    test('Debe retornar false si inicialización falla', () async {
      // Arrange
      when(() => mockSpeech.initialize(
            onError: any(named: 'onError'),
            onStatus: any(named: 'onStatus'),
          )).thenAnswer((_) async => false);

      // Act
      final result = await service.initialize();

      // Assert
      expect(result, isFalse);
    });

    test('Debe capturar texto reconocido', () async {
      // Arrange
      const expectedText = 'factura edesur';

      when(() => mockSpeech.initialize(
            onError: any(named: 'onError'),
            onStatus: any(named: 'onStatus'),
          )).thenAnswer((_) async => true);

      when(() => mockSpeech.listen(
            onResult: any(named: 'onResult'),
            listenFor: any(named: 'listenFor'),
            pauseFor: any(named: 'pauseFor'),
            localeId: any(named: 'localeId'),
          )).thenAnswer((invocation) {
        // Simular callback con resultado
        final onResult =
            invocation.namedArguments[const Symbol('onResult')] as Function;
        final result = MockSpeechRecognitionResult(expectedText, true);
        onResult(result);
        return Future.value();
      });

      when(() => mockSpeech.isListening).thenReturn(true);
      when(() => mockSpeech.stop()).thenAnswer((_) async {});

      await service.initialize();

      // Act
      final result = await service.listen(timeoutSeconds: 5);

      // Assert
      expect(result, expectedText);
    });

    test('Debe detener escucha después de timeout', () async {
      // Arrange
      when(() => mockSpeech.initialize(
            onError: any(named: 'onError'),
            onStatus: any(named: 'onStatus'),
          )).thenAnswer((_) async => true);

      when(() => mockSpeech.listen(
            onResult: any(named: 'onResult'),
            listenFor: any(named: 'listenFor'),
            pauseFor: any(named: 'pauseFor'),
            localeId: any(named: 'localeId'),
          )).thenAnswer((_) async {});

      when(() => mockSpeech.isListening).thenReturn(false);
      when(() => mockSpeech.stop()).thenAnswer((_) async {});

      await service.initialize();

      // Act
      final result = await service.listen(timeoutSeconds: 1);

      // Assert
      expect(result, isNull);
      verify(() => mockSpeech.stop()).called(1);
    });

    test('Debe manejar permiso no otorgado', () async {
      // Arrange
      when(() => mockSpeech.initialize(
            onError: any(named: 'onError'),
            onStatus: any(named: 'onStatus'),
          )).thenAnswer((_) async => false);

      // Act
      final initialized = await service.initialize();

      // Assert
      expect(initialized, isFalse);

      // Intentar escuchar sin inicializar debe retornar null
      final result = await service.listen(timeoutSeconds: 5);
      expect(result, isNull);
    });

    test('Debe usar locale español por defecto', () async {
      // Arrange
      when(() => mockSpeech.initialize(
            onError: any(named: 'onError'),
            onStatus: any(named: 'onStatus'),
          )).thenAnswer((_) async => true);

      when(() => mockSpeech.listen(
            onResult: any(named: 'onResult'),
            listenFor: any(named: 'listenFor'),
            pauseFor: any(named: 'pauseFor'),
            localeId: 'es_ES',
          )).thenAnswer((_) async {});

      when(() => mockSpeech.isListening).thenReturn(false);
      when(() => mockSpeech.stop()).thenAnswer((_) async {});

      await service.initialize();

      // Act
      await service.listen(timeoutSeconds: 5);

      // Assert
      verify(() => mockSpeech.listen(
            onResult: any(named: 'onResult'),
            listenFor: any(named: 'listenFor'),
            pauseFor: any(named: 'pauseFor'),
            localeId: 'es_ES',
          )).called(1);
    });

    test('Debe llamar dispose correctamente', () {
      // Arrange
      when(() => mockSpeech.stop()).thenAnswer((_) async {});

      // Act
      service.dispose();

      // Assert
      verify(() => mockSpeech.stop()).called(1);
    });
  });
}

// Mock de SpeechRecognitionResult
class MockSpeechRecognitionResult implements stt.SpeechRecognitionResult {
  final String _recognizedWords;
  final bool _finalResult;

  MockSpeechRecognitionResult(this._recognizedWords, this._finalResult);

  @override
  String get recognizedWords => _recognizedWords;

  @override
  bool get finalResult => _finalResult;

  @override
  bool get hasConfidenceRating => false;

  @override
  double get confidence => 0.0;

  @override
  List<stt.SpeechRecognitionWords> get alternates => [];
}
