import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:escandoc/features/image_processing/classification/domain/image_classifier.dart';
import 'package:escandoc/features/image_processing/classification/domain/classification_result.dart';

/// Implementación del clasificador de imágenes usando TensorFlow Lite.
///
/// **Modelo:** clasificador_documento.tflite (Keras)
/// **Clases (orden alfabético español):**
/// - 0: documento → Documentos generales
/// - 1: folleto → Folletos
/// - 2: foto → Fotografías
/// - 3: manuscrito → Manuscritos
/// - 4: recibo → Recibos/tickets
///
/// **Input:** 224x224 RGB (sin normalizar [0, 255], igual que image_dataset_from_directory)
/// **Output:** [1, 5] probabilidades
///
/// **Performance:** ~100-300ms (depende del dispositivo)
class TFLiteImageClassifier implements ImageClassifier {
  Interpreter? _interpreter;
  bool _isInitialized = false;

  /// Tamaño de entrada del modelo (224x224 es estándar para MobileNet)
  static const int inputSize = 224;

  /// Labels en orden alfabético español (índice = clase del modelo)
  static const List<String> labels = [
    'documento',   // 0 (singular para notas)
    'folleto',     // 1
    'foto',        // 2
    'manuscrito',  // 3
    'recibo',      // 4 (ticket → recibo en español)
  ];

  /// Mapeo de índice a DocumentType (orden alfabético español)
  static const Map<int, DocumentType> indexToType = {
    0: DocumentType.document,   // documentos
    1: DocumentType.brochure,   // folletos
    2: DocumentType.photo,      // fotos
    3: DocumentType.handwritten, // manuscrito
    4: DocumentType.ticket,     // tickets
  };

  /// Inicializa el intérprete TFLite cargando el modelo.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('[TFLiteClassifier] 🟢 Inicializando modelo...');

      // Cargar modelo desde assets
      _interpreter = await Interpreter.fromAsset('assets/models/clasificador_documento.tflite');

      _isInitialized = true;
      debugPrint('[TFLiteClassifier] ✅ Modelo cargado correctamente');

      // Log de info del modelo
      debugPrint('[TFLiteClassifier] Input shape: ${_interpreter!.getInputTensors()}');
      debugPrint('[TFLiteClassifier] Output shape: ${_interpreter!.getOutputTensors()}');
    } catch (e, stackTrace) {
      debugPrint('[TFLiteClassifier] ❌ Error cargando modelo: $e');
      debugPrint('[TFLiteClassifier] StackTrace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<ClassificationResult> classify(String imagePath) async {
    try {
      final startTime = DateTime.now();
      debugPrint('[TFLiteClassifier] 🟢 START: Clasificación TFLite - ${startTime.millisecondsSinceEpoch}');
      debugPrint('[TFLiteClassifier] Imagen: $imagePath');

      // Asegurar que el modelo esté inicializado
      if (!_isInitialized) {
        await initialize();
      }

      // 1. Cargar y preprocesar imagen
      final startPreprocess = DateTime.now();
      final input = await _preprocessImage(imagePath);
      final preprocessDuration = DateTime.now().difference(startPreprocess).inMilliseconds;
      debugPrint('[TFLiteClassifier] Preprocesado en ${preprocessDuration}ms');

      // 2. Preparar output (5 clases)
      final output = List.filled(1 * 5, 0.0).reshape([1, 5]);

      // 3. Ejecutar inferencia
      final startInference = DateTime.now();
      _interpreter!.run(input, output);
      final inferenceDuration = DateTime.now().difference(startInference).inMilliseconds;
      debugPrint('[TFLiteClassifier] Inferencia en ${inferenceDuration}ms');

      // 4. Extraer resultados
      final probabilities = output[0] as List<double>;

      // Encontrar clase con mayor probabilidad
      double maxProb = 0.0;
      int maxIndex = 0;
      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          maxIndex = i;
        }
      }

      final type = indexToType[maxIndex]!;
      final label = labels[maxIndex];

      final endTime = DateTime.now();
      final totalDuration = endTime.difference(startTime).inMilliseconds;

      debugPrint('[TFLiteClassifier] 📊 Probabilidades:');
      for (int i = 0; i < probabilities.length; i++) {
        debugPrint('[TFLiteClassifier]   ${labels[i]}: ${(probabilities[i] * 100).toStringAsFixed(2)}%');
      }
      debugPrint('[TFLiteClassifier] ✅ Clasificado como: ${label.toUpperCase()} (confianza: ${(maxProb * 100).toStringAsFixed(1)}%)');
      debugPrint('[TFLiteClassifier] 🔴 END: Clasificación completa - Duración TOTAL: ${totalDuration}ms');

      return ClassificationResult(
        type: type,
        confidence: maxProb,
        metadata: {
          'method': 'tflite_keras',
          'label': label,
          'probabilities': {
            for (int i = 0; i < probabilities.length; i++)
              labels[i]: probabilities[i],
          },
          'preprocessDurationMs': preprocessDuration,
          'inferenceDurationMs': inferenceDuration,
          'totalDurationMs': totalDuration,
        },
      );
    } catch (e, stackTrace) {
      debugPrint('[TFLiteClassifier] ❌ ERROR: $e');
      debugPrint('[TFLiteClassifier] StackTrace: $stackTrace');

      // Fallback: clasificar como documento
      return ClassificationResult(
        type: DocumentType.document,
        confidence: 0.5,
        metadata: {
          'method': 'tflite_keras',
          'error': e.toString(),
        },
      );
    }
  }

  /// Preprocesa la imagen para el modelo.
  ///
  /// 1. Carga imagen desde disco
  /// 2. Redimensiona a 224x224
  /// 3. Convierte píxeles a Float [0, 255] (sin normalizar, igual que entrenamiento)
  /// 4. Convierte a formato Float32 [1, 224, 224, 3]
  Future<List<List<List<List<double>>>>> _preprocessImage(String imagePath) async {
    // Cargar imagen
    final bytes = await File(imagePath).readAsBytes();
    img.Image? image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('No se pudo decodificar la imagen');
    }

    // Redimensionar a 224x224
    final resized = img.copyResize(image, width: inputSize, height: inputSize);

    // 🔍 DEBUG: Verificar píxeles originales
    debugPrint('[TFLiteClassifier] 🔍 Verificando píxeles originales:');
    final testPixel = resized.getPixel(0, 0);
    debugPrint('  Pixel (0,0) raw: r=${testPixel.r}, g=${testPixel.g}, b=${testPixel.b}');
    debugPrint('  Tipo de dato: ${testPixel.r.runtimeType}');

    // Convertir a formato [1, 224, 224, 3] SIN normalizar
    // El modelo espera píxeles en [0, 255] (igual que image_dataset_from_directory)
    final input = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (y) => List.generate(
          inputSize,
          (x) {
            final pixel = resized.getPixel(x, y);
            return [
              pixel.r.toDouble(), // Red [0, 255]
              pixel.g.toDouble(), // Green [0, 255]
              pixel.b.toDouble(), // Blue [0, 255]
            ];
          },
        ),
      ),
    );

    // 🔍 DEBUG: Verificar píxeles normalizados
    debugPrint('[TFLiteClassifier] 🔍 Verificando píxeles normalizados:');
    debugPrint('  Pixel (0,0) normalizado: ${input[0][0][0]}');
    final allPixels = input[0].expand((row) => row.expand((pixel) => pixel)).toList();
    final minPixel = allPixels.reduce((a, b) => a < b ? a : b);
    final maxPixel = allPixels.reduce((a, b) => a > b ? a : b);
    debugPrint('  Min: $minPixel, Max: $maxPixel (esperado: [0, 255])');

    return input;
  }

  /// Libera recursos del intérprete.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    debugPrint('[TFLiteClassifier] 🗑️ Recursos liberados');
  }
}
