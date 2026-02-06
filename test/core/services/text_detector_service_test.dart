import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:escandoc/core/services/text_detector_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TextDetectorServiceImpl', () {
    late TextDetectorServiceImpl service;
    const channel = MethodChannel('escandoc/text_detector');

    setUp(() {
      service = TextDetectorServiceImpl();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    group('detect()', () {
      test('retorna varianza y hasText cuando detección exitosa', () async {
        // Mock del platform channel
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'detect') {
            expect(methodCall.arguments['imagePath'], '/path/to/image.jpg');
            expect(methodCall.arguments['threshold'], 600.0);
            return {
              'variance': 750.0,
              'hasText': true,
            };
          }
          return null;
        });

        final result = await service.detect('/path/to/image.jpg', threshold: 600.0);

        expect(result['variance'], 750.0);
        expect(result['hasText'], true);
      });

      test('retorna hasText false cuando varianza es baja', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'detect') {
            return {
              'variance': 150.0,
              'hasText': false,
            };
          }
          return null;
        });

        final result = await service.detect('/path/to/photo.jpg', threshold: 600.0);

        expect(result['variance'], 150.0);
        expect(result['hasText'], false);
      });

      test('usa threshold por defecto 600.0 cuando no se especifica', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'detect') {
            expect(methodCall.arguments['threshold'], 600.0);
            return {
              'variance': 500.0,
              'hasText': false,
            };
          }
          return null;
        });

        await service.detect('/path/to/image.jpg');
        // Si llega aquí, el threshold por defecto fue usado correctamente
      });

      test('retorna fallback seguro cuando platform channel falla', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          throw PlatformException(code: 'ERROR', message: 'Native error');
        });

        final result = await service.detect('/path/to/image.jpg');

        expect(result['variance'], 0.0);
        expect(result['hasText'], false);
        expect(result['error'], isNotNull);
      });

      test('retorna fallback seguro cuando resultado es null', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return null;
        });

        final result = await service.detect('/path/to/image.jpg');

        expect(result['variance'], 0.0);
        expect(result['hasText'], false);
        expect(result['error'], 'null_result');
      });

      test('maneja threshold personalizado correctamente', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'detect') {
            expect(methodCall.arguments['threshold'], 800.0);
            return {
              'variance': 750.0,
              'hasText': false, // < 800
            };
          }
          return null;
        });

        final result = await service.detect('/path/to/image.jpg', threshold: 800.0);

        expect(result['hasText'], false);
      });
    });

    group('hasText() [deprecated]', () {
      test('retorna resultado de detect()', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'detect') {
            return {
              'variance': 700.0,
              'hasText': true,
            };
          }
          return null;
        });

        // ignore: deprecated_member_use_from_same_package
        final result = await service.hasText('/path/to/image.jpg', threshold: 600.0);

        expect(result, true);
      });
    });

    group('getVariance() [deprecated]', () {
      test('retorna varianza de detect()', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'detect') {
            return {
              'variance': 450.0,
              'hasText': false,
            };
          }
          return null;
        });

        // ignore: deprecated_member_use_from_same_package
        final result = await service.getVariance('/path/to/image.jpg');

        expect(result, 450.0);
      });
    });
  });
}
