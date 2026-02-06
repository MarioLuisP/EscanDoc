Sí, **en febrero de 2026** hay varias opciones **super brutas y rápidas** para solo detectar si hay texto en una imagen en Android, sin necesidad de reconocer palabras, leer el texto ni preocuparte por idiomas. El ML Kit Text Recognition (incluso la v2) es muy bueno, pero hace más de lo que necesitas (detección + reconocimiento completo), lo que consume tiempo extra innecesario.

Aquí te resumo lo mejor que existe ahora mismo para ser **lo más veloz posible** (priorizando velocidad extrema sobre precisión perfecta):

### 1. Truco más simple y rápido con ML Kit (recomendado para empezar)
Sigue usando ML Kit, pero **detente inmediatamente** cuando detectes el primer bloque de texto. No esperes el OCR completo.

```kotlin
val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

recognizer.process(image)
    .addOnSuccessListener { visionText ->
        if (visionText.textBlocks.isNotEmpty()) {
            // ¡Ya hay texto! Para todo aquí mismo
            // No sigas procesando líneas/palabras
            callback(true)  // o lo que uses
            return@addOnSuccessListener
        } else {
            callback(false)
        }
    }
    .addOnFailureListener { callback(false) }
```

- En imágenes con texto claro, suele responder en **< 80-150 ms** (mucho menos que esperar el texto completo).
- Es lo más fácil: ya lo tienes integrado, sin dependencias nuevas.
- En la práctica, muchos desarrolladores usan esto exactamente para "saber si hay texto" de forma rápida.

### 2. OpenCV puro (el más bruto y veloz posible sin ML pesado)
Si quieres algo **realmente ligero y ultra-rápido** (10-50 ms en la mayoría de celulares), usa OpenCV con heurísticas clásicas de visión por computadora. No necesita modelos de ML grandes.

Ideas rápidas que funcionan muy bien para detectar "presencia de texto":

- **Laplacian variance** (muy rápido): texto genera alta varianza de bordes.
  ```kotlin
  val gray = Imgproc.cvtColor(mat, gray, Imgproc.COLOR_BGR2GRAY)
  val laplacian = Mat()
  Imgproc.Laplacian(gray, laplacian, CvType.CV_64F)
  val mean = Core.meanStdDev(laplacian).second.`val`[0]
  if (mean > umbral) { hay texto }
  ```
- **Contornos + Canny** o **Sobel**: cuenta regiones con muchos bordes horizontales/verticales (texto suele tenerlos).
- **MSER** (Maximally Stable Extremal Regions): detecta regiones candidatas a caracteres muy rápido.
- **Adaptive threshold + conteo de blobs**: binariza y cuenta "islas" pequeñas alineadas.

Esto corre en **milisegundos** incluso en celulares viejos, sin descargar modelos de 10-20 MB. OpenCV en Android es ~10-15 MB extra, pero es puro nativo y brutalmente eficiente. Es ideal para live camera o chequeos constantes.

### 3. PaddleOCR Lite / PP-OCR mobile (muy competitivo en 2026)
- Tiene versiones **ultra-ligeras** (~10-20 MB) optimizadas para móvil.
- La fase de **detección** (DBNet o similares) es extremadamente rápida y puedes usarla sola para preguntar "¿hay regiones de texto?".
- En benchmarks recientes, la detección pura suele ser **más rápida** que ML Kit en dispositivos mid-range cuando solo buscas presencia.
- Integra vía Paddle Lite (JNI) o wrappers Android. Es una gran alternativa si ML Kit no te da la velocidad que buscas.

### 4. Otras opciones ultra-ligeras
- **TensorFlow Lite con modelo mínimo**: un clasificador binario "hay texto / no hay texto" (modelos de 2-5 MB). Inferencia en < 30-80 ms. Requiere más trabajo (entrenar o buscar modelo pre-hecho).
- No hay un "Text Detection only" oficial separado en ML Kit en 2026 (la API antigua de Mobile Vision está deprecated y migrada al Text Recognition v2).

### Recomendación práctica hoy (febrero 2026)
1. **Prueba primero** el truco de ML Kit (detener en `textBlocks.isNotEmpty()`). Es lo más rápido de implementar y en la mayoría de casos ya te da < 150 ms.
2. **Si necesitas aún más velocidad** (live camera, dispositivos low-end, o chequeos masivos): pasa a **OpenCV + Laplacian/MSER**. Es lo más bruto y veloz sin depender de modelos pesados.
3. **Si quieres ML pero más optimizado**: mira PaddleOCR Lite.

Si me dices más detalles (¿es para cámara en vivo? ¿qué % de imágenes tienen texto? ¿dispositivos low-end o medianos? ¿ya usas OpenCV?), te puedo dar código más preciso o la mejor opción exacta. ¡Avísame!
