l punto 7 era la duplicación entre ScanProvider e ImportProvider (~90% código compartido). Déjame releer ambos para darte una propuesta precisa.

Reading 2 files… (ctrl+o to expand)
⎿  lib\features\documents\presentation\providers\import_provider.dart

● Ahora puedo ver el cuadro exacto. La duplicación es real y significativa, pero las diferencias también son concretas. Acá va el análisis.

  ---
Diagnóstico: qué se duplica y qué no

Idéntico (~130 líneas duplicadas)

┌─────────────────────────────────────────────────────────────────┬───────────────────────────────┬───────────────────────────────────────────────────┐
│                             Lógica                              │         ScanProvider          │                  ImportProvider                   │
├─────────────────────────────────────────────────────────────────┼───────────────────────────────┼───────────────────────────────────────────────────┤
│ PreparationResult class                                         │ ScanPreparationResult         │ ImportPreparationResult — mismos 4 campos exactos │
├─────────────────────────────────────────────────────────────────┼───────────────────────────────┼───────────────────────────────────────────────────┤
│ Pipeline prepare: convert → classify → normalize/thumbnail      │ prepareScan() líneas 128-174  │ prepareImport() líneas 127-177                    │
├─────────────────────────────────────────────────────────────────┼───────────────────────────────┼───────────────────────────────────────────────────┤
│ Pipeline complete: normalize si foto → save → OCR               │ completeScan() líneas 224-267 │ completeImport() líneas 230-277                   │
├─────────────────────────────────────────────────────────────────┼───────────────────────────────┼───────────────────────────────────────────────────┤
│ OCR background                                                  │ _processOCRInBackground()     │ _processOCRInBackground()                         │
├─────────────────────────────────────────────────────────────────┼───────────────────────────────┼───────────────────────────────────────────────────┤                                                                            │ State: _isSaving, _isProcessingOCR, _error, _lastClassification │ sí                            │ sí                                                │
├─────────────────────────────────────────────────────────────────┼───────────────────────────────┼───────────────────────────────────────────────────┤                                                                          
│ clearError()                                                    │ sí                            │ sí                                                │
└─────────────────────────────────────────────────────────────────┴───────────────────────────────┴───────────────────────────────────────────────────┘                                                                             
Diferente (lo que hace a cada provider único)                                                                                                                                                                                                      
┌────────────────────────────┬───────────────────────────────────────┬────────────────────────────────────────────────┐
│                            │             ScanProvider              │                 ImportProvider                 │
├────────────────────────────┼───────────────────────────────────────┼────────────────────────────────────────────────┤
│ Origen del archivo         │ _scanDocument.call() (scanner nativo) │ recibe File por parámetro                      │
├────────────────────────────┼───────────────────────────────────────┼────────────────────────────────────────────────┤
│ _statusMessage             │ no tiene                              │ sí, actualiza en cada paso                     │
├────────────────────────────┼───────────────────────────────────────┼────────────────────────────────────────────────┤
│ PDF multi-página           │ no                                    │ importPdfPages(), checkPdfPageCount()          │
├────────────────────────────┼───────────────────────────────────────┼────────────────────────────────────────────────┤
│ Tracking OCR               │ booleano simple                       │ _processingOcrIds (Set, múltiples simultáneos) │
├────────────────────────────┼───────────────────────────────────────┼────────────────────────────────────────────────┤
│ onOcrComplete callback     │ no                                    │ sí                                             │
├────────────────────────────┼───────────────────────────────────────┼────────────────────────────────────────────────┤
│ onStatus callback al OCR   │ no                                    │ sí                                             │
├────────────────────────────┼───────────────────────────────────────┼────────────────────────────────────────────────┤
│ _isScanning / _isImporting │ _isScanning                           │ _isImporting                                   │
└────────────────────────────┴───────────────────────────────────────┴────────────────────────────────────────────────┘

  ---
Propuesta: composición con DocumentPipeline

Ni herencia ni mixin. Composición: extraer la lógica compartida a una clase pura (no es un provider, no extiende ChangeNotifier) que ambos providers usan internamente.

┌──────────────┐     ┌──────────────────┐     ┌──────────────┐
│ ScanProvider │────▶│ DocumentPipeline  │◀────│ImportProvider│
│              │     │  (lógica pura)    │     │              │
│ + scanner    │     │                   │     │ + PDF import │
│ + isScanning │     │ prepare(file)     │     │ + statusMsg  │
│              │     │ complete(prep)    │     │ + ocrIds     │
│              │     │ processOCR(id)    │     │              │
└──────────────┘     └──────────────────┘     └──────────────┘

DocumentPipeline contendría:

class DocumentPipeline {
final ImportDocument _importDocument;
final ImageClassifier _imageClassifier;
final SaveScannedDocument _saveDocument;
final ProcessOCR _processOCR;
final ThumbnailGenerator _thumbnailGenerator;

    // 1. Preparar: convert → classify → normalize/thumbnail
    Future<PreparationResult> prepare(File file);

    // 2. Completar: normalize si foto → save → retorna documento
    Future<DocumentModel> complete(PreparationResult prep, String locale);

    // 3. OCR background
    Future<void> processOCR(int docId, String tfliteClass, String locale);
}

PreparationResult unificado:

Una sola clase reemplaza ScanPreparationResult e ImportPreparationResult (son idénticas hoy).

Cada provider mantiene su personalidad:

ScanProvider queda liviano:
Future<PreparationResult?> prepareScan() async {
_isScanning = true; notifyListeners();
final file = await _scanDocument.call();  // lo único propio
if (file == null) { ... return null; }
final result = await _pipeline.prepare(file);  // delegado
_isScanning = false; notifyListeners();
return result;
}

ImportProvider mantiene sus extras:
Future<PreparationResult?> prepareImport(File file) async {
_isImporting = true;
_statusMessage = 'status_preparing';  // lo propio
notifyListeners();
final result = await _pipeline.prepare(file);  // delegado
_statusMessage = null;
_isImporting = false;
notifyListeners();
return result;
}

Y importPdfPages(), checkPdfPageCount(), _processingOcrIds se quedan exclusivamente en ImportProvider.

  ---
Ventajas de esta propuesta

1. Elimina ~130 líneas duplicadas sin forzar herencia artificial
2. DocumentPipeline es testeable aislado — lógica pura, sin ChangeNotifier
3. En main.dart se instancian los servicios una sola vez: se crea un DocumentPipeline y se inyecta a ambos providers
4. Cada provider sigue siendo independiente: no hay acoplamiento entre scan e import
5. Los debugPrint de timing pueden vivir en Pipeline: un solo lugar para el logging de performance

Riesgo bajo

El refactor es mecánico: extraer, delegar, no cambia comportamiento. Los tests de domain (usecases) no se tocan. Solo necesitarías verificar que los flujos completos siguen funcionando igual en emulador.

