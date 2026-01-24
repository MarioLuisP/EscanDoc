# ÉPICA 3 - SEARCH: Especificación de Desarrollo

**Fecha:** 24 de Enero 2026  
**Versión:** 1.0  
**Historias:** HU-005, HU-006

---

## OBJETIVO DE LA ÉPICA

Implementar búsqueda full-text con FTS5 en documentos y notas. Incluye búsqueda por voz como diferenciador para usuarios mayores.

**Dependencia:** Requiere Épica 1 (Documents) completada.

---

## HISTORIAS DE 


## ÉPICA 3: SEARCH (Feature 3 - Búsqueda)
**Prioridad:** ALTA

### HU-005: Buscar documentos por texto
**Prioridad:** ALTA

**Como** persona mayor  
**Quiero** buscar "Edesur" y ver todas las facturas de luz  
**Para** encontrar documentos rápidamente

**Criterios de Aceptación:**
- [ ] Barra de búsqueda visible en pantalla principal
- [ ] Placeholder claro: "Buscar en documentos..."
- [ ] Fuente 18sp en campo de búsqueda
- [ ] Busca en: nombre del documento + texto OCR + notas vinculadas
- [ ] Resultados aparecen mientras escribo (búsqueda incremental)
- [ ] Muestra snippet del texto encontrado (contexto)
- [ ] Máximo 3 segundos para mostrar resultados
- [ ] Si no hay resultados: "No se encontraron documentos"
- [ ] Usa FTS5 de SQLite para performance

---

### HU-006: Buscar por voz
**Prioridad:** MEDIA (diferenciador)

**Como** persona mayor que no escribe rápido  
**Quiero** buscar diciendo "factura Edesur"  
**Para** encontrar documentos sin escribir

**Criterios de Aceptación:**
- [ ] Botón micrófono visible junto a barra de búsqueda
- [ ] Ícono grande (32x32 dp mínimo)
- [ ] Al tocar, inicia reconocimiento de voz
- [ ] Indicador visual: "Escuchando..." con animación
- [ ] Transcribe a texto y ejecuta búsqueda automáticamente
- [ ] Funciona offline (speech_to_text con modelo local)
- [ ] Si no entiende: "No entendí, intentá de nuevo"
- [ ] Timeout de 5 segundos máximo

---

### HU-005: Buscar documentos por texto
**Prioridad:** ALTA

**Criterios clave:**
- Barra de búsqueda visible en pantalla principal
- Búsqueda incremental (mientras escribe)
- Busca en: nombre + OCR + notas vinculadas
- Resultados en <3 segundos
- Muestra snippet con contexto
- Usa FTS5 de SQLite

---

### HU-006: Buscar por voz
**Prioridad:** MEDIA (diferenciador)

**Criterios clave:**
- Botón micrófono junto a barra búsqueda (32x32dp)
- Indicador visual "Escuchando..."
- Funciona offline (speech_to_text)
- Transcribe y ejecuta búsqueda automáticamente
- Timeout 5 segundos
- Mensaje claro si no entiende

---

## CONTRATO DE TESTS

### PASO 1: Domain (UseCases)

**Tests unitarios requeridos:**

```
test/features/search/domain/usecases/

├── search_documents_test.dart
│   ├── ✓ Debe buscar en documentos y retornar resultados
│   ├── ✓ Debe buscar en notas vinculadas
│   ├── ✓ Debe retornar lista vacía si no encuentra nada
│   ├── ✓ Debe ordenar resultados por relevancia (rank)
│   ├── ✓ Debe limitar resultados a 20 items
│   └── ✓ Debe retornar snippet con query destacado
│
└── voice_search_test.dart
    ├── ✓ Debe transcribir voz correctamente
    ├── ✓ Debe retornar null si no entiende
    ├── ✓ Debe retornar null si timeout (5 seg)
    └── ✓ Debe manejar permiso denegado
```

**Cobertura mínima Domain:** 100%

---

### PASO 2: Data (Repository + Service)

**Tests de integración requeridos:**

```
test/features/search/data/repositories/

└── search_repository_test.dart
    ├── ✓ Debe ejecutar query FTS5 correctamente
    ├── ✓ Debe buscar en documents_fts
    ├── ✓ Debe buscar en notes_fts
    ├── ✓ Debe combinar resultados (docs + notas)
    ├── ✓ Debe generar snippet con highlight
    └── ✓ Debe manejar caracteres especiales en query

test/core/services/

└── speech_service_test.dart
    ├── ✓ Debe inicializar SpeechToText correctamente
    ├── ✓ Debe capturar texto reconocido
    ├── ✓ Debe detener escucha después de timeout
    └── ✓ Debe manejar permiso no otorgado
```

**Nota:** FTS5 ya está creado en DatabaseHelper

---

### PASO 3: Presentation (Provider)

**Tests de provider (opcional para MVP):**

```
test/features/search/presentation/providers/

└── search_provider_test.dart
    ├── ✓ Debe ejecutar búsqueda y actualizar resultados
    ├── ✓ Debe manejar búsqueda incremental (debounce)
    ├── ✓ Debe cambiar estado a "listening" en búsqueda voz
    └── ✓ Debe limpiar resultados al borrar query
```

**Cobertura mínima Provider:** 80% (opcional)

---

## ORDEN DE IMPLEMENTACIÓN (TDD)

### PASO 1: Domain Layer

**Objetivo:** Lógica de búsqueda sin Flutter

**Artefactos a crear:**
```
lib/features/search/domain/usecases/
├── search_documents.dart
└── voice_search.dart

lib/features/search/data/models/
└── search_result.dart
```

**Modelo SearchResult:**
```dart
class SearchResult {
  final String type;      // 'document' o 'note'
  final int id;
  final String title;
  final String snippet;   // Texto con query destacado
  final DateTime? date;   // Para ordenar
}
```

**Workflow:**
1. Escribir tests primero (search_documents_test.dart)
2. Implementar UseCases hasta que tests pasen
3. Repetir para voice_search

**Criterio de avance:** Todos los tests Domain en verde

---

### PASO 2: Data Layer + Core Service

**Objetivo:** FTS5 queries + SpeechToText

**Artefactos a crear:**
```
lib/features/search/data/repositories/
└── search_repository.dart

lib/core/services/
└── speech_service.dart
```

**SQL crítico (FTS5):**
```sql
-- Búsqueda en documentos
SELECT 
  d.id,
  d.title,
  'document' as type,
  snippet(documents_fts, 1, '<b>', '</b>', '...', 32) AS snippet,
  d.created_at
FROM documents d
JOIN documents_fts ON documents_fts.rowid = d.id
WHERE documents_fts MATCH ?
ORDER BY rank
LIMIT 20;

-- Búsqueda en notas
SELECT 
  n.id,
  n.title,
  'note' as type,
  snippet(notes_fts, 1, '<b>', '</b>', '...', 32) AS snippet,
  n.created_at
FROM notes n
JOIN notes_fts ON notes_fts.rowid = n.id
WHERE notes_fts MATCH ?
ORDER BY rank
LIMIT 20;
```

**SpeechService básico:**
```dart
class SpeechService {
  final SpeechToText _speech;
  
  Future<String?> listen({int timeoutSeconds = 5});
  Future<bool> initialize();
  void dispose();
}
```

**Workflow:**
1. Implementar SearchRepository con queries FTS5
2. Implementar SpeechService con speech_to_text
3. Tests de integración en verde

**Criterio de avance:** Tests repository + service en verde

---

### PASO 3: Presentation Layer

**Objetivo:** UI de búsqueda + voz

**Artefactos a crear:**
```
lib/features/search/presentation/
├── providers/
│   └── search_provider.dart
├── pages/
│   └── search_page.dart
└── widgets/
    ├── search_bar_widget.dart
    ├── voice_button.dart
    ├── search_result_card.dart
    ├── listening_indicator.dart
    └── no_results_message.dart
```

**Modificar (integración con home):**
```
lib/features/documents/presentation/pages/
└── documents_list_page.dart
    └── Agregar: barra búsqueda en AppBar
    └── O: FloatingActionButton que abre SearchPage
```

**Workflow:**
1. Crear SearchProvider con debounce (500ms)
2. Crear SearchPage con barra + resultados
3. Agregar VoiceButton con animación
4. Integrar en home
5. Testing manual

**Criterio de avance:** Búsqueda funciona end-to-end

---

## DATOS DE PRUEBA

**Para testing manual (asumiendo Épica 1 completada):**

```sql
-- Documento con OCR para búsqueda
UPDATE documents 
SET ocr_text = 'EDESUR S.A. Factura de Energía Eléctrica. Período Enero 2026. Vencimiento 15/02/2026. Total: $12,500'
WHERE id = 1;

-- Nota para búsqueda
UPDATE notes 
SET content = 'Pagar antes del vencimiento usando Mercado Pago para evitar recargo del 10%'
WHERE id = 1;

-- Triggers FTS5 actualizan automáticamente
```

**Queries de prueba:**
- "edesur" → debe encontrar documento
- "mercado pago" → debe encontrar nota
- "vencimiento" → debe encontrar ambos
- "xyz123" → debe retornar vacío

---

## CRITERIOS DE COMPLETITUD ÉPICA 3

**Checklist antes de pasar a Épica 4:**

### Tests
- [ ] Todos los tests Domain pasan (100% cobertura)
- [ ] Tests de repository pasan (FTS5 queries correctos)
- [ ] Tests de SpeechService pasan
- [ ] No hay tests rojos

### Funcionalidad - Búsqueda texto
- [ ] Barra búsqueda visible en home
- [ ] Placeholder: "Buscar en documentos..." (18sp)
- [ ] Búsqueda incremental funciona (mientras escribe)
- [ ] Resultados aparecen en <3 segundos
- [ ] Snippet muestra contexto con query destacado
- [ ] Busca en: nombre + OCR + notas
- [ ] Si no hay resultados: "No se encontraron documentos"
- [ ] Al tocar resultado, navega a detalle documento

### Funcionalidad - Búsqueda voz
- [ ] Botón micrófono visible (32x32dp)
- [ ] Al tocar, muestra "Escuchando..." con animación
- [ ] Transcribe correctamente en español
- [ ] Funciona offline
- [ ] Timeout de 5 segundos
- [ ] Si no entiende: "No entendí, intentá de nuevo"
- [ ] Al transcribir, ejecuta búsqueda automáticamente

### Arquitectura
- [ ] Domain NO importa Flutter
- [ ] Domain NO importa speech_to_text directamente
- [ ] Repository usa FTS5 (no LIKE queries)
- [ ] Provider maneja debounce correctamente

### Performance
- [ ] Búsqueda tarda <3 segundos (con 100+ docs)
- [ ] UI no se congela durante búsqueda
- [ ] Búsqueda incremental no hace queries excesivos

### Localización
- [ ] Todos los textos usan claves (AppLocalizations)
- [ ] Funciona en ES y EN

---

## ENTREGABLES ESPERADOS

```
lib/features/search/
├── data/
│   ├── models/
│   │   └── search_result.dart         ✓ Completo
│   └── repositories/
│       └── search_repository.dart     ✓ Completo + tests FTS5
├── domain/
│   └── usecases/
│       ├── search_documents.dart      ✓ Completo + tests
│       └── voice_search.dart          ✓ Completo + tests
└── presentation/
    ├── providers/
    │   └── search_provider.dart       ✓ Con debounce
    ├── pages/
    │   └── search_page.dart           ✓ UI mínima funcional
    └── widgets/
        ├── search_bar_widget.dart     ✓ Completo
        ├── voice_button.dart          ✓ Completo
        ├── search_result_card.dart    ✓ Completo
        ├── listening_indicator.dart   ✓ Con animación
        └── no_results_message.dart    ✓ Completo

lib/core/services/
└── speech_service.dart                ✓ Completo + tests

test/features/search/
├── domain/
│   └── usecases/                      ✓ 2 archivos, ~10 tests
└── data/
    └── repositories/                  ✓ 1 archivo, ~6 tests

test/core/services/
└── speech_service_test.dart           ✓ ~4 tests

Modificaciones:
lib/features/documents/presentation/pages/
└── documents_list_page.dart           ✓ Integración búsqueda
```

---

## NOTAS PARA CLAUDE CODE

1. **FTS5 ya existe** - Triggers ya configurados en DatabaseHelper
2. **Debounce crítico** - Evitar queries en cada tecla (usar 500ms)
3. **Snippet con highlight** - Usar `<b>` tags, UI los estiliza
4. **Permisos micrófono** - SpeechService debe manejarlos
5. **Búsqueda voz ES** - Configurar locale='es_ES' en SpeechToText
6. **Combinar resultados** - Docs + Notes en una sola lista
7. **Sin búsqueda en tiempo real extremo** - Esperar 500ms después de última tecla

---

## PERFORMANCE CRÍTICA

**FTS5 optimization:**
```sql
-- NO hacer esto (lento):
SELECT * FROM documents WHERE title LIKE '%query%';

-- SÍ hacer esto (rápido):
SELECT * FROM documents_fts WHERE documents_fts MATCH 'query';
```

**Debounce en Provider:**
```dart
Timer? _debounce;

void search(String query) {
  _debounce?.cancel();
  _debounce = Timer(Duration(milliseconds: 500), () {
    _executeSearch(query);
  });
}
```

---

## REFERENCIAS en /.context

- **Arquitectura:** /architecture.md`
- **Schema BD:** `/database_schema.md` (FTS5 tables)
- **Historias completas:** `/user_stories_mvp.md`
- **Épicas previas:** `ÉPICA_1_SPEC.md`, `ÉPICA_2_SPEC.md`
- **Decisiones técnicas:** `/project/ADDS.md`
- **Package speech_to_text:** Revisar docs para permisos Android/iOS