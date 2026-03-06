# Flujo PDF — Plan de implementación

## Principio fundamental

La app siempre trabaja con JPG internamente.
El PDF de entrada es solo una fuente de datos, nunca se almacena.
El PDF de salida se genera al momento del export, nunca se guarda en la app.

---

## Flujo de Import (PDF → documentos)

### Paso 1: Detección del tipo de PDF

Al importar un PDF, antes de cualquier procesamiento:
- Intentar extraer texto de la primera página con pdfrx
- Si el texto extraído tiene sustancia (> 50 caracteres significativos) → PDF editable
- Si devuelve vacío o basura → PDF imagen

### Paso 2a: PDF editable (texto nativo)

- Extraer texto completo directamente con pdfrx (sin OCR, sin conversión)
- Renderizar página 1 como JPG (thumbnail + imagen del documento)
- Guardar como documento normal: JPG + texto ya extraído en `ocr_text`
- `document_type` inferido por keywords del texto (clasificador existente)
- Sin TFLite ni OCR → mucho más rápido

### Paso 2b: PDF imagen (páginas escaneadas)

- Renderizar cada página como JPG con pdfrx
- Cada página → documento independiente en la DB
- Cada JPG pasa por el pipeline normal: TFLite → clasificador → OCR
- Límite: máximo 10 páginas por PDF
  - Si el PDF tiene más de 10 páginas → dialog al usuario:
    "Este PDF tiene N páginas. ¿Importar solo las primeras 10 o elegir cuántas?"

---

## Flujo de Export

### Export documento individual

- Tomar el JPG almacenado del documento
- Generar PDF de una página con pdf_converter_service.dart (ya existe, optimizado)
- Compartir vía share sheet del SO (WhatsApp, mail, etc.)
- El PDF generado es temporal, se borra después de compartir

### Export combinado (multi-selección)

- Usuario selecciona N documentos
- Tomar los N JPGs en el orden seleccionado
- Generar PDF de N páginas (extender pdf_converter_service para multi-página)
- Compartir o guardar en carpeta de descargas
- PDF temporal igual que el individual

---

## Dependencias resultantes

| Paquete | Para qué | Estado |
|---|---|---|
| `pdfrx` | Leer PDF al importar: detectar tipo, extraer texto, renderizar páginas | Mantener |
| `pdf` + `pdf/widgets` | Generar PDF al exportar | Mantener |
| `printing` | Reemplazado por pdfrx para el raster | **Eliminar** |
| `image` | Solo lee headers JPEG en pdf_converter_service | Evaluar |

---

## Archivos

**Existente — conservar:**
- `lib/core/services/pdf_converter_service.dart`
  - Export JPG → PDF (ya implementado y optimizado)
  - Extender para recibir lista de JPGs → PDF multi-página

**A crear cuando se implemente:**
- `lib/features/import/data/services/pdf_import_service.dart`
  - Detección editable vs imagen
  - Extracción de texto directo (PDF editable)
  - Renderizado de páginas a JPG (PDF imagen)
  - Lógica del límite de páginas + dialog

**Eliminado:**
- `lib/core/services/pdf_generator.dart` → borrado (duplicados + sin uso activo)

---

## Orden de implementación sugerido

1. Import PDF imagen (más común, extiende pipeline existente) ✅ IMPLEMENTADO
2. Export individual (extiende pdf_converter_service)
3. Export combinado multi-página
4. Import PDF editable (menos urgente, es un bonus de UX)

---

## Estado: Import PDF imagen — COMPLETADO (Feb 2026)

### Qué se implementó

**Domain:** `PdfImportService` (abstract) + `PdfImportException`
- `getPageCount(pdfPath)` → int
- `renderPagesToJpg(pdfPath, outputDir, {maxPages})` → List<File>

**Data:** `PdfImportServiceImpl` usando pdfrx
- Renderizado a 150 DPI (suficiente para OCR en texto vectorial: sin ruido, bordes nítidos)
- Flujo in-memory sin archivo PNG temporal: pdfrx → dart:ui → PNG bytes en memoria → FlutterImageCompress → JPG (una sola escritura a disco)

**Provider:** dos métodos nuevos en `ImportProvider`
- `checkPdfPageCount(path)` → retorna cantidad de páginas para que la UI decida
- `importPdfPages(path, pagesToImport, locale)` → renderiza y pasa cada página al pipeline existente (TFLite + OCR + BD), con progreso `pdfCurrentPage / pdfTotalPages`
- `PdfImportService` es opcional (nullable) para no romper tests existentes

**UI:** `home_page.dart`
- `_handleImport()` detecta extensión: si es PDF bifurca a `_handlePdfImport()`
- `_handlePdfImport()` pide pageCount, muestra dialog si > 10 páginas (opciones: Primeras 10 / Todas / Cancelar), llama `importPdfPages()`, navega al detalle de la primera página
- Dialog con strings hardcodeados — pendiente mover a claves i18n cuando se internacionalice

**DI:** `PdfImportServiceImpl` inyectado en `ImportProvider` en `main.dart`

### Decisiones técnicas
- 150 DPI elegido sobre 200 DPI: menos presión de memoria, suficiente para MLKit en PDFs digitales
- Cada página → documento independiente en BD (mismo comportamiento que importar N imágenes)
- Si una página falla, las demás se procesan igual (no aborta todo)
- Los JPG temporales renderizados se borran después de procesar cada página
- Pipeline de imagen (TFLite, clasificación, normalización, OCR) sin cambios

### Pendiente de esta etapa
- Mover strings del dialog a claves i18n (`pdf_too_long`, `pdf_import_first_10`, etc.)

La sesión anterior terminó bien — paso 1 (Import PDF imagen) completado y diagrama actualizado.

Estado actual del plan (50_flujo_pdf_editable.md):                                                                                                                                                                               
1. ✅ Import PDF imagen
2. ⏳ Export individual — próximo paso                                                                                                                                                                                           ─
3. ⏳ Export combinado multi-página
4. ⏳ Import PDF editable

  ---
Resumen de lo implementado:

┌─────────────────────────────────┬───────────────────────────────────────────────────┐
│             Archivo             │                      Cambio                       │
├─────────────────────────────────┼───────────────────────────────────────────────────┤
│ a4_normalizer_service.dart      │ Abstract + calculateA4Fit (lógica pura testeable) │
├─────────────────────────────────┼───────────────────────────────────────────────────┤
│ a4_normalizer_service_impl.dart │ Impl con dart:ui: canvas A4 blanco + contain fit  │
├─────────────────────────────────┼───────────────────────────────────────────────────┤
│ pdf_converter_service.dart      │ convertImageBytesToPdfA4() con dimensiones fijas  │
├─────────────────────────────────┼───────────────────────────────────────────────────┤
│ photo_fullscreen_page.dart      │ StatefulWidget + bottom sheet + loading inline    │
├─────────────────────────────────┼───────────────────────────────────────────────────┤
│ pubspec.yaml                    │ share_plus: ^10.1.0                               │
├─────────────────────────────────┼───────────────────────────────────────────────────┤
│ es.json / en.json               │ 5 claves nuevas                                   │
├─────────────────────────────────┼───────────────────────────────────────────────────┤
│ photo_fullscreen_page_test.dart │ Removidos tests del botón print                   │
└─────────────────────────────────┴───────────────────────────────────────────────────┘

El A4FitResult con calculateA4Fit queda disponible para cuando implementemos el export combinado multi-página — cada JPG se normaliza a A4 y después los unimos en un solo PDF.
El lugar natural: DocumentsListPage con selección múltiple por long-press

Por qué ahí y no en otro lado

1. Ya tenés long-press en cada item de la lista — hoy dispara el delete dialog directamente
2. Es la única pantalla donde el usuario ve todos sus documentos juntos — el contexto correcto para "elegir varios y combinar"
3. Home muestra solo 3 recientes — no tiene sentido seleccionar ahí
4. El patrón long-press → selección múltiple es universal (Google Photos, WhatsApp, Files)

Cómo funcionaría

Estado normal (lo que ya tenés):
┌─────────────────────────────────┐
│  EscanDocs                      │
│  Todos los documentos           │
│  [Más reciente ▾]               │
│ ┌─────────────────────────────┐ │
│ │ 📄 Factura 1 del 3/3       │ │  ← tap → detalle
│ │ 📄 Documento 2 del 3/3     │ │  ← long-press → modo selección
│ │ 📄 Recibo 1 del 2/3        │ │
│ │ 📝 Mi nota personal        │ │
│ └─────────────────────────────┘ │
│ ┌───────────┐ ┌───────────────┐ │
│ │ 🏠 Inicio │ │ 🔍 Buscar    │ │
│ └───────────┘ └───────────────┘ │
└─────────────────────────────────┘

Modo selección (se activa con long-press en cualquier item):
┌─────────────────────────────────┐
│  ✕  3 seleccionados             │  ← header se transforma
│                                 │
│ ┌─────────────────────────────┐ │
│ │ ☑ Factura 1 del 3/3        │ │  ← tap ahora toggle check
│ │ ☑ Documento 2 del 3/3      │ │
│ │ ☐ Recibo 1 del 2/3         │ │
│ │ ☑ Mi nota personal          │ │
│ └─────────────────────────────┘ │
│ ┌───────────┐ ┌───────────────┐ │
│ │ 🗑 Eliminar│ │ 📑 Crear PDF │ │  ← barra inferior se transforma
│ └───────────┘ └───────────────┘ │
└─────────────────────────────────┘

Por qué este enfoque encaja con tu filosofía de diseño

Para el usuario mayor (60-85):
- En el uso diario no ve nada nuevo — la lista funciona exactamente igual
- No hay botones extra que confundan
- El flujo primario (escanear, ver, buscar) no se toca

Para el usuario avanzado:
- Long-press es un gesto que ya conoce (lo usaba para borrar)
- Al entrar en modo selección, las acciones son explícitas y grandes
- Puede seleccionar 2, 5, 20 documentos y combinar en un tap
- Es el mismo patrón del botón + en home: "oculto pero a mano"

Detalles de implementación que importan para UX

1. La transición debe ser suave y clara:
- El item long-presionado queda seleccionado (con check verde)
- Los demás items muestran un checkbox vacío (aparece con animación)
- La barra inferior cambia de [Inicio][Buscar] a [Eliminar][Crear PDF]
- El título cambia a "X seleccionados" con una ✕ para cancelar

2. El botón "Crear PDF" solo aparece si hay ≥2 seleccionados:
- Con 1 seleccionado: solo [Eliminar] (reemplaza el long-press → delete actual)
- Con 2+: [Eliminar] y [Crear PDF]
- Esto evita confusión — combinar 1 documento no tiene sentido

3. Delete actual migra al modo selección:
- Hoy: long-press → dialog "¿Eliminar?" (1 documento)
- Propuesto: long-press → selección → [Eliminar] (1 o más documentos)
- Es más potente (borrar varios a la vez) y más consistente

4. Orden de selección = orden en el PDF:
- Los documentos se combinan en el orden en que aparecen en la lista
- El usuario puede cambiar el sort antes de seleccionar para controlar el orden
- Esto es intuitivo sin necesitar drag & drop (que es difícil para manos mayores)

Lo que NO haría

- No agregar un botón "Exportar" permanente en la barra inferior — contamina la vista principal con una acción que se usa poco
- No poner la opción en el menú + de home — ese es para crear/ingresar, no para exportar
- No crear una pantalla nueva de "Seleccionar documentos" — duplica la lista y confunde
- No usar FAB flotante — ocupa espacio visual, compite con el botón ESCANEAR


❯ excelentee, me parece perfecto| que propones para que el usuario pueda ordenar facilmente las paginas del pdf a exportar? que pueda ir ordenando antes de exzportar

● Buena pregunta. El sort de la lista resuelve el orden inicial, pero el usuario necesita control fino antes de exportar. Déjame pensar en las opciones.

El problema                                                                                                                                                                                                                         
Drag & drop es la solución obvia en apps para jóvenes, pero para manos de 60-85 años:
- El gesto de mantener presionado + arrastrar es difícil (temblor, precisión)
- En listas largas hay que hacer scroll mientras arrastrás — frustrante
- Es fácil soltar en el lugar equivocado

Propuesta: pantalla de "Vista previa PDF" con flechas

Después de seleccionar documentos y tocar [Crear PDF], antes de exportar, se abre una pantalla intermedia:                                                                                                                                                                                                                                                                                                                                                          
┌─────────────────────────────────┐                                                                                                                                                                                              
│  ← Ordenar páginas              │
│                                 │
│  ┌───┬──────────────────┬───┐  │
│  │   │                  │   │  │                                                                                                                                                                                               
│  │   │  📄 miniatura 1  │ ▲ │  │  ← botón subir                                                                                                                                                                                
│  │ 1 │  Factura 1 del…  │   │  │                                                                                                                                                                                               
│  │   │                  │ ▼ │  │  ← botón bajar                                                                                                                                                                                
│  │   │                  │   │  │                                                                                                                                                                                               
│  ├───┼──────────────────┼───┤  │                                                                                                                                                                                               
│  │   │                  │   │  │                                                                                                                                                                                               
│  │   │  📄 miniatura 2  │ ▲ │  │                                                                                                                                                                                               
│  │ 2 │  Documento 2…    │   │  │                                                                                                                                                                                               
│  │   │                  │ ▼ │  │                                                                                                                                                                                                 │  │   │                  │   │  │
│  ├───┼──────────────────┼───┤  │                                                                                                                                                                                               
│  │   │                  │   │  │                                                                                                                                                                                                 │  │   │  📄 miniatura 3  │ ▲ │  │
│  │ 3 │  Mi nota pers…   │   │  │                                                                                                                                                                                               
│  │   │                  │ ▼ │  │                                                                                                                                                                                               
│  │   │                  │   │  │
│  └───┴──────────────────┴───┘  │                                                                                                                                                                                               
│                                 │
│  ┌─────────────────────────────┐│                                                                                                                                                                                              
│  │    📑  Exportar PDF (3)     ││                                                                                                                                                                                              
│  └─────────────────────────────┘│                                                                                                                                                                                              
└─────────────────────────────────┘                                                                                                                                                                                                                                                                                                                                                                                                                                 
Por qué flechas y no drag & drop                                                                                                                                                                                                                   
┌─────────────────────┬─────────────────────────────┬─────────────────────────────────┐                                                                                                                                            │                     │         Drag & drop         │           Flechas ▲ ▼           │
├─────────────────────┼─────────────────────────────┼─────────────────────────────────┤                                                                                                                                          
│ Precisión requerida │ Alta (mantener + arrastrar) │ Baja (un tap)                   │
├─────────────────────┼─────────────────────────────┼─────────────────────────────────┤
│ Temblor de manos    │ Problema serio              │ No afecta                       │                                                                                                                                            ├─────────────────────┼─────────────────────────────┼─────────────────────────────────┤
│ Feedback visual     │ Ambiguo (¿dónde lo suelto?) │ Inmediato (se mueve 1 posición) │                                                                                                                                          
├─────────────────────┼─────────────────────────────┼─────────────────────────────────┤                                                                                                                                            │ Descubrimiento      │ Poco intuitivo para mayores │ Botón visible = acción obvia    │
├─────────────────────┼─────────────────────────────┼─────────────────────────────────┤                                                                                                                                            │ Scroll + arrastrar  │ Muy difícil                 │ No necesario                    │
└─────────────────────┴─────────────────────────────┴─────────────────────────────────┘                                                                                                                                                            
Detalles de cada item en la lista                                                                                                                                                                                                                  
┌─────┬──────────────────────────┬────────┐                                                                                                                                                                                      
│     │  Factura 1 del 3/3       │        │                                                                                                                                                                                      
│  1  │  📄 miniatura 60×80      │  ▲  ▼  │
│     │  3 Mar 2026              │        │                                                                                                                                                                                      
└─────┴──────────────────────────┴────────┘
- Número grande a la izquierda: posición en el PDF — se actualiza al mover
- Miniatura + título + fecha: identifica el documento rápidamente
- ▲ ▼ a la derecha: botones grandes (48×48 tap target mínimo), bien separados
- El ▲ del primero y el ▼ del último se deshabilitan (gris tenue)

La interacción al mover                                                                                                                                                                                                                                                                                                                                                                                                                                             
Cuando el usuario toca ▲ en el item 3:
1. El item 3 sube a posición 2 con una animación suave (300ms, slide)
2. El item que estaba en 2 baja a 3
3. Los números se actualizan
4. El item movido queda brevemente resaltado (flash verde sutil) para confirmar visualmente

Esto es rápido: 3 taps para mover un item del final al principio en una lista de 4. Para listas más largas...

Atajo para listas largas (5+ items): "Mover al inicio / Mover al final"                                                                                                                                                                                                                                                                                                                                                                                             
Si la lista tiene 5 o más documentos, agregar un long-press en las flechas:
- Long-press en ▲ → mueve al inicio (posición 1)
- Long-press en ▼ → mueve al final

Con un tooltip/snackbar sutil la primera vez: "Mantené presionado para mover al inicio". Es un atajo descubrible sin ser necesario — el usuario puede ignorarlo y usar taps simples.                                                                                                                                                                                                                                                                                
Opción complementaria: ¿ofrecer drag & drop también?                                                                                                                                                                                               
Sí, pero como gesto secundario, no primario. Flutter tiene ReorderableListView que es gratis. Los usuarios avanzados o más jóvenes (hijos/nietos ayudando) lo usarían naturalmente. Las flechas quedan como método principal y     accesible.

Ambos métodos coexisten sin conflicto:
- Flechas: siempre visibles, método principal
- Drag handle (⠿ grip icon): a la izquierda del número, funciona pero no es prominente                                                                                                                                                             
  ┌──┬─────┬──────────────────┬────────┐                                                                                                                                                                                           
  │⠿│  1  │  Factura 1 del…  │  ▲  ▼  │                                                                                                                                                                                            
  └──┴─────┴──────────────────┴────────┘                                                                                                                                                                                           
  ↑ drag handle discreto (gris claro)

Flujo completo integrado                                                                                                                                                                                                                                                                                                                                                                                                                                            
DocumentsListPage          Vista previa PDF         Resultado                                                                                                                                                                    
─────────────────         ──────────────────       ──────────                                                                                                                                                                    
Long-press → selección    Reordenar con ▲▼        PDF generado                                                                                                                                                                   
Tap items (checks)   →    [Exportar PDF (3)]  →   Share sheet                                                                                                                                                                    
[Crear PDF]               ← (back = cancelar)     o guardar                                                                                                                                                                      
Lo que NO haría

- No numerar en la selección — el orden de selección (1ro clickeado = página 1) es confuso e irreversible. Mejor usar el orden de la lista + reordenar después
- No mostrar un grid de miniaturas — ocupa mucho espacio y las fotos de documentos se parecen mucho entre sí; el título es más útil para identificar
- No pedir el nombre del PDF antes de ordenar — primero el contenido, después el nombre (o autogenerarlo)                           