package com.example.escandoc

import android.util.Log
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

                    // Calcular varianza Laplaciana
                    val detectionResult = detectTextAdvanced(imagePath, threshold)

                    result.success(detectionResult)
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
     * Detección avanzada de texto combinando Laplacian + Densidad de píxeles.
     *
     * Estrategia de 2 fases:
     * 1. Fast reject: variance < threshold → PHOTO (sin procesamiento extra)
     * 2. Validación con densidad: variance >= threshold → medir píxeles blancos (densidad de tinta/texto)
     *    - Documentos: alta densidad de píxeles blancos (texto concentrado)
     *    - Fotos: baja densidad (píxeles dispersos en texturas)
     *
     * @param imagePath Ruta absoluta de la imagen
     * @param threshold Umbral de varianza Laplaciana
     * @return Mapa con variance, hasText, whiteRatio, contourCount (para debugging)
     */
    private fun detectTextAdvanced(imagePath: String, threshold: Double): Map<String, Any> {
        var image: Mat? = null
        var resized: Mat? = null
        var gray: Mat? = null
        var laplacian: Mat? = null
        var binary: Mat? = null
        var hierarchy: Mat? = null

        try {
            // 1. Cargar y redimensionar imagen
            image = Imgcodecs.imread(imagePath)
            if (image.empty()) {
                throw IllegalArgumentException("Unable to load image: $imagePath")
            }

            resized = Mat()
            val maxDim = 640.0
            val scale = maxDim / maxOf(image.width(), image.height())
            val newSize = Size(image.width() * scale, image.height() * scale)
            Imgproc.resize(image, resized, newSize, 0.0, 0.0, Imgproc.INTER_AREA)

            // 2. Convertir a escala de grises
            gray = Mat()
            Imgproc.cvtColor(resized, gray, Imgproc.COLOR_BGR2GRAY)

            // 3. Calcular varianza Laplaciana
            laplacian = Mat()
            Imgproc.Laplacian(gray, laplacian, CvType.CV_64F)

            val mean = MatOfDouble()
            val stddev = MatOfDouble()
            Core.meanStdDev(laplacian, mean, stddev)

            val stddevValue = stddev.get(0, 0)[0]
            val variance = stddevValue * stddevValue

            // 4. FAST REJECT: Si varianza baja → PHOTO (sin análisis extra)
            if (variance < threshold) {
                return mapOf(
                    "variance" to variance,
                    "hasText" to false,
                    "whiteRatio" to 0.0,
                    "contourCount" to 0
                )
            }

            // 5. VALIDACIÓN CON PÍXELES BLANCOS: variance >= threshold
            // Aplicar adaptive threshold para binarizar
            binary = Mat()
            Imgproc.adaptiveThreshold(
                gray,
                binary,
                255.0,
                Imgproc.ADAPTIVE_THRESH_GAUSSIAN_C,
                Imgproc.THRESH_BINARY,
                11,  // blockSize
                2.0  // C constant
            )

            // 6. Contar densidad de píxeles blancos Y negros
            val whitePixels = Core.countNonZero(binary)
            val totalPixels = binary.width() * binary.height()
            val whiteRatio = whitePixels.toDouble() / totalPixels.toDouble()

            // Contar píxeles muy oscuros (< 25) en escala de grises original
            val darkMask = Mat()
            Core.compare(gray, Scalar(25.0), darkMask, Core.CMP_LT)
            val darkPixels = Core.countNonZero(darkMask)
            val darkRatio = darkPixels.toDouble() / totalPixels.toDouble()
            darkMask.release()

            Log.d("TextDetector", "📊 Píxeles blancos: $whitePixels / $totalPixels (ratio: ${String.format("%.4f", whiteRatio)})")
            Log.d("TextDetector", "📊 Píxeles negros: $darkPixels / $totalPixels (ratio: ${String.format("%.4f", darkRatio)})")

            // 7. Encontrar contornos (SOLO para debugging)
            val contours = ArrayList<MatOfPoint>()
            hierarchy = Mat()
            Imgproc.findContours(
                binary,
                contours,
                hierarchy,
                Imgproc.RETR_EXTERNAL,
                Imgproc.CHAIN_APPROX_SIMPLE
            )

            Log.d("TextDetector", "📊 Total contornos encontrados: ${contours.size}")

            // 7. Filtrar contornos válidos (por área y aspect ratio)
            val minArea = 10.0  // Área mínima de contorno
            val maxArea = (resized.width() * resized.height()) * 0.5  // Máximo 50% de imagen

            var validContours = 0
            var rejectedByArea = 0
            var rejectedByAspectRatio = 0

            for (contour in contours) {
                val area = Imgproc.contourArea(contour)

                // Filtrar por área
                if (area < minArea || area > maxArea) {
                    rejectedByArea++
                    continue
                }

                // Filtrar por aspect ratio (texto tiene cierta proporción)
                val rect = Imgproc.boundingRect(contour)
                val aspectRatio = rect.width.toDouble() / rect.height.toDouble()

                // Rechazar contornos muy anchos o muy altos (probablemente ruido)
                if (aspectRatio > 15.0 || aspectRatio < 0.05) {
                    rejectedByAspectRatio++
                    continue
                }

                validContours++
            }

            Log.d("TextDetector", "✅ Válidos: $validContours | ❌ Por área: $rejectedByArea | ❌ Por aspect ratio: $rejectedByAspectRatio")

            // 8. NUEVA REGLA MULTI-CONDICIÓN (2026-02-10 - 85% accuracy en 20 casos)
            // Recupera documentos en pantallas, facturas, texto negro/blanco
            // Protege fotos reales (90.9% grupo B)
            val hasText = variance > 850.0 ||
                    (whiteRatio > 0.68 && variance > 520.0) ||
                    (darkRatio > 0.45 && variance > 450.0) ||
                    (validContours > 30 && variance > 750.0)

            Log.d("TextDetector", "📦 Retornando Map: variance=$variance, hasText=$hasText, whiteRatio=$whiteRatio, darkRatio=$darkRatio, contourCount=$validContours")

            return mapOf(
                "variance" to variance,
                "hasText" to hasText,
                "whiteRatio" to whiteRatio,
                "darkRatio" to darkRatio,
                "contourCount" to validContours
            )

        } finally {
            // Liberar memoria
            image?.release()
            resized?.release()
            gray?.release()
            laplacian?.release()
            binary?.release()
            hierarchy?.release()
        }
    }

    /**
     * [DEPRECATED] Calcula la varianza del Laplaciano de una imagen.
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
