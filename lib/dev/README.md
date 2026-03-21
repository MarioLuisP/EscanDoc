# lib/dev — Herramientas de Desarrollo

Esta carpeta contiene herramientas temporales de desarrollo que **no forman parte
del build de producción**. Los archivos aquí son intencionalmente ignorados por el
router de la app y no se importan desde `main.dart`.

---

## fixture_capture_page.dart

### ¿Para qué sirve?

Página Flutter para capturar fixtures OCR reales desde el dispositivo físico.
Usada para implementar **Golden Master Testing** en `blocksToMarkdown`.

Un fixture es un JSON con la estructura de bloques que devuelve ML Kit para un
documento real. Capturando fixtures del dispositivo podemos testear el algoritmo
`blocksToMarkdown` sin depender de ML Kit en los tests.

### ¿Cuándo volver a usarla?

- Cuando se agregue un nuevo tipo de documento no cubierto por los 8 fixtures actuales
- Cuando se modifique el algoritmo `blocksToMarkdown` y se necesiten nuevos casos de prueba
- Cuando se quiera testear un documento problemático específico

### Fixtures actuales (test/fixtures/)

| Fixture | Tipo | Descripción |
|---------|------|-------------|
| `fixture_documento_plano.json` | documento | Texto corrido, párrafos |
| `fixture_receta.json` | médico | Formulario de hospital con campos manuscritos |
| `fixture_horario.json` | documento | Tabla ALL_CAPS (horario escolar) |
| `fixture_factura_luz.json` | factura | Factura de servicio eléctrico |
| `fixture_factura_agua.json` | factura | Factura de servicio de agua |
| `fixture_tiket.json` | recibo | Ticket de farmacia |
| `fixture_folleto.json` | folleto | Manual de instrucciones de licuadora (2 columnas) |
| `fixture_test_ocr.json` | documento | Documento de prueba con secciones mixtas |

Los goldens correspondientes están en `test/fixtures/golden/*.md`.

### Cómo reactivarla

**1. Agregar import en `lib/main.dart`:**
```dart
import 'dev/fixture_capture_page.dart';
```

**2. Agregar ruta en `lib/main.dart` dentro del `routes` map:**
```dart
'/dev/fixture': (context) => const FixtureCapturePage(),
```

**3. Agregar botón en `lib/features/documents/presentation/pages/home_page.dart`**
dentro de `_ActionsSheet`, debajo del botón Importar:
```dart
const SizedBox(height: 10),
OutlinedButton.icon(
  icon: const Icon(Icons.bug_report, size: 16),
  label: const Text('[DEV] Capturar Fixture OCR'),
  onPressed: () {
    Navigator.pop(context);
    Navigator.pushNamed(context, '/dev/fixture');
  },
),
```

### Flujo de captura

```
Abrir página DEV → Ingresar nombre del fixture → Seleccionar imagen/PDF
  → ConvertToJpg → NormalizeImage → ML Kit OCR → JSON con bloques
  → Guardar en internal storage → Compartir via share_plus
  → Mover JSON a test/fixtures/fixture_<nombre>.json
```

### Notas técnicas

- Usa `FileType.any` (no `FileType.custom`) para que el file picker muestre PDFs en Android
- Guarda en `getApplicationDocumentsDirectory()` porque Android 10+ bloquea escritura en `/Pictures`
- El JSON incluye `fixtureName`, `blockCount` y `blocks` con `text`, `confidence`, `angle` y `bbox`
- El pipeline aplica: convertToJpg → normalizeImage (resize A4 + compress 850KB) antes del OCR,
  replicando exactamente el pipeline de producción
