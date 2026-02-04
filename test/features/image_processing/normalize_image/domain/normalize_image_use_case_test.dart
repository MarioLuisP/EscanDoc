import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/image_processing/normalize_image/domain/normalize_image_use_case.dart';
import 'package:escandoc/features/image_processing/normalize_image/domain/image_normalizer_service.dart';

// Mock del servicio que hará la normalización real
class MockImageNormalizerService extends Mock
    implements ImageNormalizerService {}

void main() {
  late NormalizeImageUseCase useCase;
  late MockImageNormalizerService mockService;

  setUp(() {
    mockService = MockImageNormalizerService();
    useCase = NormalizeImageUseCase(mockService);
  });

  group('NormalizeImageUseCase', () {
    const testImagePath = '/test/path/image.jpg';
    const normalizedImagePath = '/test/path/image_normalized.jpg';

    test(
      'DADO una imagen <= 850 KB '
      'CUANDO se ejecuta el use case '
      'ENTONCES retorna el mismo path sin normalizar',
      () async {
        // Arrange
        const imageSize = 800 * 1024; // 800 KB
        when(() => mockService.getFileSize(testImagePath))
            .thenReturn(imageSize);

        // Act
        final result = await useCase.execute(testImagePath);

        // Assert
        expect(result, testImagePath);
        verify(() => mockService.getFileSize(testImagePath)).called(1);
        verifyNever(() => mockService.normalizeImage(any(), any()));
      },
    );

    test(
      'DADO una imagen > 850 KB '
      'CUANDO se ejecuta el use case '
      'ENTONCES comprime la imagen y retorna nuevo path',
      () async {
        // Arrange
        const imageSize = 1200 * 1024; // 1.2 MB
        when(() => mockService.getFileSize(testImagePath))
            .thenReturn(imageSize);
        when(() => mockService.normalizeImage(testImagePath, any()))
            .thenAnswer((_) async => normalizedImagePath);
        when(() => mockService.getFileSize(normalizedImagePath))
            .thenReturn(800 * 1024); // 800 KB después de normalizar

        // Act
        final result = await useCase.execute(testImagePath);

        // Assert
        expect(result, normalizedImagePath);
        verify(() => mockService.getFileSize(testImagePath)).called(1);
        verify(() => mockService.normalizeImage(testImagePath, any()))
            .called(1);
      },
    );

    test(
      'DADO una imagen > 850 KB '
      'CUANDO se normaliza '
      'ENTONCES el resultado es <= 850 KB',
      () async {
        // Arrange
        const imageSize = 1500 * 1024; // 1.5 MB
        const targetSize = 850 * 1024; // 850 KB
        when(() => mockService.getFileSize(testImagePath))
            .thenReturn(imageSize);
        when(() => mockService.normalizeImage(testImagePath, targetSize))
            .thenAnswer((_) async => normalizedImagePath);
        when(() => mockService.getFileSize(normalizedImagePath))
            .thenReturn(800 * 1024); // 800 KB

        // Act
        final result = await useCase.execute(testImagePath);

        // Assert
        final resultSize = mockService.getFileSize(result);
        expect(resultSize, lessThanOrEqualTo(targetSize));
      },
    );

    test(
      'DADO una imagen PNG (iOS) '
      'CUANDO se ejecuta el use case '
      'ENTONCES convierte a JPG antes de normalizar',
      () async {
        // Arrange
        const pngImagePath = '/test/path/image.png';
        const jpgImagePath = '/test/path/image.jpg';
        const imageSize = 2000 * 1024; // 2 MB (PNG típico)

        when(() => mockService.getFileSize(pngImagePath))
            .thenReturn(imageSize);
        when(() => mockService.convertToJpg(pngImagePath))
            .thenAnswer((_) async => jpgImagePath);
        when(() => mockService.getFileSize(jpgImagePath))
            .thenReturn(1200 * 1024); // 1.2 MB después de convertir
        when(() => mockService.normalizeImage(jpgImagePath, any()))
            .thenAnswer((_) async => normalizedImagePath);
        when(() => mockService.getFileSize(normalizedImagePath))
            .thenReturn(800 * 1024);

        // Act
        final result = await useCase.execute(pngImagePath);

        // Assert
        expect(result, normalizedImagePath);
        verify(() => mockService.convertToJpg(pngImagePath)).called(1);
        verify(() => mockService.normalizeImage(jpgImagePath, any()))
            .called(1);
      },
    );

    test(
      'DADO una imagen muy grande que no se normaliza con calidad mínima '
      'CUANDO se ejecuta el use case '
      'ENTONCES aplica fallback (redimensionar + comprimir)',
      () async {
        // Arrange
        const hugeImageSize = 5000 * 1024; // 5 MB
        const targetSize = 850 * 1024;

        when(() => mockService.getFileSize(testImagePath))
            .thenReturn(hugeImageSize);
        when(() => mockService.normalizeImage(testImagePath, targetSize))
            .thenAnswer((_) async => normalizedImagePath);
        when(() => mockService.getFileSize(normalizedImagePath))
            .thenReturn(800 * 1024); // Después de fallback

        // Act
        final result = await useCase.execute(testImagePath);

        // Assert
        expect(result, normalizedImagePath);
        final resultSize = mockService.getFileSize(result);
        expect(resultSize, lessThanOrEqualTo(targetSize));
      },
    );
  });
}
