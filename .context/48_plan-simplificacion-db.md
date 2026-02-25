# Plan: Simplificación DB — Tabla única + LIKE normalizado

**Fecha:** Feb 2026
**Estado:** Pendiente (hacer en hilo separado con desinstalación previa)

---

## Motivación

Tres problemas en uno:
1. **FTS4 no sirve para tildes** y agrega complejidad sin beneficio real para este volumen
2. **Tabla `notes` separada** con many-to-many es sobrediseño — un documento tiene UNA nota
3. **Sin campo `document_type`** — el tipo se infiere del título en runtime, no está persistido

---

## Schema nuevo — una sola tabla

```sql
CREATE TABLE documents (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  title           TEXT NOT NULL,
  file_path       TEXT NOT NULL,
  document_type   TEXT,          -- factura, recibo, foto, manuscrito, documento, folleto
  note_content    TEXT,          -- reemplaza tablas notes + document_notes
  ocr_text        TEXT,
  extracted_date  DATE,
  created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP
)
```

Se conserva `due_dates` y `document_due_dates` (Fase 2, sin cambios).

---

## Qué desaparece completamente

### Base de datos
- Tabla `notes`
- Tabla `document_notes`
- Tabla virtual `documents_fts`
- Tabla virtual `notes_fts`
- Trigger `documents_ai`, `documents_ad` (FTS)
- Trigger `notes_ai`, `notes_au`, `notes_ad` (FTS)
- Índices `idx_document_notes_*`

### Código Dart — archivos a ELIMINAR
- `lib/features/notes/data/models/note_model.dart`
- `lib/features/notes/data/repositories/note_repository.dart`
- `lib/features/notes/domain/usecases/create_note.dart`
- `lib/features/notes/domain/usecases/update_note.dart`
- `lib/features/notes/domain/usecases/get_note_by_document.dart`
- `lib/features/notes/domain/usecases/delete_note.dart`
- `lib/features/notes/presentation/providers/note_provider.dart` (o fusionar)

### Tests a eliminar/actualizar
- Todos los tests de NoteRepository, CreateNote, UpdateNote, etc.

---

## Archivos a modificar

### 1. `lib/core/database/database_helper.dart`
- Reemplazar schema completo (tabla única documents, sin notes/document_notes/FTS)
- Eliminar todos los triggers FTS
- Conservar triggers `updated_at` para documents y due_dates
- Conservar índices de documents y due_dates

### 2. `lib/features/documents/data/models/document_model.dart`
- Agregar campo `documentType` (String?)
- Agregar campo `noteContent` (String?)
- Actualizar `fromMap()`, `toMap()`, `copyWith()`, `==`, `hashCode`

### 3. `lib/features/documents/data/repositories/document_repository.dart`
- Guardar/leer `document_type` y `note_content` en queries
- Agregar método `updateNote(int documentId, String? content)`
- Agregar método `updateDocumentType(int documentId, String type)` si se necesita

### 4. `lib/features/notes/presentation/pages/note_editor_page.dart`
- Reemplazar `NoteProvider` + use cases por llamada directa a `DocumentRepository`
- O: crear `updateNote` en `DocumentsProvider` y usarlo desde la página

### 5. `lib/features/documents/presentation/pages/document_detail_page.dart`
- Cambiar referencias de `NoteModel` / `NoteProvider` → `DocumentModel.noteContent`
- Simplifica: ya no necesita cargar nota separada, viene con el documento

### 6. `lib/features/documents/presentation/providers/documents_provider.dart`
- Agregar `updateNote(int documentId, String? content)`
- Que llame a `DocumentRepository.updateNote()`

### 7. `lib/features/search/data/repositories/search_repository_impl.dart`
- Eliminar estrategia FTS completa
- Implementar LIKE normalizado puro
- Buscar en `d.title`, `d.note_content` (antes `n.content`)
- Query unificada: un solo SELECT sobre `documents` (no más JOIN con notes)
- Agregar `_normalizeSqlExpr(column)` con REPLACE() anidado para tildes
- Agregar `_normalizeText()` en Dart para el query del usuario

### 8. `lib/features/scan/domain/usecases/save_scanned_document.dart`
- Guardar `document_type` al crear el documento

### 9. `lib/features/scan/domain/usecases/process_ocr.dart`
- Guardar nota de clasificación en `note_content` (antes usaba `NoteRepository`)
- Guardar refinamiento en `note_content` si hubo corrección

### 10. `lib/main.dart`
- Eliminar providers de notas del MultiProvider
- Eliminar imports de NoteRepository, CreateNote, UpdateNote, etc.

### 11. `lib/features/documents/presentation/pages/documents_list_page.dart`
- `_docTypeKey` pasa a leer `document.documentType` directamente
- Ya no infiere desde el título

---

## Cómo queda la búsqueda

```
Usuario escribe "nóta" (o "NOTA" o "nota")
    ↓
Dart: _normalizeText() → "nota"
    ↓
SQL en tabla documents:
  WHERE normalize(title)        LIKE '%nota%'
     OR normalize(note_content) LIKE '%nota%'
    ↓
Matchea en cualquier dirección: con tilde o sin tilde, mayúsculas o no
```

Un solo query, sin JOINs, sin FTS. Resultado tiene `id` = `document_id` siempre.

---

## SearchResult simplificado

Con nota dentro de documents, el `SearchResult` ya no necesita distinguir tanto:
- `type`: sigue siendo 'document' o 'note' (indica dónde matcheó)
- `documentId`: siempre es `d.id` (no más lookup en `document_notes`)

---

## Notas del clasificador/refinador

Actualmente `ProcessOCR` crea una nota en la tabla `notes` con el texto de clasificación
("Clasificado como: factura"). Con el nuevo schema:
- Esa nota va en `note_content` del documento
- Si ya hay nota del usuario, concatenar con separador (`\n---\n`)
- O solo guardar si `note_content` está vacío (la del clasificador es de bajo valor para el usuario)

**Decisión pendiente**: ¿Se conservan las notas automáticas del clasificador o se descartan?
Recomendación: descartarlas. El usuario no las pidió y ocupan espacio en su nota.

---

## Orden de trabajo

1. Desinstalar app del celular (limpia la DB)
2. Modificar `database_helper.dart` → schema nuevo
3. Modificar `document_model.dart` → agregar `documentType` y `noteContent`
4. Modificar `document_repository.dart` → nuevos campos + `updateNote()`
5. Eliminar archivos de notes (model, repository, use cases)
6. Modificar `documents_provider.dart` → agregar `updateNote()`
7. Modificar `note_editor_page.dart` → usar DocumentsProvider
8. Modificar `document_detail_page.dart` → leer noteContent del modelo
9. Modificar `save_scanned_document.dart` → guardar document_type
10. Modificar `process_ocr.dart` → nota en document, sin NoteRepository
11. Modificar `search_repository_impl.dart` → LIKE normalizado
12. Limpiar `main.dart` → sacar providers y deps de notes
13. Actualizar/eliminar tests afectados
14. Compilar, probar búsqueda y flujo completo de notas

---

## Riesgos / a tener en cuenta

- Sin migración → requiere desinstalación. Para producción habría que migrar.
- `process_ocr.dart` usa `NoteRepository` directamente → revisar bien ese flujo
- Los tests de notes son varios → definir cuáles se eliminan vs cuáles se adaptan
- `NoteProvider` está inyectado en `main.dart` con sus dependencias → limpiar todo


● Todo listo. Resumen de lo que se hizo:                                                                                                                                                                                                                                                                                                                                                                                                                              
---                                                                                                                                                                                                                                Cambios realizados:                                                                                                                                                                                                              
┌─────────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────┐                                                                                                   │           Archivo           │                                             Cambio                                             │
├─────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────┤
│ database_helper.dart        │ Schema nuevo: tabla única documents + due_dates. Sin notes, document_notes, FTS4, triggers FTS │
├─────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────┤
│ document_model.dart         │ Agregados documentType y noteContent                                                           │
├─────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────┤
│ document_repository.dart    │ Agregado updateNote()                                                                          │
├─────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────┤
│ documents_provider.dart     │ Guarda ref al repo, agrega updateNote()                                                        │
├─────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────┤
│ save_scanned_document.dart  │ Guarda documentType: tfliteClass                                                               │
├─────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────┤
│ process_ocr.dart            │ Eliminado NoteRepository — nota va en noteContent del documento vía updateDocument()           │
├─────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────┤
│ search_repository_impl.dart │ Reemplazado FTS + JOIN por LIKE normalizado, un solo query                                     │
├─────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────┤
│ note_editor_page.dart       │ Usa DocumentsProvider.updateNote(), lee initialContent de args                                 │
├─────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────┤
│ document_detail_page.dart   │ Eliminado Consumer<NoteProvider>, lee document.noteContent                                     │
├─────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────┤
│ documents_list_page.dart    │ _docTypeKey lee document.documentType directamente                                             │
├─────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────┤
│ main.dart                   │ Eliminados NoteProvider y NoteRepository                                                       │
├─────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Eliminados                  │ 7 archivos de lib/features/notes/ (model, repo, 4 use cases, provider)                         │
├─────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Tests                       │ process_ocr_test.dart actualizado; 5 tests de notes eliminados                                 │
└─────────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────┘

Próximo paso: Desinstalar la app del celular y compilar. ¿Le damos?


## Post Simplificación

Lo que naturalmente pasa en todo proyecto así

Empezaste bien (POV, historias, Clean Arch, TDD) → iteraste rápido → el código real diverge del diseño original. Es normal y sano. El problema es que esa deuda se acumula silenciosamente.                                                                                                                                                                                                                                                                         
Después de la simplificación DB, sí vale la pena una auditoría

Ese momento es ideal porque:
- Acabás de borrar todo el feature de notes/ → hay imports muertos, providers fantasma, tests obsoletos
- La búsqueda cambió completamente (FTS → LIKE)
- Es un punto natural de "respiro" antes de nuevas features (Nueva nota, etc.)

Qué revisar concretamente

1. Código muerto — con herramientas:
   flutter analyze   # imports sin usar, variables muertas
   dart fix --apply  # fixes automáticos

2. Archivos sin uso — recorrer a mano:
- features/notes/ → borrado completo
- main.dart → providers que ya no existen
- core/ → servicios que quizás nadie llama
- Routes en el router → ¿todas tienen destino?

3. Tests:
- Borrar los de notes
- Verificar que los de documents/search cubren el nuevo esquema
- Agregar los que falten (updateNote, LIKE normalizado)

4. Coherencia de arquitectura:
   Con la DB simplificada, algunos use cases van a ser trivialmente delgados (solo llaman al repository). Vale preguntarse: ¿tiene sentido mantener esa capa para operaciones tan simples? No es obligatorio refactorizar, pero es  
   bueno ser consciente.

Lo que NO haría

- No hagas un refactor grande de arquitectura en ese momento — hay deuda pero la app funciona
- No reescribas lo que funciona bien solo por pureza
- No intentes recuperar el TDD al 100% — enfocate en los flujos críticos (scan, search, save)

Recomendación práctica

DB simplification
↓
flutter analyze + dart fix
↓
Borrar archivos muertos + limpiar main.dart
↓
Revisar tests: borrar obsoletos, agregar críticos
↓
Nueva nota (49_) → pergamino, etc.

Una tarde de limpieza después del refactor de DB te va a dejar el proyecto mucho más liviano para lo que viene. No es una reescritura, es sacar la basura.

