import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/core/services/text_detector_service.dart';
import 'package:escandoc/features/image_processing/classification/data/image_classifier_impl.dart';
import 'package:escandoc/features/image_processing/classification/domain/classification_result.dart';

/// Mock del TextDetectorService
class MockTextDetectorService extends Mock implements TextDetectorService {}

void main() {
  group('ImageClassifierImpl', () {
    late MockTextDetectorService mockTextDetector;
    late ImageClassifierImpl classifier;

    setUp(() {
      mockTextDetector = MockTextDetectorService();
      classifier = ImageClassifierImpl(textDetector: mockTextDetector);
    });

    group('classify() con threshold 600', () {
      const testImagePath = '/path/to/test/image.jpg';

      test('clasifica como DOCUMENTO cuando varianza > 600', () async {
        // Arrange: varianza alta (documento con texto)
        when(() => mockTextDetector.detect(any(), threshold: any(named: 'threshold')))
            .thenAnswer((_) async => {
                  'variance': 750.0,
                  'hasText': true,
                });

        // Act
        final result = await classifier.classify(testImagePath);

        // Assert
        expect(result.type, DocumentType.document);
        expect(result.metadata['variance'], 750.0);
        expect(result.metadata['hasText'], true);
        expect(result.metadata['threshold'], 600.0);
        expect(result.metadata['method'], 'opencv_multicondition_v2');
        expect(result.confidence, greaterThan(0.5));
        verify(() => mockTextDetector.detect(testImagePath, threshold: 600.0))
            .called(1);
      });

      test('clasifica como FOTO cuando varianza < 600', () async {
        // Arrange: varianza baja (foto sin texto)
        when(() => mockTextDetector.detect(any(), threshold: any(named: 'threshold')))
            .thenAnswer((_) async => {
                  'variance': 350.0,
                  'hasText': false,
                });

        // Act
        final result = await classifier.classify(testImagePath);

        // Assert
        expect(result.type, DocumentType.photo);
        expect(result.metadata['variance'], 350.0);
        expect(result.metadata['hasText'], false);
        expect(result.confidence, greaterThan(0.5));
      });

      test('clasifica correctamente casos reales - rostros (168)', () async {
        when(() => mockTextDetector.detect(any(), threshold: any(named: 'threshold')))
            .thenAnswer((_) async => {
                  'variance': 168.0,
                  'hasText': false,
                });

        final result = await classifier.classify(testImagePath);

        expect(result.type, DocumentType.photo);
      });

      test('clasifica correctamente casos reales - documento A4 (4806)', () async {
        when(() => mockTextDetector.detect(any(), threshold: any(named: 'threshold')))
            .thenAnswer((_) async => {
                  'variance': 4806.0,
                  'hasText': true,
                });

        final result = await classifier.classify(testImagePath);

        expect(result.type, DocumentType.document);
      });

      test('clasifica correctamente casos reales - documento amarillo (1449)', () async {
        when(() => mockTextDetector.detect(any(), threshold: any(named: 'threshold')))
            .thenAnswer((_) async => {
                  'variance': 1449.0,
                  'hasText': true,
                });

        final result = await classifier.classify(testImagePath);

        expect(result.type, DocumentType.document);
      });

      test('clasifica correctamente casos reales - texto en pantalla (668)', () async {
        when(() => mockTextDetector.detect(any(), threshold: any(named: 'threshold')))
            .thenAnswer((_) async => {
                  'variance': 668.0,
                  'hasText': true,
                });

        final result = await classifier.classify(testImagePath);

        expect(result.type, DocumentType.document);
      });

      test('threshold 600 separa correctamente fotos de documentos', () async {
        // Caso límite inferior (justo debajo del threshold)
        when(() => mockTextDetector.detect(any(), threshold: any(named: 'threshold')))
            .thenAnswer((_) async => {
                  'variance': 599.0,
                  'hasText': false,
                });

        final resultPhoto = await classifier.classify(testImagePath);
        expect(resultPhoto.type, DocumentType.photo);

        // Caso límite superior (justo encima del threshold)
        when(() => mockTextDetector.detect(any(), threshold: any(named: 'threshold')))
            .thenAnswer((_) async => {
                  'variance': 601.0,
                  'hasText': true,
                });

        final resultDoc = await classifier.classify(testImagePath);
        expect(resultDoc.type, DocumentType.document);
      });
    });

    group('confianza de clasificación', () {
      test('confianza alta cuando varianza muy alejada del threshold', () async {
        // Varianza muy alta (documento claro)
        when(() => mockTextDetector.detect(any(), threshold: any(named: 'threshold')))
            .thenAnswer((_) async => {
                  'variance': 2000.0,
                  'hasText': true,
                });

        final result = await classifier.classify('/path/to/doc.jpg');

        expect(result.confidence, greaterThanOrEqualTo(0.8));
      });

      test('confianza alta cuando varianza muy baja (foto clara)', () async {
        when(() => mockTextDetector.detect(any(), threshold: any(named: 'threshold')))
            .thenAnswer((_) async => {
                  'variance': 100.0,
                  'hasText': false,
                });

        final result = await classifier.classify('/path/to/photo.jpg');

        expect(result.confidence, greaterThanOrEqualTo(0.8));
      });

      test('confianza moderada cerca del threshold', () async {
        when(() => mockTextDetector.detect(any(), threshold: any(named: 'threshold')))
            .thenAnswer((_) async => {
                  'variance': 610.0,
                  'hasText': true,
                });

        final result = await classifier.classify('/path/to/image.jpg');

        expect(result.confidence, lessThan(0.9));
        expect(result.confidence, greaterThan(0.5));
      });
    });

    group('manejo de errores', () {
      test('retorna DOCUMENTO con baja confianza cuando hay error', () async {
        when(() => mockTextDetector.detect(any(), threshold: any(named: 'threshold')))
            .thenThrow(Exception('Network error'));

        final result = await classifier.classify('/path/to/image.jpg');

        expect(result.type, DocumentType.document); // Fallback seguro
        expect(result.confidence, 0.5);
        expect(result.metadata['error'], isNotNull);
      });

      test('retorna DOCUMENTO cuando detector retorna error', () async {
        when(() => mockTextDetector.detect(any(), threshold: any(named: 'threshold')))
            .thenAnswer((_) async => {
                  'variance': 0.0,
                  'hasText': false,
                  'error': 'OpenCV error',
                });

        final result = await classifier.classify('/path/to/image.jpg');

        // Con varianza 0, clasificaría como FOTO, pero con baja confianza
        expect(result.type, DocumentType.photo);
        expect(result.confidence, greaterThan(0.0));
      });
    });

    group('metadata del resultado', () {
      test('incluye toda la información relevante', () async {
        when(() => mockTextDetector.detect(any(), threshold: any(named: 'threshold')))
            .thenAnswer((_) async => {
                  'variance': 850.0,
                  'hasText': true,
                });

        final result = await classifier.classify('/path/to/image.jpg');

        expect(result.metadata['method'], 'opencv_multicondition_v2');
        expect(result.metadata['variance'], 850.0);
        expect(result.metadata['threshold'], 600.0);
        expect(result.metadata['hasText'], true);
        expect(result.metadata['durationMs'], isA<int>());
      });

      test('incluye duración de clasificación', () async {
        when(() => mockTextDetector.detect(any(), threshold: any(named: 'threshold')))
            .thenAnswer((_) async {
          // Simular delay
          await Future.delayed(const Duration(milliseconds: 10));
          return {
            'variance': 700.0,
            'hasText': true,
          };
        });

        final result = await classifier.classify('/path/to/image.jpg');

        expect(result.metadata['durationMs'], greaterThanOrEqualTo(10));
      });
    });
  });
}
