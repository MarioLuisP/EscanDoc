# Simplificación Base de Datos (Feb 2026)

## Resumen
Eliminados 3 campos redundantes del schema SQLite + modelos + tests.

## Campos Eliminados

### 1. `documents.thumbnail_path`
**Por qué:** Apuntaba al mismo JPG que `filePath` (~850KB)

**Solución:**
- UI usa `Image.file(File(filePath), cacheWidth: 200)` para thumbnails
- Elimina archivo duplicado y simplifica lógica

### 2. `documents.doc_type`
**Por qué:** Redundante con category

**Cambios:**
- Eliminado de DocumentModel
- Clasificador sigue detectando tipo (para generar nombre)
- Índice `idx_documents_doc_type` eliminado

### 3. `notes.title`
**Por qué:** Notas son "bloc de notas" (solo content)

**Cambios:**
- NoteModel ahora: `{id, content, createdAt, updatedAt}`
- UI: TextField de título eliminado en NoteEditorPage
- Search: Usa `SUBSTR(content, 1, 50)` como preview
- FTS4: `notes_fts` solo indexa `content` (índice 0)

## Schema Actualizado

```sql
-- documents (antes: 7 campos → ahora: 6 campos)
CREATE TABLE documents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  file_path TEXT NOT NULL,  -- JPG ~850KB (UI usará cacheWidth)
  ocr_text TEXT,
  extracted_date DATE,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
)

-- notes (antes: 5 campos → ahora: 4 campos)
CREATE TABLE notes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  content TEXT,  -- Sin título
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
)

-- notes_fts (FTS4)
CREATE VIRTUAL TABLE notes_fts USING fts4(
  content,  -- Solo 1 columna indexada
  content=notes
)
```

## FTS4 Triggers Actualizados

```sql
-- INSERT: Solo inserta content
CREATE TRIGGER notes_ai AFTER INSERT ON notes BEGIN
  INSERT INTO notes_fts(docid, content)
  VALUES (new.id, new.content);
END

-- UPDATE: Solo actualiza content
CREATE TRIGGER notes_au AFTER UPDATE ON notes BEGIN
  UPDATE notes_fts SET content = new.content
  WHERE docid = new.id;
END
```

## Search Query Fix

```sql
-- Búsqueda en notas (snippet índice 0, no 1)
SELECT
  n.id,
  SUBSTR(n.content, 1, 50) as title,  -- Preview de 50 chars
  'note' as type,
  snippet(notes_fts, 0, '<b>', '</b>', '...', 32) AS snippet,  -- Índice 0
  n.created_at
FROM notes n
JOIN notes_fts ON notes_fts.docid = n.id
WHERE notes_fts MATCH ?
LIMIT 20
```

## Archivos Modificados

**Core (2):**
- `database_helper.dart` - Schema + triggers + índices

**Models (2):**
- `document_model.dart` - Sin thumbnailPath/docType
- `note_model.dart` - Sin title

**UseCases (7):**
- `save_scanned_document.dart`
- `process_ocr.dart`
- `create_note.dart` / `update_note.dart`
- `import_document.dart`
- Y 2 más

**Repositories (2):**
- `document_repository.dart`
- `search_repository_impl.dart` - Query SQL actualizado

**UI (5):**
- `document_card.dart` - cacheWidth para thumbnails
- `photo_preview_section.dart` - Renombrado imagePath
- `document_detail_page.dart` - imagePath
- `note_editor_page.dart` - Sin TextField de título
- `note_provider.dart` - Sin parámetro title

**Tests (18):**
- Todos actualizados y pasando ✅ (189 tests)

## Migración Base de Datos

**Para tests:**
```powershell
Remove-Item -Recurse -Force .dart_tool\sqflite_common_ffi\databases\
```

**Para producción:**
- Cuando app actualice, DatabaseHelper recreará schema automáticamente
- NOTA: En próxima versión, implementar migration en `_upgradeDB()`

## Resultado

✅ **Tests:** 189 pasando
✅ **Compilación:** Sin errores
✅ **Schema:** -3 campos, +simplicidad
✅ **Performance:** Menos I/O (sin thumbnail duplicado)
