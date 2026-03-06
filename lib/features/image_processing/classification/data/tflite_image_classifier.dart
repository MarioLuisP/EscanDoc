import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
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
      return await _classifyInternal(imagePath)
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      debugPrint('[TFLiteClassifier] ⏱️ TIMEOUT al clasificar $imagePath → fallback documento');
      return ClassificationResult(
        type: DocumentType.document,
        confidence: 0.5,
        metadata: {'method': 'tflite_keras', 'error': 'timeout'},
      );
    } catch (e, stackTrace) {
      debugPrint('[TFLiteClassifier] ❌ ERROR: $e');
      debugPrint('[TFLiteClassifier] StackTrace: $stackTrace');
      return ClassificationResult(
        type: DocumentType.document,
        confidence: 0.5,
        metadata: {'method': 'tflite_keras', 'error': e.toString()},
      );
    }
  }

  Future<ClassificationResult> _classifyInternal(String imagePath) async {
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
  /// **Optimización:** Usa Float32List + loop lineal en vez de triple loop anidado.
  /// - Antes: ~2300ms (triple loop anidado con 50,176 llamadas getPixel)
  /// - Después: ~300-500ms (loop lineal con acceso directo a píxeles)
  ///
  /// **CRÍTICO:** El modelo espera píxeles en [0, 255] SIN normalizar.
  /// Fue entrenado con image_dataset_from_directory (NO normaliza).
  ///
  /// 1. Carga imagen desde disco
  /// 2. Redimensiona a 224x224 (operación nativa del package image)
  /// 3. Convierte píxeles a Float32List [0, 255] con loop lineal
  /// 4. Retorna formato [1, 224, 224, 3]
  Future<List<List<List<List<double>>>>> _preprocessImage(String imagePath) async {
    final startTotal = DateTime.now();

    // 1. Cargar y decodificar imagen CON DART:UI (nativo, 10-20x más rápido)
    final startDecode = DateTime.now();
    final bytes = await File(imagePath).readAsBytes();

    // Decodificar con engine nativo de Flutter (Android/iOS codecs)
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: inputSize,   // Resize durante decode (más eficiente)
      targetHeight: inputSize,
    );
    final frame = await codec.getNextFrame();
    final uiImage = frame.image;

    final decodeDuration = DateTime.now().difference(startDecode).inMilliseconds;
    debugPrint('[TFLiteClassifier] ⏱️ 1. Decodificar + Resize (dart:ui nativo): ${decodeDuration}ms');

    // 2. Extraer píxeles como bytes raw (RGBA)
    final startExtract = DateTime.now();
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (byteData == null) {
      throw Exception('No se pudo extraer bytes de la imagen');
    }

    final extractDuration = DateTime.now().difference(startExtract).inMilliseconds;
    debugPrint('[TFLiteClassifier] ⏱️ 2. Extraer bytes RGBA: ${extractDuration}ms');

    // 3. Convertir RGBA a RGB Float32List
    final startFloatConversion = DateTime.now();
    final pixelCount = inputSize * inputSize * 3;
    final input = Float32List(pixelCount);
    final rgbaBytes = byteData.buffer.asUint8List();

    int outputIndex = 0;
    for (int i = 0; i < rgbaBytes.length; i += 4) {
      // Mantener píxeles en [0, 255] (sin normalizar)
      input[outputIndex++] = rgbaBytes[i].toDouble();       // Red
      input[outputIndex++] = rgbaBytes[i + 1].toDouble();   // Green
      input[outputIndex++] = rgbaBytes[i + 2].toDouble();   // Blue
      // Skip Alpha (i + 3)
    }

    final floatDuration = DateTime.now().difference(startFloatConversion).inMilliseconds;
    debugPrint('[TFLiteClassifier] ⏱️ 3. RGBA → RGB Float32List: ${floatDuration}ms');

    // 🔍 DEBUG: Verificar rango de píxeles
    final minVal = input.reduce((a, b) => a < b ? a : b);
    final maxVal = input.reduce((a, b) => a > b ? a : b);
    debugPrint('[TFLiteClassifier] 🔍 Rango píxeles: Min=$minVal, Max=$maxVal (esperado: [0, 255])');

    if (maxVal > 260 || minVal < -5) {
      debugPrint('  ⚠️ WARNING: Píxeles fuera de rango esperado [0, 255]');
    }

    // 4. Convertir Float32List a formato [1, 224, 224, 3]
    final startReshape = DateTime.now();
    final result = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (y) => List.generate(
          inputSize,
          (x) {
            final baseIndex = (y * inputSize + x) * 3;
            return [
              input[baseIndex],     // Red
              input[baseIndex + 1], // Green
              input[baseIndex + 2], // Blue
            ];
          },
        ),
      ),
    );
    final reshapeDuration = DateTime.now().difference(startReshape).inMilliseconds;
    debugPrint('[TFLiteClassifier] ⏱️ 4. Reshape a [1,224,224,3]: ${reshapeDuration}ms');

    final totalDuration = DateTime.now().difference(startTotal).inMilliseconds;
    debugPrint('[TFLiteClassifier] ⏱️ TOTAL preprocesado: ${totalDuration}ms');

    // Liberar recursos
    uiImage.dispose();

    return result;
  }

  /// Libera recursos del intérprete.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    debugPrint('[TFLiteClassifier] 🗑️ Recursos liberados');
  }
}
