





Cascada óptima: de lo más barato y distintivo a lo más caro
Después del Laplacian (ya resuelto, ~1s):
Paso 2: RECIBO — Aspect Ratio (~50ms)
La señal más barata y más inequívoca. Un ticket de supermercado tiene una forma 
que ningún otro documento tiene. Altura/ancho > 2.0 (un A4 normal es ~1.4). 
Podés ser más estricto con 2.5 si querés menos falsos positivos.
Es prácticamente gratis en tiempo.
Paso 3: FOLLETO — Saturación de color (~100-200ms)
Más inteligente que contar regiones de color (que es caro): analizar el porcentaje de píxeles 
con saturación alta en HSV. Un documento normal es mayormente blanco/negro/gris (saturación baja).
Un folleto tiene colores vivos (logos, fotos, fondos). Si más del 15-20% de los píxeles tienen 
saturación > 80 (de 255), es folleto. Es más rápido que segmentar regiones porque es un solo recorrido 
de la imagen ya redimensionada.
Paso 4: MANUSCRITO — Uniformidad de componentes (~200-300ms)
En vez de HoughLines (caro, ~400-600ms), analizá los componentes conectados después de binarización. 
Texto impreso produce componentes de tamaño muy uniforme (todas las letras son parejas).
Texto manuscrito produce componentes con alta varianza de tamaño (letras grandes, chicas, conectadas, separadas).
Coeficiente de variación > 0.35-0.40 sugiere manuscrito. La binarización adaptativa ya la necesitás para el análisis, 
así que el costo extra es solo contar y medir componentes.
Default: DOCUMENTO
Tiempos estimados acumulados (post-Laplacian):

FOTO: 0ms extra (sale en Laplacian)
RECIBO: +50ms (~1.05s total)
FOLLETO: +150ms (~1.2s total)
MANUSCRITO: +400ms (~1.4s total)
DOCUMENTO: +400ms (~1.4s total, peor caso)

Lo clave del orden: cada paso es más caro que el anterior, pero también cada paso tiene menos candidatos 
que evaluar porque los anteriores ya filtraron. 
Y ningún paso supera los 2s totales ni siquiera en el Moto G52.
Un detalle importante: la saturación de color antes que manuscrito tiene una razón extra. 
Si un folleto tiene texto manuscrito encima (como una nota escrita sobre una propaganda), 
querés que gane FOLLETO, no MANUSCRITO, porque el nombre "folleto" es más descriptivo del objeto real.

El flujo queda limpio y lógico:
Gate 1 (inmediato): Laplacian → FOTO vs DOCUMENTO
Si FOTO → diálogo galería. Si el usuario dice "no, es documento" → pasa al pipeline.
Gate 2 (visual, ~400ms máx): OpenCV cascade
RECIBO → aspect ratio
FOLLETO → saturación
MANUSCRITO → uniformidad componentes
Default → DOCUMENTO genérico
Gate 3 (semántico, ya existe): OCR + DocumentClassifier
Acá es donde está la clave de tu razonamiento. El OCR ya corre en background, ya tarda su tiempo, 
y el DocumentClassifier con keywords ya detecta factura/recibo/contrato/médico. 
Eso es gratis porque ya lo tenés implementado y el usuario ya está viendo "Procesando documento...".
Barcode con ML Kit es innecesario. Sumar 2s para detectar que algo es factura cuando el OCR ya te dice 
"FACTURA" en el texto es redundante. El texto es más confiable que el barcode para tu caso de uso, 
porque no todas las facturas argentinas tienen barcode estándar, pero todas dicen "factura" en algún lado.
Lo elegante: la clasificación visual (OpenCV) y la clasificación semántica (OCR) corren 
en momentos distintos y se complementan. OpenCV te dice la forma del objeto, OCR te dice el contenido. 
Juntas dan el nombre final más preciso: si OpenCV dice RECIBO y OCR dice "Edesur" → "recibo_edesur_06_Feb_2026".
La UX queda natural: foto se descarta rápido, todo lo demás procesa en background con feedback visual, 
y el usuario recibe un documento ya clasificado y nombrado sin haber tocado nada.