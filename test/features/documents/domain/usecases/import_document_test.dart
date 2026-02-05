import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/documents/domain/usecases/import_document.dart';
import 'package:escandoc/features/image_processing/format_converter/domain/image_format_converter.dart';
import 'package:escandoc/features/image_processing/normalize_image/domain/normalize_image_use_case.dart';

/// Mocks
class MockImageFormatConverter extends Mock implements ImageFormatConverter {}
class MockNormalizeImageUseCase extends Mock implements NormalizeImageUseCase {}
class MockFile extends Mock implements File {}

void main() {
  group('ImportDocument', () {
    late ImageFormatConverter mockFormatConverter;
    late NormalizeImageUseCase mockNormalizeImage;
    late ImportDocument importDocument;
    late File mockFile;

    setUp(() {
      mockFormatConverter = MockImageFormatConverter();
      mockNormalizeImage = MockNormalizeImageUseCase();
      mockFile = MockFile();

      importDocument = ImportDocument(
        mockFormatConverter,
        mockNormalizeImage,
      );

      // Register fallback values for any()
      registerFallbackValue(File(''));
    });

    group('call - flujo exitoso', () {
      test('importa JPG correctamente (sin conversión, con normalización)', () async {
        const importedPath = '/path/to/imported.jpg';
        const normalizedPath = '/path/to/imported_q85.jpg';

        when(() => mockFile.path).thenReturn(importedPath);
        when(() => mockFile.existsSync()).thenReturn(true);
        when(() => mockFile.lengthSync()).thenReturn(1024 * 1024); // 1 MB

        // JPG pasa sin conversión
        when(() => mockFormatConverter.convertToJpg(importedPath))
            .thenAnswer((_) async => importedPath);

        // Normalización reduce tamaño
        when(() => mockNormalizeImage.execute(importedPath))
            .thenAnswer((_) async => normalizedPath);

        final result = await importDocument.call(mockFile);

        expect(result.path, normalizedPath);
        verify(() => mockFormatConverter.convertToJpg(importedPath)).called(1);
        verify(() => mockNormalizeImage.execute(importedPath)).called(1);
      });

      test('importa PNG correctamente (con conversión y normalización)', () async {
        const importedPath = '/path/to/imported.png';
        const convertedPath = '/path/to/imported_converted.jpg';
        const normalizedPath = '/path/to/imported_converted_q85.jpg';

        when(() => mockFile.path).thenReturn(importedPath);
        when(() => mockFile.existsSync()).thenReturn(true);
        when(() => mockFile.lengthSync()).thenReturn(2 * 1024 * 1024); // 2 MB

        // PNG se convierte a JPG
        when(() => mockFormatConverter.convertToJpg(importedPath))
            .thenAnswer((_) async => convertedPath);

        // JPG se normaliza
        when(() => mockNormalizeImage.execute(convertedPath))
            .thenAnswer((_) async => normalizedPath);

        final result = await importDocument.call(mockFile);

        expect(result.path, normalizedPath);
        expect(result.path, endsWith('.jpg'));
        verify(() => mockFormatConverter.convertToJpg(importedPath)).called(1);
        verify(() => mockNormalizeImage.execute(convertedPath)).called(1);
      });

      test('importa PDF correctamente (extrae página y normaliza)', () async {
        const importedPath = '/path/to/document.pdf';
        const convertedPath = '/path/to/document_page1.jpg';
        const normalizedPath = '/path/to/document_page1_q85.jpg';

        when(() => mockFile.path).thenReturn(importedPath);
        when(() => mockFile.existsSync()).thenReturn(true);
        when(() => mockFile.lengthSync()).thenReturn(500 * 1024); // 500 KB

        // PDF se convierte a JPG (primera página)
        when(() => mockFormatConverter.convertToJpg(importedPath))
            .thenAnswer((_) async => convertedPath);

        // JPG se normaliza
        when(() => mockNormalizeImage.execute(convertedPath))
            .thenAnswer((_) async => normalizedPath);

        final result = await importDocument.call(mockFile);

        expect(result.path, normalizedPath);
        verify(() => mockFormatConverter.convertToJpg(importedPath)).called(1);
        verify(() => mockNormalizeImage.execute(convertedPath)).called(1);
      });

      test('usa normalización automática con target 850 KB', () async {
        const importedPath = '/path/to/imported.jpg';
        const normalizedPath = '/path/to/imported_q85.jpg';

        when(() => mockFile.path).thenReturn(importedPath);
        when(() => mockFile.existsSync()).thenReturn(true);
        when(() => mockFile.lengthSync()).thenReturn(1 * 1024 * 1024);

        when(() => mockFormatConverter.convertToJpg(any()))
            .thenAnswer((_) async => importedPath);

        when(() => mockNormalizeImage.execute(any()))
            .thenAnswer((_) async => normalizedPath);

        await importDocument.call(mockFile);

        verify(() => mockNormalizeImage.execute(importedPath)).called(1);
      });
    });

    group('call - validaciones', () {
      test('lanza Exception cuando archivo no existe', () async {
        const importedPath = '/path/to/nonexistent.jpg';

        when(() => mockFile.path).thenReturn(importedPath);
        when(() => mockFile.existsSync()).thenReturn(false);

        expect(
          () => importDocument.call(mockFile),
          throwsA(isA<Exception>()),
        );

        verifyNever(() => mockFormatConverter.convertToJpg(any()));
        verifyNever(() => mockNormalizeImage.execute(any()));
      });
    });

    group('call - manejo de errores', () {
      test('propaga error de conversión de formato', () async {
        const importedPath = '/path/to/unsupported.bmp';

        when(() => mockFile.path).thenReturn(importedPath);
        when(() => mockFile.existsSync()).thenReturn(true);
        when(() => mockFile.lengthSync()).thenReturn(1024 * 1024);

        when(() => mockFormatConverter.convertToJpg(importedPath))
            .thenThrow(UnsupportedImageFormatException('bmp', importedPath));

        expect(
          () => importDocument.call(mockFile),
          throwsA(isA<UnsupportedImageFormatException>()),
        );

        verify(() => mockFormatConverter.convertToJpg(importedPath)).called(1);
        verifyNever(() => mockNormalizeImage.execute(any()));
      });

      test('propaga error de normalización', () async {
        const importedPath = '/path/to/imported.jpg';

        when(() => mockFile.path).thenReturn(importedPath);
        when(() => mockFile.existsSync()).thenReturn(true);
        when(() => mockFile.lengthSync()).thenReturn(1024 * 1024);

        when(() => mockFormatConverter.convertToJpg(importedPath))
            .thenAnswer((_) async => importedPath);

        when(() => mockNormalizeImage.execute(importedPath))
            .thenThrow(Exception('Normalization failed'));

        await expectLater(
          importDocument.call(mockFile),
          throwsA(isA<Exception>()),
        );

        verify(() => mockFormatConverter.convertToJpg(importedPath)).called(1);
        verify(() => mockNormalizeImage.execute(importedPath)).called(1);
      });
    });

    group('call - flujo completo', () {
      test('ejecuta pasos en orden correcto: verificar → convertir → normalizar', () async {
        const importedPath = '/path/to/imported.png';
        const convertedPath = '/path/to/imported.jpg';
        const normalizedPath = '/path/to/imported_q85.jpg';

        final callOrder = <String>[];

        when(() => mockFile.path).thenReturn(importedPath);
        when(() => mockFile.existsSync()).thenAnswer((_) {
          callOrder.add('existsSync');
          return true;
        });
        when(() => mockFile.lengthSync()).thenAnswer((_) {
          callOrder.add('lengthSync');
          return 2 * 1024 * 1024;
        });

        when(() => mockFormatConverter.convertToJpg(importedPath))
            .thenAnswer((_) async {
          callOrder.add('convertToJpg');
          return convertedPath;
        });

        when(() => mockNormalizeImage.execute(convertedPath))
            .thenAnswer((_) async {
          callOrder.add('normalizeImage');
          return normalizedPath;
        });

        await importDocument.call(mockFile);

        expect(callOrder, [
          'existsSync',
          'lengthSync',
          'convertToJpg',
          'normalizeImage',
        ]);
      });
    });
  });
}
