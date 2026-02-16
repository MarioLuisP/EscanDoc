import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:escandoc/features/image_processing/thumbnail/domain/thumbnail_generator.dart';

/// Mock implementation para tests
class MockThumbnailGenerator implements ThumbnailGenerator {
  File? thumbnailToReturn;
  String? lastImagePath;
  int? lastMaxWidth;

  @override
  Future<File> generateThumbnail(
    String imagePath, {
    int maxWidth = 400,
  }) async {
    lastImagePath = imagePath;
    lastMaxWidth = maxWidth;

    if (thumbnailToReturn != null) {
      return thumbnailToReturn!;
    }

    // Fallback: retornar archivo con path modificado
    return File('${imagePath}_thumb.jpg');
  }
}

void main() {
  group('ThumbnailGenerator (Domain)', () {
    late MockThumbnailGenerator thumbnailGenerator;

    setUp(() {
      thumbnailGenerator = MockThumbnailGenerator();
    });

    test('debe generar thumbnail con maxWidth por defecto (400px)', () async {
      // Arrange
      const imagePath = '/path/to/image.jpg';
      final expectedThumbnail = File('/path/to/image_thumb.jpg');
      thumbnailGenerator.thumbnailToReturn = expectedThumbnail;

      // Act
      final result = await thumbnailGenerator.generateThumbnail(imagePath);

      // Assert
      expect(result.path, expectedThumbnail.path);
      expect(thumbnailGenerator.lastImagePath, imagePath);
      expect(thumbnailGenerator.lastMaxWidth, 400); // Default
    });

    test('debe generar thumbnail con maxWidth personalizado', () async {
      // Arrange
      const imagePath = '/path/to/image.jpg';
      const customWidth = 600;
      final expectedThumbnail = File('/path/to/image_thumb.jpg');
      thumbnailGenerator.thumbnailToReturn = expectedThumbnail;

      // Act
      final result = await thumbnailGenerator.generateThumbnail(
        imagePath,
        maxWidth: customWidth,
      );

      // Assert
      expect(result.path, expectedThumbnail.path);
      expect(thumbnailGenerator.lastImagePath, imagePath);
      expect(thumbnailGenerator.lastMaxWidth, customWidth);
    });

    test('debe retornar File con el thumbnail generado', () async {
      // Arrange
      const imagePath = '/original/image.jpg';
      final thumbnailFile = File('/thumbnails/image_thumb.jpg');
      thumbnailGenerator.thumbnailToReturn = thumbnailFile;

      // Act
      final result = await thumbnailGenerator.generateThumbnail(imagePath);

      // Assert
      expect(result, isA<File>());
      expect(result.path, thumbnailFile.path);
    });

    test('debe manejar paths con diferentes extensiones', () async {
      // Arrange
      final testCases = [
        '/path/to/photo.jpg',
        '/path/to/document.png',
        '/path/to/scan.jpeg',
        '/path/to/file.webp',
      ];

      for (final imagePath in testCases) {
        // Act
        final result = await thumbnailGenerator.generateThumbnail(imagePath);

        // Assert
        expect(result, isA<File>());
        expect(thumbnailGenerator.lastImagePath, imagePath);
      }
    });

    test('debe preservar el contrato de la interfaz', () async {
      // Arrange
      const imagePath = '/test/image.jpg';

      // Act
      final result = await thumbnailGenerator.generateThumbnail(imagePath);

      // Assert - verificar que cumple el contrato
      expect(result, isA<File>()); // Retorna File
      expect(result.path, isNotEmpty); // Path no vacío
      expect(result.path.contains('thumb'), isTrue); // Indica que es thumbnail
    });

    test('debe aceptar maxWidth válidos', () async {
      // Arrange
      const imagePath = '/test/image.jpg';
      final validWidths = [100, 200, 400, 600, 800, 1000];

      for (final width in validWidths) {
        // Act
        final result = await thumbnailGenerator.generateThumbnail(
          imagePath,
          maxWidth: width,
        );

        // Assert
        expect(result, isA<File>());
        expect(thumbnailGenerator.lastMaxWidth, width);
      }
    });
  });
}
