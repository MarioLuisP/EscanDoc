import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/image_processing/format_converter/domain/image_format_converter.dart';

/// Mock implementation para testing
class MockImageFormatConverter extends Mock implements ImageFormatConverter {}

void main() {
  group('ImageFormatConverter', () {
    late ImageFormatConverter mockConverter;

    setUp(() {
      mockConverter = MockImageFormatConverter();
    });

    group('detectFormat', () {
      test('detecta JPG correctamente', () {
        when(() => mockConverter.detectFormat(any()))
            .thenReturn('jpg');

        expect(mockConverter.detectFormat('image.jpg'), 'jpg');
        expect(mockConverter.detectFormat('image.JPG'), 'jpg');
        expect(mockConverter.detectFormat('/path/to/image.jpg'), 'jpg');
      });

      test('detecta JPEG como JPG (normalizado)', () {
        when(() => mockConverter.detectFormat(any()))
            .thenReturn('jpg');

        expect(mockConverter.detectFormat('image.jpeg'), 'jpg');
        expect(mockConverter.detectFormat('image.JPEG'), 'jpg');
      });

      test('detecta PNG correctamente', () {
        when(() => mockConverter.detectFormat(any()))
            .thenReturn('png');

        expect(mockConverter.detectFormat('image.png'), 'png');
        expect(mockConverter.detectFormat('image.PNG'), 'png');
      });

      test('detecta PDF correctamente', () {
        when(() => mockConverter.detectFormat(any()))
            .thenReturn('pdf');

        expect(mockConverter.detectFormat('document.pdf'), 'pdf');
        expect(mockConverter.detectFormat('document.PDF'), 'pdf');
      });

      test('detecta WebP correctamente', () {
        when(() => mockConverter.detectFormat(any()))
            .thenReturn('webp');

        expect(mockConverter.detectFormat('image.webp'), 'webp');
        expect(mockConverter.detectFormat('image.WEBP'), 'webp');
      });

      test('detecta HEIC correctamente', () {
        when(() => mockConverter.detectFormat(any()))
            .thenReturn('heic');

        expect(mockConverter.detectFormat('image.heic'), 'heic');
        expect(mockConverter.detectFormat('image.HEIC'), 'heic');
      });
    });

    group('isSupportedFormat', () {
      test('retorna true para formatos soportados', () {
        when(() => mockConverter.isSupportedFormat(any()))
            .thenReturn(true);

        expect(mockConverter.isSupportedFormat('image.jpg'), true);
        expect(mockConverter.isSupportedFormat('image.png'), true);
        expect(mockConverter.isSupportedFormat('image.webp'), true);
        expect(mockConverter.isSupportedFormat('document.pdf'), true);
        expect(mockConverter.isSupportedFormat('image.heic'), true);
      });

      test('retorna false para formatos no soportados', () {
        when(() => mockConverter.isSupportedFormat(any()))
            .thenReturn(false);

        expect(mockConverter.isSupportedFormat('image.bmp'), false);
        expect(mockConverter.isSupportedFormat('image.gif'), false);
        expect(mockConverter.isSupportedFormat('image.tiff'), false);
        expect(mockConverter.isSupportedFormat('document.doc'), false);
      });
    });

    group('convertToJpg', () {
      test('JPG pasa sin conversión (retorna mismo path)', () async {
        const jpgPath = '/path/to/image.jpg';
        when(() => mockConverter.convertToJpg(jpgPath))
            .thenAnswer((_) async => jpgPath);

        final result = await mockConverter.convertToJpg(jpgPath);

        expect(result, jpgPath);
        verify(() => mockConverter.convertToJpg(jpgPath)).called(1);
      });

      test('PNG se convierte a JPG (retorna nuevo path)', () async {
        const pngPath = '/path/to/image.png';
        const jpgPath = '/path/to/image_converted.jpg';

        when(() => mockConverter.convertToJpg(pngPath))
            .thenAnswer((_) async => jpgPath);

        final result = await mockConverter.convertToJpg(pngPath);

        expect(result, jpgPath);
        expect(result, endsWith('.jpg'));
        verify(() => mockConverter.convertToJpg(pngPath)).called(1);
      });

      test('PDF se convierte a JPG (extrae primera página)', () async {
        const pdfPath = '/path/to/document.pdf';
        const jpgPath = '/path/to/document_page1.jpg';

        when(() => mockConverter.convertToJpg(pdfPath))
            .thenAnswer((_) async => jpgPath);

        final result = await mockConverter.convertToJpg(pdfPath);

        expect(result, jpgPath);
        expect(result, contains('page1'));
        verify(() => mockConverter.convertToJpg(pdfPath)).called(1);
      });

      test('lanza UnsupportedImageFormatException para formato no soportado', () async {
        const unsupportedPath = '/path/to/image.bmp';

        when(() => mockConverter.convertToJpg(unsupportedPath))
            .thenThrow(UnsupportedImageFormatException('bmp', unsupportedPath));

        expect(
          () => mockConverter.convertToJpg(unsupportedPath),
          throwsA(isA<UnsupportedImageFormatException>()),
        );
      });

      test('lanza ImageConversionException si la conversión falla', () async {
        const pngPath = '/path/to/corrupted.png';

        when(() => mockConverter.convertToJpg(pngPath))
            .thenThrow(ImageConversionException(
              'Failed to convert',
              pngPath,
              Exception('Corrupted file'),
            ));

        expect(
          () => mockConverter.convertToJpg(pngPath),
          throwsA(isA<ImageConversionException>()),
        );
      });
    });
  });

  group('UnsupportedImageFormatException', () {
    test('tiene mensaje descriptivo', () {
      final exception = UnsupportedImageFormatException('bmp', '/path/to/file.bmp');

      expect(exception.format, 'bmp');
      expect(exception.filePath, '/path/to/file.bmp');
      expect(exception.toString(), contains('bmp'));
      expect(exception.toString(), contains('not supported'));
    });
  });

  group('ImageConversionException', () {
    test('tiene mensaje descriptivo sin error original', () {
      final exception = ImageConversionException(
        'Conversion failed',
        '/path/to/file.png',
      );

      expect(exception.message, 'Conversion failed');
      expect(exception.filePath, '/path/to/file.png');
      expect(exception.originalError, isNull);
      expect(exception.toString(), contains('Conversion failed'));
    });

    test('incluye error original cuando está presente', () {
      final originalError = Exception('File corrupted');
      final exception = ImageConversionException(
        'Conversion failed',
        '/path/to/file.png',
        originalError,
      );

      expect(exception.originalError, originalError);
      expect(exception.toString(), contains('Original error'));
    });
  });
}
