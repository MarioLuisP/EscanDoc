# Corrección automática de orientación de documentos

**Fecha:** 4 Marzo 2026

---

## Problema

Las fotos importadas desde galería llegan frecuentemente acostadas (rotadas 90° o 270°). El scanner nativo ya maneja orientación correctamente, pero las imágenes importadas no.

Intentos previos descartados:
- **Pre-pipeline con EXIF + Crop OCR** (`DetectAndFixOrientation`): se ejecutaba antes del TFLite, agregaba ~900ms al flujo visible. Se implementó y testeó completamente pero se descartó por afectar la experiencia del usuario y porque la clasificación inicial sobre una imagen acostada era incorrecta de todos modos.

---

## Solución adoptada: corrección post-OCR en background

La corrección ocurre **dentro del background OCR**, completamente invisible para el usuario.

### ¿Por qué este enfoque?

- El scanner nativo ya orienta correctamente → el 99% de los escaneos no necesitan corrección
- La corrección se hace solo cuando es necesario, con costo cero cuando no lo es
- El OCR de texto completo detecta ángulos con mucha más precisión que un crop de 90px
- Todo ocurre en background: el usuario no espera

---

## Flujo de corrección

```
1er OCR completo
      ↓
detectOrientationDegrees() — mediana de ángulos de todas las líneas
      ↓
¿detectedRotationDegrees != 0?
      ├── NO → continuar normalmente
      └── SÍ →
            rotateImage() (~200ms, JPEG nativo)
                  ↓
            re-clasificar TFLite (~280ms, modelo ya en memoria)
                  ↓
            2do OCR completo
                  ↓
            continuar con resultado del 2do OCR
```

Después del 2do OCR (o del 1er OCR si no hubo rotación), el pipeline continúa igual: refinamiento, actualización de tipo/título/nota, update en BD.

---

## Archivos involucrados

### Detección de ángulo
- `lib/core/services/blocks_to_markdown.dart` — expone `detectOrientationDegrees(List<double>)` → 0/90/180/270. Reutilizado por `OCRServiceImpl`.

### Resultado OCR con campo de rotación
- `lib/core/services/ocr_analysis.dart` — campo `detectedRotationDegrees` (default 0)
- `lib/core/services/ocr_service.dart` — calcula `detectedRotationDegrees` al final de `extractAnalysis()`

### Orquestación del pipeline
- `lib/features/scan/domain/usecases/process_ocr.dart` — bloque de corrección entre 1er y 2do OCR. Recibe `DocumentOrientationService?` e `ImageClassifier?` opcionales (nullable → backward compat). Callback `onStatus` para reportar estado al provider.

### Rotación física del archivo
- `lib/core/services/document_orientation_service.dart` — interface, método `rotateImage()`
- `lib/core/services/document_orientation_service_impl.dart` — implementación con `FlutterImageCompress` nativo (~200ms, sin pérdida de calidad perceptible)

### Inyección de dependencias
- `lib/main.dart` — ambos `ProcessOCR` (ScanProvider e ImportProvider) reciben `orientationService` e `imageClassifier`

### Código anterior conservado (no activo)
- `lib/features/scan/domain/usecases/detect_and_fix_orientation.dart` — UseCase EXIF + Crop OCR, testeado y funcional, conservado pero fuera del pipeline activo
- `test/features/scan/domain/usecases/detect_and_fix_orientation_test.dart` — 5 tests GREEN ✅

---

## Feedback de estado en el botón verde

El UseCase reporta estado al provider via callback `onStatus`. El provider almacena claves de localización en `statusMessage`. El widget las traduce con `.tr()`.

Secuencia visible durante una corrección:
```
Extrayendo texto...        ← 1er OCR
Corrigiendo orientación... ← rotación detectada
Analizando documento...    ← re-clasificación
Extrayendo texto...        ← 2do OCR
```

Claves relevantes en `es.json` / `en.json`: `status_fixing_orientation`, `status_analyzing`, `status_extracting`.

---

## Actualización de UI post-pipeline

El pipeline completo (OCR → rotación → refinamiento) termina antes de actualizar la BD. Solo después de ese update, la UI se refresca.

### Mecanismo — `home_page.dart`
- `_onImportChanged()`: listener sobre `ImportProvider`, detecta cuando `isProcessingOCR` pasa de `true` a `false`
- Al detectar ese cambio: limpia `imageCache` + llama `loadDocuments()`
- Aplica a home y a la pantalla "mostrar todos" (ambas escuchan `DocumentsProvider`)

### Por qué no alcanza solo con limpiar el cache
- `Image.file()` usa el path como cache key en `_ImageState`
- Si el archivo fue rotado (mismo path, píxeles distintos), Flutter reutiliza el `_ImageState` y no recarga
- Se necesita un `ValueKey` en `Image.file()` que cambie cuando el pipeline actualiza el documento

### ValueKey en miniaturas
- `home_page.dart` → `_RecentDocItem._buildThumbnail()`
- `documents_list_page.dart` → `_buildThumbnail()`
- Key compuesta por `filePath + documentType + ocrText.isNotEmpty`
- Cuando el pipeline cambia tipo o establece ocrText → key cambia → Flutter destruye `_ImageState` → imagen rotada carga desde disco ✓

---

## Tiempos medidos en dispositivo

### Documento orientado correctamente
- OCR único: ~748ms, sin paso extra

### Documento acostado (270°, 19 bloques — comprobante hospitalario)
- 1er OCR: 748ms → detecta 270°
- Rotación: 208ms
- Re-clasificar: 281ms (modelo ya en memoria, mucho más rápido que el 1er clasificado)
- 2do OCR: 639ms
- **Total background: 1908ms**

### Factura acostada (270°, 132 bloques)
- 1er OCR: 2458ms → detecta 270°
- Rotación: 222ms
- Re-clasificar: 322ms → **corrige tipo: documento → recibo** ✅
- 2do OCR: 2187ms
- **Total background: 5273ms**

El tiempo extra por corrección es ~600ms (rotar + re-clasificar). El 2do OCR tarda similar al 1er OCR — inevitable para documentos densos.

---

## Tests — `process_ocr_test.dart`

Grupo `corrección de orientación post-OCR`:

1. **Rotación detectada**: rota archivo, re-clasifica, re-hace OCR, resultado final viene del 2do pass
2. **Rotación detectada sin services**: usa resultado original sin rotar (backward compat — services son opcionales)
3. **Orientación 0°**: una sola pasada OCR, sin rotación

**Lección de mocks**: `File` en Dart no implementa `==` por path — dos instancias con el mismo path no son iguales. Stubs con instancias concretas de `File` nunca hacen match. Usar `any()` para argumentos `File` en mocktail. Para distinguir llamadas múltiples al mismo método, usar un contador en el closure del `thenAnswer`.
