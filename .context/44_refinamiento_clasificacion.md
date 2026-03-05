# Refinamiento de Clasificación - Implementación

**Fecha:** 17 Febrero 2026
**Versión:** 1.0

---

## Contexto

El clasificador TFLite distingue 5 categorías: documento, folleto, foto, manuscrito, recibo.
En la práctica, comete dos errores frecuentes:
- Documentos manuscritos largos clasificados como `documento`
- Facturas de servicio clasificadas como `documento` (sin llegar a `factura`)

El refinamiento corrige estos casos usando las métricas que ya devuelve el OCR,
sin costo adicional de procesamiento.

---

## Decisión de diseño

- Se ejecuta **en background**, después de que el OCR finaliza
- Solo ajusta `documento` y `manuscrito`
- `foto`, `folleto` y `recibo` quedan intocables
- Si hubo reclasificación, se registra una nota automática en el documento

---

## Umbrales (basados en datos empíricos, Feb 2026)

| Tipo real       | avgConfidence OCR | Bloques |
|-----------------|-------------------|---------|
| Documento impreso | 0.85 – 0.93     | ~32     |
| Factura          | 0.79 – 0.84      | 118-144 |
| Manuscrito       | 0.17 – 0.56 (máx)| 9-15    |
| Recibo (control) | —                | 13-46   |

- **Umbral manuscrito:** `avgConfidence < 0.72`
  - Ajustado de 0.55 → 0.72 por receta médica mixta (membrete impreso + manuscrito = avgConf 0.657)
- **Umbral factura:** `blockCount > 80` + al menos una keyword

---

## Archivos creados

- `lib/core/services/ocr_analysis.dart`
- `lib/features/scan/domain/usecases/refine_classification.dart`
- `test/features/scan/domain/usecases/refine_classification_test.dart`

---

## Archivos modificados

- `lib/core/services/ocr_service.dart`
- `lib/features/scan/domain/usecases/process_ocr.dart`
- `lib/features/scan/presentation/providers/scan_provider.dart`
- `lib/features/documents/presentation/providers/import_provider.dart`
- `lib/main.dart`
- `test/features/scan/domain/usecases/process_ocr_test.dart`

---

## Cambios por archivo

### `ocr_service.dart`
- Reemplazó `extractText()` → `extractAnalysis()`
- Retorna `OcrAnalysis` en vez de `String`
- Calcula `blockCount` y `avgConfidence` internamente

### `process_ocr.dart`
- Agrega `NoteRepository` y `RefineClassification` como dependencias
- Recibe `tfliteClass` como parámetro nombrado
- Llama a `RefineClassification` con el análisis OCR
- Crea nota de corrección en BD si hubo reclasificación

### `scan_provider.dart` / `import_provider.dart`
- `_processOCRInBackground` recibe y pasa `tfliteClass`
- El label del TFLite ya estaba disponible en ambos providers

### `main.dart`
- Inyecta `NoteRepository` y `RefineClassification()` en los dos constructores de `ProcessOCR`
- Agrega import de `refine_classification.dart`

---

## Keywords de detección de facturas

### Español
factura, facturación, vencimiento, total a pagar, importe a pagar,
liquidación, período, cuit, iva, consumo, prestación, abono,
fecha de vencimiento, próximo vencimiento, monto a pagar,
n° de cliente, número de cliente, tarifa, deuda, mora, talón, cupón de pago

### Inglés
invoice, bill, statement, amount due, total due, due date,
billing period, billing cycle, account number, balance due,
past due, payment due, current charges, remittance, kwh,
meter reading, usage, subscription, account summary,
previous balance, minimum payment, payment stub, tear here

---

## Notas generadas

| Corrección            | Texto de nota                                                    |
|-----------------------|------------------------------------------------------------------|
| doc → manuscrito      | `documento → manuscrito (2° paso: confianza promedio baja: X)`  |
| manuscrito → doc      | `manuscrito → documento (2° paso: confianza promedio alta: X)`  |
| doc → factura         | `documento → factura (2° paso: keywords + N bloques)`           |
| manuscrito → factura  | `manuscrito → factura (2° paso: keywords + N bloques)`          |

---

## Tests

- 31 tests en `refine_classification_test.dart`
- 10 tests en `process_ocr_test.dart` (actualizados)
- Todos pasan ✅

---

## Títulos de documentos (18 Febrero 2026)

Cada documento recibe un nombre amigable en el momento de guardado, basado en el tipo TFLite inicial.
Si el refinamiento post-OCR cambia el tipo, el título se regenera con el tipo correcto.

### Formato
`[Tipo] [N] del [D]/[M]` en español, `[Type] [N] of [D]/[M]` en inglés.

Ejemplos: `Factura 1 del 17/2`, `Nota 3 del 18/2`, `Foto 1 del 18/2`

### Nombres por tipo

| Tipo TFLite  | ES       | EN       |
|--------------|----------|----------|
| documento    | Documento| Document |
| factura      | Factura  | Invoice  |
| manuscrito   | Nota     | Note     |
| folleto      | Folleto  | Brochure |
| foto         | Foto     | Photo    |
| recibo       | Recibo   | Receipt  |

### Numeración secuencial
Se cuenta cuántos documentos del mismo tipo ya existen **en el mismo día** usando el prefijo del nombre (`LIKE 'Factura %'`). El nuevo recibe el siguiente número.

### Renombrado manual
El usuario puede cambiar el nombre desde el detalle del documento (ícono de lápiz). El nuevo nombre se valida como no vacío y se guarda en BD.

---

## Notas automáticas (18 Febrero 2026)

Las notas de debug (clasificación TFLite y corrección de tipo) fueron eliminadas.
En su lugar, `ProcessOCR` crea una única nota de extracto útil para el usuario.

### Nota para documentos impresos
Primeros 150 caracteres del texto OCR, con espacios y saltos de línea colapsados.

### Nota para manuscritos
Se toman las top-5 líneas con mayor confianza OCR (sin importar si superan un umbral fijo) y se unen con espacio. Si hay palabras reconocibles: `"Nota manuscrita de [palabras]"`. Si no hay nada reconocible: `"Nota manuscrita"`.

La idea es que si el documento tiene texto impreso (membrete, encabezado), esas líneas naturalmente tendrán confianza alta y aparecerán en la nota. Si es puro manuscrito, al menos aparecen las palabras más legibles.

### Cuándo no se crea nota
Si el OCR no extrae ningún texto (imagen en blanco, error de reconocimiento), no se crea nota.

### Campo agregado a OcrAnalysis
Se agregó `topConfidenceText` al modelo de dominio `OcrAnalysis`, calculado en `OCRServiceImpl` ordenando todas las líneas por confianza y tomando las top-5 con longitud útil.

El problema está claro: TFLite clasifica esta boleta de agua como 'recibo', y la línea 97 dice 'recibo' es intocable — el refinamiento nunca corre, aunque tenga keywords de factura.

Un recibo real tiene 13-46 bloques. Esta boleta tiene ~120+. El fix: si TFLite dice 'recibo' pero tiene keywords de factura + muchos bloques → promoverlo a 'factura'.

Primero el test (RED):

● Read 1 file (ctrl+o to expand)

● Está claro. El test en línea 37-44 confirma que 'recibo' es intocable. Necesito:

1. Actualizar el test: sacar 'recibo' de intocables + agregar tests del nuevo comportamiento
2. Agregar la lógica en call() para 'recibo' → 'factura'

Nota: real recibo supermercado = 13-46 bloques. Esta boleta = ~120+ bloques. El umbral de 80 los separa perfectamente.
, igual que un texto de folleto no claro lo toma como manuscrito