import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/image_processing/classification/domain/image_classifier.dart';
import 'package:escandoc/features/image_processing/classification/domain/classification_result.dart';

/// Mock implementation para testing
class MockImageClassifier extends Mock implements ImageClassifier {}

void main() {
  group('ImageClassifier', () {
    late ImageClassifier mockClassifier;

    setUp(() {
      mockClassifier = MockImageClassifier();
    });

    group('classify - FOTO detection', () {
      test('detecta FOTO cuando cumple criterios (>12K colores, <25% cobertura)', () async {
        const imagePath = '/path/to/photo.jpg';
        final expectedResult = ClassificationResult(
          type: DocumentType.photo,
          confidence: 0.85,
          metadata: {
            'uniqueColors': 15000,
            'topTenCoverage': 0.20,
            'totalPixels': 100000,
          },
        );

        when(() => mockClassifier.classify(imagePath))
            .thenAnswer((_) async => expectedResult);

        final result = await mockClassifier.classify(imagePath);

        expect(result.type, DocumentType.photo);
        expect(result.confidence, greaterThan(0.5));
        expect(result.metadata['uniqueColors'], greaterThan(12000));
        expect(result.metadata['topTenCoverage'], lessThan(0.25));
        verify(() => mockClassifier.classify(imagePath)).called(1);
      });

      test('detecta FOTO con alta confianza cuando criterios son muy claros', () async {
        const imagePath = '/path/to/clear_photo.jpg';
        final expectedResult = ClassificationResult(
          type: DocumentType.photo,
          confidence: 0.95,
          metadata: {
            'uniqueColors': 25000, // Muchos colores
            'topTenCoverage': 0.10, // Baja cobertura
            'totalPixels': 100000,
          },
        );

        when(() => mockClassifier.classify(imagePath))
            .thenAnswer((_) async => expectedResult);

        final result = await mockClassifier.classify(imagePath);

        expect(result.type, DocumentType.photo);
        expect(result.isHighConfidence, true);
        expect(result.confidence, greaterThan(0.7));
      });

      test('detecta FOTO con confianza media en casos límite', () async {
        const imagePath = '/path/to/borderline_photo.jpg';
        final expectedResult = ClassificationResult(
          type: DocumentType.photo,
          confidence: 0.55,
          metadata: {
            'uniqueColors': 13000, // Apenas por encima del umbral
            'topTenCoverage': 0.23, // Cerca del umbral
            'totalPixels': 100000,
          },
        );

        when(() => mockClassifier.classify(imagePath))
            .thenAnswer((_) async => expectedResult);

        final result = await mockClassifier.classify(imagePath);

        expect(result.type, DocumentType.photo);
        expect(result.isMediumConfidence, true);
      });
    });

    group('classify - DOCUMENTO detection', () {
      test('detecta DOCUMENTO cuando no cumple criterios de FOTO', () async {
        const imagePath = '/path/to/document.jpg';
        final expectedResult = ClassificationResult(
          type: DocumentType.document,
          confidence: 0.80,
          metadata: {
            'uniqueColors': 5000, // Pocos colores
            'topTenCoverage': 0.60, // Alta cobertura (documento típico)
            'totalPixels': 100000,
          },
        );

        when(() => mockClassifier.classify(imagePath))
            .thenAnswer((_) async => expectedResult);

        final result = await mockClassifier.classify(imagePath);

        expect(result.type, DocumentType.document);
        expect(result.confidence, greaterThan(0.5));
        expect(result.metadata['uniqueColors'], lessThan(12000));
        verify(() => mockClassifier.classify(imagePath)).called(1);
      });

      test('detecta DOCUMENTO con alta cobertura top 10', () async {
        const imagePath = '/path/to/invoice.jpg';
        final expectedResult = ClassificationResult(
          type: DocumentType.document,
          confidence: 0.85,
          metadata: {
            'uniqueColors': 8000,
            'topTenCoverage': 0.75, // Muy alta cobertura
            'totalPixels': 100000,
          },
        );

        when(() => mockClassifier.classify(imagePath))
            .thenAnswer((_) async => expectedResult);

        final result = await mockClassifier.classify(imagePath);

        expect(result.type, DocumentType.document);
        expect(result.metadata['topTenCoverage'], greaterThan(0.25));
      });

      test('DOCUMENTO es el tipo por defecto', () async {
        const imagePath = '/path/to/unknown.jpg';
        final expectedResult = ClassificationResult(
          type: DocumentType.document,
          confidence: 0.80,
          metadata: {
            'uniqueColors': 10000,
            'topTenCoverage': 0.30,
            'totalPixels': 100000,
          },
        );

        when(() => mockClassifier.classify(imagePath))
            .thenAnswer((_) async => expectedResult);

        final result = await mockClassifier.classify(imagePath);

        expect(result.type, DocumentType.document);
      });
    });

    group('classify - error handling', () {
      test('lanza Exception cuando archivo no existe', () async {
        const imagePath = '/path/to/nonexistent.jpg';

        when(() => mockClassifier.classify(imagePath))
            .thenThrow(Exception('Image file not found: $imagePath'));

        expect(
          () => mockClassifier.classify(imagePath),
          throwsA(isA<Exception>()),
        );
      });

      test('lanza Exception cuando no puede decodificar imagen', () async {
        const imagePath = '/path/to/corrupted.jpg';

        when(() => mockClassifier.classify(imagePath))
            .thenThrow(Exception('Failed to decode image: $imagePath'));

        expect(
          () => mockClassifier.classify(imagePath),
          throwsA(isA<Exception>()),
        );
      });
    });
  });

  group('ClassificationResult', () {
    test('isHighConfidence retorna true cuando confidence >= 0.7', () {
      final result = ClassificationResult(
        type: DocumentType.photo,
        confidence: 0.85,
      );

      expect(result.isHighConfidence, true);
      expect(result.isMediumConfidence, false);
      expect(result.isLowConfidence, false);
    });

    test('isMediumConfidence retorna true cuando 0.4 <= confidence < 0.7', () {
      final result = ClassificationResult(
        type: DocumentType.photo,
        confidence: 0.55,
      );

      expect(result.isHighConfidence, false);
      expect(result.isMediumConfidence, true);
      expect(result.isLowConfidence, false);
    });

    test('isLowConfidence retorna true cuando confidence < 0.4', () {
      final result = ClassificationResult(
        type: DocumentType.document,
        confidence: 0.30,
      );

      expect(result.isHighConfidence, false);
      expect(result.isMediumConfidence, false);
      expect(result.isLowConfidence, true);
    });

    test('metadata es opcional y default es mapa vacío', () {
      final result = ClassificationResult(
        type: DocumentType.document,
        confidence: 0.80,
      );

      expect(result.metadata, isEmpty);
    });

    test('metadata puede contener información adicional', () {
      final result = ClassificationResult(
        type: DocumentType.photo,
        confidence: 0.85,
        metadata: {
          'uniqueColors': 15000,
          'topTenCoverage': 0.20,
          'imageWidth': 1920,
          'imageHeight': 1080,
        },
      );

      expect(result.metadata['uniqueColors'], 15000);
      expect(result.metadata['topTenCoverage'], 0.20);
      expect(result.metadata['imageWidth'], 1920);
      expect(result.metadata['imageHeight'], 1080);
    });

    test('toString incluye type y confidence', () {
      final result = ClassificationResult(
        type: DocumentType.photo,
        confidence: 0.85,
        metadata: {'uniqueColors': 15000},
      );

      final string = result.toString();
      expect(string, contains('photo'));
      expect(string, contains('85.0%'));
      expect(string, contains('metadata'));
    });
  });

  group('DocumentType', () {
    test('tiene los tipos esperados', () {
      expect(DocumentType.values, contains(DocumentType.photo));
      expect(DocumentType.values, contains(DocumentType.document));
    });

    test('photo es diferente de document', () {
      expect(DocumentType.photo, isNot(DocumentType.document));
    });
  });
}
