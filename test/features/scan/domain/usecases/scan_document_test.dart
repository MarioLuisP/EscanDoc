import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/scan/domain/usecases/scan_document.dart';
import 'package:escandoc/core/services/document_scanner_service.dart';

// Mock del scanner service
class MockDocumentScannerService extends Mock implements DocumentScannerService {}

void main() {
  late ScanDocument useCase;
  late MockDocumentScannerService mockScanner;

  setUp(() {
    mockScanner = MockDocumentScannerService();
    useCase = ScanDocument(mockScanner);
  });

  group('ScanDocument', () {
    test('debe llamar scanner nativo correctamente', () async {
      // Arrange
      final expectedFile = File('scanned_image.jpg');
      when(() => mockScanner.scanDocument()).thenAnswer((_) async => expectedFile);

      // Act
      await useCase.call();

      // Assert
      verify(() => mockScanner.scanDocument()).called(1);
    });

    test('debe retornar imagen escaneada', () async {
      // Arrange
      final expectedFile = File('scanned_image.jpg');
      when(() => mockScanner.scanDocument()).thenAnswer((_) async => expectedFile);

      // Act
      final result = await useCase.call();

      // Assert
      expect(result, expectedFile);
    });

    test('debe retornar null si usuario cancela scan', () async {
      // Arrange - usuario cancela, scanner retorna null
      when(() => mockScanner.scanDocument()).thenAnswer((_) async => null);

      // Act
      final result = await useCase.call();

      // Assert
      expect(result, isNull);
    });

    test('debe retornar null si hay error de permisos', () async {
      // Arrange
      when(() => mockScanner.scanDocument()).thenThrow(Exception('Camera permission denied'));

      // Act
      final result = await useCase.call();

      // Assert
      expect(result, isNull);
    });

    test('debe manejar cualquier error sin crash', () async {
      // Arrange
      when(() => mockScanner.scanDocument()).thenThrow(Exception('Unknown error'));

      // Act
      final result = await useCase.call();

      // Assert
      expect(result, isNull);
    });
  });
}
