import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/scan/domain/usecases/detect_and_fix_orientation.dart';
import 'package:escandoc/core/services/document_orientation_service.dart';

class MockDocumentOrientationService extends Mock
    implements DocumentOrientationService {}

class FakeFile extends Fake implements File {}

void main() {
  late DetectAndFixOrientation useCase;
  late MockDocumentOrientationService mockService;
  late File originalFile;
  late File rotatedFile;
  late File doubleRotatedFile;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(FakeFile());
  });

  setUp(() {
    mockService = MockDocumentOrientationService();
    useCase = DetectAndFixOrientation(mockService);
    originalFile = File('original.jpg');
    rotatedFile = File('rotated.jpg');
    doubleRotatedFile = File('double_rotated.jpg');
  });

  group('DetectAndFixOrientation', () {
    test('imagen derecha (EXIF=0, contenido=0): retorna original sin rotar', () async {
      when(() => mockService.readExifRotation(originalFile))
          .thenAnswer((_) async => 0);
      when(() => mockService.detectContentRotation(originalFile))
          .thenAnswer((_) async => 0);

      final result = await useCase.call(originalFile);

      expect(result, same(originalFile));
      verifyNever(() => mockService.rotateImage(any(), any()));
    });

    test('solo EXIF (90°): rota por EXIF, luego verifica contenido sobre archivo rotado', () async {
      when(() => mockService.readExifRotation(originalFile))
          .thenAnswer((_) async => 90);
      when(() => mockService.rotateImage(originalFile, 90))
          .thenAnswer((_) async => rotatedFile);
      when(() => mockService.detectContentRotation(rotatedFile))
          .thenAnswer((_) async => 0);

      final result = await useCase.call(originalFile);

      expect(result, same(rotatedFile));
      verify(() => mockService.rotateImage(originalFile, 90)).called(1);
      verify(() => mockService.detectContentRotation(rotatedFile)).called(1);
      verifyNever(() => mockService.rotateImage(rotatedFile, any()));
    });

    test('solo contenido (270°): no rota por EXIF, rota por contenido', () async {
      when(() => mockService.readExifRotation(originalFile))
          .thenAnswer((_) async => 0);
      when(() => mockService.detectContentRotation(originalFile))
          .thenAnswer((_) async => 270);
      when(() => mockService.rotateImage(originalFile, 270))
          .thenAnswer((_) async => rotatedFile);

      final result = await useCase.call(originalFile);

      expect(result, same(rotatedFile));
      verify(() => mockService.rotateImage(originalFile, 270)).called(1);
    });

    test('EXIF + contenido: rota dos veces, contenido se verifica sobre archivo ya rotado por EXIF',
        () async {
      when(() => mockService.readExifRotation(originalFile))
          .thenAnswer((_) async => 90);
      when(() => mockService.rotateImage(originalFile, 90))
          .thenAnswer((_) async => rotatedFile);
      when(() => mockService.detectContentRotation(rotatedFile))
          .thenAnswer((_) async => 180);
      when(() => mockService.rotateImage(rotatedFile, 180))
          .thenAnswer((_) async => doubleRotatedFile);

      final result = await useCase.call(originalFile);

      expect(result, same(doubleRotatedFile));
      verify(() => mockService.rotateImage(originalFile, 90)).called(1);
      verify(() => mockService.detectContentRotation(rotatedFile)).called(1);
      verify(() => mockService.rotateImage(rotatedFile, 180)).called(1);
    });

    test('EXIF=180: rota 180°, contenido sobre archivo ya rotado', () async {
      when(() => mockService.readExifRotation(originalFile))
          .thenAnswer((_) async => 180);
      when(() => mockService.rotateImage(originalFile, 180))
          .thenAnswer((_) async => rotatedFile);
      when(() => mockService.detectContentRotation(rotatedFile))
          .thenAnswer((_) async => 0);

      final result = await useCase.call(originalFile);

      expect(result, same(rotatedFile));
      verify(() => mockService.rotateImage(originalFile, 180)).called(1);
    });
  });
}
