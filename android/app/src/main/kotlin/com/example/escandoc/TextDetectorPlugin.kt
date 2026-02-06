package com.example.escandoc

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.opencv.android.OpenCVLoader
import org.opencv.core.*
import org.opencv.imgcodecs.Imgcodecs
import org.opencv.imgproc.Imgproc

/**
 * Plugin nativo para detección de texto usando OpenCV Laplacian variance.
 *
 * Estrategia ultra-rápida (10-50ms):
 * 1. Redimensionar imagen a 640px (performance)
 * 2. Convertir a escala de grises
 * 3. Aplicar operador Laplaciano (detecta bordes de segundo orden)
 * 4. Calcular varianza de la respuesta
 * 5. Comparar con threshold
 *
 * Varianza alta → texto (bordes finos y estructurados)
 * Varianza baja → sin texto (fondo uniforme)
 */
class TextDetectorPlugin(private val channel: MethodChannel) : MethodChannel.MethodCallHandler {

    init {
        // Inicializar OpenCV (debe ejecutarse antes de usar cv)
        if (!OpenCVLoader.initLocal()) {
            throw RuntimeException("Unable to load OpenCV!")
        }
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "detect" -> {
                try {
                    val imagePath = call.argument<String>("imagePath")
                        ?: throw IllegalArgumentException("imagePath is required")
                    val threshold = call.argument<Double>("threshold") ?: 600.0

                    // Una sola llamada que calcula varianza y determina hasText
                    val variance = calculateLaplacianVariance(imagePath)
                    val hasText = variance > threshold

                    // Retornar mapa con ambos valores
                    val resultMap = mapOf(
                        "variance" to variance,
                        "hasText" to hasText
                    )

                    result.success(resultMap)
                } catch (e: Exception) {
                    result.error("DETECTION_ERROR", e.message, null)
                }
            }
            "hasText" -> {
                // Deprecated: mantener por compatibilidad
                try {
                    val imagePath = call.argument<String>("imagePath")
                        ?: throw IllegalArgumentException("imagePath is required")
                    val threshold = call.argument<Double>("threshold") ?: 120.0

                    val variance = calculateLaplacianVariance(imagePath)
                    val hasText = variance > threshold

                    result.success(hasText)
                } catch (e: Exception) {
                    result.error("DETECTION_ERROR", e.message, null)
                }
            }
            "getVariance" -> {
                // Deprecated: mantener por compatibilidad
                try {
                    val imagePath = call.argument<String>("imagePath")
                        ?: throw IllegalArgumentException("imagePath is required")

                    val variance = calculateLaplacianVariance(imagePath)
                    result.success(variance)
                } catch (e: Exception) {
                    result.error("VARIANCE_ERROR", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Calcula la varianza del Laplaciano de una imagen.
     *
     * @param imagePath Ruta absoluta de la imagen
     * @return Varianza calculada (double)
     */
    private fun calculateLaplacianVariance(imagePath: String): Double {
        var image: Mat? = null
        var resized: Mat? = null
        var gray: Mat? = null
        var laplacian: Mat? = null

        try {
            // 1. Cargar imagen
            image = Imgcodecs.imread(imagePath)
            if (image.empty()) {
                throw IllegalArgumentException("Unable to load image: $imagePath")
            }

            // 2. Redimensionar a 640px (CLAVE para velocidad 10-50ms)
            // Mantiene aspect ratio, reduce tamaño para análisis rápido
            resized = Mat()
            val maxDim = 640.0
            val scale = maxDim / maxOf(image.width(), image.height())
            val newSize = Size(image.width() * scale, image.height() * scale)
            Imgproc.resize(image, resized, newSize, 0.0, 0.0, Imgproc.INTER_AREA)

            // 3. Convertir a escala de grises
            // Texto se detecta bien en gris, más rápido que color
            gray = Mat()
            Imgproc.cvtColor(resized, gray, Imgproc.COLOR_BGR2GRAY)

            // 4. Aplicar operador Laplaciano
            // Detecta bordes de segundo orden (cambios bruscos de intensidad)
            // Texto tiene muchos bordes finos → alta respuesta Laplaciana
            laplacian = Mat()
            Imgproc.Laplacian(gray, laplacian, CvType.CV_64F)

            // 5. Calcular varianza (desviación estándar al cuadrado)
            // Varianza mide "cuánto varían los valores del Laplaciano"
            // Texto: alta varianza (muchos bordes diferentes)
            // Foto lisa: baja varianza (pocos cambios)
            val mean = MatOfDouble()
            val stddev = MatOfDouble()
            Core.meanStdDev(laplacian, mean, stddev)

            // Obtener desviación estándar y calcular varianza (stddev²)
            val stddevValue = stddev.get(0, 0)[0]
            val variance = stddevValue * stddevValue

            return variance

        } finally {
            // Liberar memoria (IMPORTANTE para evitar memory leaks)
            image?.release()
            resized?.release()
            gray?.release()
            laplacian?.release()
        }
    }
}
