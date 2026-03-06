import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:escandoc/features/image_processing/classification/data/tflite_image_classifier.dart';
import 'package:escandoc/features/image_processing/classification/domain/classification_result.dart';

void main() {
  // IMPORTANTE: Inicializar Flutter binding ANTES de todo
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TFLiteImageClassifier', () {
    // Skip todos los tests en desktop (Windows/macOS/Linux)
    // TFLite requiere bibliotecas nativas que solo funcionan en Android/iOS
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    if (isDesktop) {
      test('SKIP: TFLite tests solo funcionan en Android/iOS', () {
        print('⚠️ Los tests de TFLiteImageClassifier solo funcionan en dispositivos Android/iOS');
        print('⚠️ Esto es normal - TFLite requiere bibliotecas nativas del engine móvil');
      });
      return;
    }
    late TFLiteImageClassifier classifier;

    setUp(() {
      classifier = TFLiteImageClassifier();
    });

    tearDown(() {
      classifier.dispose();
    });

    test('debe inicializar el modelo correctamente', () async {
      // Act
      await classifier.initialize();

      // Assert
      // Si no lanza excepción, el modelo se cargó correctamente
      expect(classifier, isNotNull);
    });

    test('debe clasificar una imagen y retornar ClassificationResult', () async {
      // Arrange
      await classifier.initialize();

      // Crear una imagen de prueba (puede ser cualquier imagen JPG)
      // NOTA: Este test requiere que exista una imagen de prueba en assets
      final testImagePath = 'test/fixtures/test_document.jpg';

      // Skip si no existe la imagen de prueba
      if (!File(testImagePath).existsSync()) {
        print('⚠️ Skipping test: imagen de prueba no encontrada en $testImagePath');
        return;
      }

      // Act
      final result = await classifier.classify(testImagePath);

      // Assert
      expect(result, isA<ClassificationResult>());
      expect(result.type, isA<DocumentType>());
      expect(result.confidence, greaterThanOrEqualTo(0.0));
      expect(result.confidence, lessThanOrEqualTo(1.0));
      expect(result.metadata['method'], 'tflite_keras');
      expect(result.metadata['probabilities'], isNotNull);
    });

    test('debe retornar metadata con probabilidades correctas', () async {
      // Arrange
      await classifier.initialize();
      final testImagePath = 'test/fixtures/test_document.jpg';

      if (!File(testImagePath).existsSync()) {
        print('⚠️ Skipping test: imagen de prueba no encontrada');
        return;
      }

      // Act
      final result = await classifier.classify(testImagePath);
      final probabilities = result.metadata['probabilities'] as Map<String, dynamic>;

      // Assert - verificar que hay 5 probabilidades
      expect(probabilities.length, 5);
      expect(probabilities.containsKey('documento'), true);
      expect(probabilities.containsKey('folleto'), true);
      expect(probabilities.containsKey('foto'), true);
      expect(probabilities.containsKey('manuscrito'), true);
      expect(probabilities.containsKey('recibo'), true);

      // Todas las probabilidades deben sumar ~1.0 (con margen de error)
      final sum = probabilities.values.fold<double>(
        0.0,
        (sum, prob) => sum + (prob as double),
      );
      expect(sum, closeTo(1.0, 0.01));
    });

    test('debe manejar error si la imagen no existe', () async {
      // Arrange
      await classifier.initialize();
      final invalidPath = 'path/to/nonexistent/image.jpg';

      // Act
      final result = await classifier.classify(invalidPath);

      // Assert - debe retornar fallback con error
      expect(result.type, DocumentType.documento); // Fallback
      expect(result.confidence, 0.5); // Confianza baja
      expect(result.metadata.containsKey('error'), true);
    });

    test('debe retornar tipo con mayor probabilidad', () async {
      // Arrange
      await classifier.initialize();
      final testImagePath = 'test/fixtures/test_document.jpg';

      if (!File(testImagePath).existsSync()) {
        print('⚠️ Skipping test: imagen de prueba no encontrada');
        return;
      }

      // Act
      final result = await classifier.classify(testImagePath);
      final probabilities = result.metadata['probabilities'] as Map<String, dynamic>;

      // Assert - el tipo retornado debe tener la mayor probabilidad
      final maxProb = probabilities.values
          .map((p) => p as double)
          .reduce((a, b) => a > b ? a : b);

      final typeLabel = result.metadata['label'] as String;
      expect(probabilities[typeLabel], maxProb);
      expect(result.confidence, maxProb);
    });

    test('debe incluir tiempos de ejecución en metadata', () async {
      // Arrange
      await classifier.initialize();
      final testImagePath = 'test/fixtures/test_document.jpg';

      if (!File(testImagePath).existsSync()) {
        print('⚠️ Skipping test: imagen de prueba no encontrada');
        return;
      }

      // Act
      final result = await classifier.classify(testImagePath);

      // Assert
      expect(result.metadata['preprocessDurationMs'], isA<int>());
      expect(result.metadata['inferenceDurationMs'], isA<int>());
      expect(result.metadata['totalDurationMs'], isA<int>());
      expect(result.metadata['totalDurationMs'], greaterThan(0));
    });

    test('debe poder clasificar múltiples imágenes sin reinicializar', () async {
      // Arrange
      await classifier.initialize();
      final testImagePath = 'test/fixtures/test_document.jpg';

      if (!File(testImagePath).existsSync()) {
        print('⚠️ Skipping test: imagen de prueba no encontrada');
        return;
      }

      // Act - clasificar la misma imagen 3 veces
      final result1 = await classifier.classify(testImagePath);
      final result2 = await classifier.classify(testImagePath);
      final result3 = await classifier.classify(testImagePath);

      // Assert - los resultados deben ser consistentes
      expect(result1.type, result2.type);
      expect(result2.type, result3.type);
      expect(result1.confidence, closeTo(result2.confidence, 0.01));
      expect(result2.confidence, closeTo(result3.confidence, 0.01));
    });
  });
}
