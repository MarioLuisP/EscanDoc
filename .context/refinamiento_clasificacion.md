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
