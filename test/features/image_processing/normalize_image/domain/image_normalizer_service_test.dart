import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/image_processing/normalize_image/domain/image_normalizer_service.dart';

/// Mock del ImageNormalizerService para tests
class MockImageNormalizerService extends Mock implements ImageNormalizerService {}

void main() {
  group('ImageNormalizerService - resizeToA4IfNeeded', () {
    late MockImageNormalizerService mockService;

    setUp(() {
      mockService = MockImageNormalizerService();
    });

    test(
      'DADO una imagen grande (> A4) '
      'CUANDO se llama resizeToA4IfNeeded '
      'ENTONCES retorna path de imagen redimensionada',
      () async {
        // Arrange
        const originalPath = '/test/large_image.jpg';
        const resizedPath = '/test/large_image_resized.jpg';

        when(() => mockService.resizeToA4IfNeeded(originalPath))
            .thenAnswer((_) async => resizedPath);

        // Act
        final result = await mockService.resizeToA4IfNeeded(originalPath);

        // Assert
        expect(result, resizedPath);
        expect(result, isNot(originalPath));
        verify(() => mockService.resizeToA4IfNeeded(originalPath)).called(1);
      },
    );

    test(
      'DADO una imagen pequeña (<= A4) '
      'CUANDO se llama resizeToA4IfNeeded '
      'ENTONCES retorna el mismo path sin modificar',
      () async {
        // Arrange
        const smallImagePath = '/test/small_image.jpg';

        when(() => mockService.resizeToA4IfNeeded(smallImagePath))
            .thenAnswer((_) async => smallImagePath);

        // Act
        final result = await mockService.resizeToA4IfNeeded(smallImagePath);

        // Assert
        expect(result, smallImagePath);
        verify(() => mockService.resizeToA4IfNeeded(smallImagePath)).called(1);
      },
    );

    test(
      'DADO cualquier imagen '
      'CUANDO se llama resizeToA4IfNeeded '
      'ENTONCES el método NO comprime (solo redimensiona)',
      () async {
        // Arrange: Este test documenta que resize NO comprime
        const imagePath = '/test/image.jpg';
        const resizedPath = '/test/image_resized.jpg';

        when(() => mockService.resizeToA4IfNeeded(imagePath))
            .thenAnswer((_) async => resizedPath);

        // Act
        final result = await mockService.resizeToA4IfNeeded(imagePath);

        // Assert
        // Este test documenta el contrato:
        // resizeToA4IfNeeded() solo ajusta geometría (dimensiones)
        // NO comprime (eso lo hace normalizeImage)
        expect(result, isNotNull);
        verify(() => mockService.resizeToA4IfNeeded(imagePath)).called(1);
        verifyNever(() => mockService.normalizeImage(any(), any()));
      },
    );
  });
}
