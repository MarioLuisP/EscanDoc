/home/claude/databas

# EscanDoc - Database Schema

**Fecha:** 17 de Enero 2026  
**Versión:** 1.0  
**Motor:** SQLite 3 con FTS5

---

## TABLAS PRINCIPALES

### 1. documents
Almacena documentos escaneados con metadata y OCR.

```sql
CREATE TABLE documents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  
  -- Metadata básica
  title TEXT NOT NULL,
  file_path TEXT NOT NULL,              -- Path al PDF en storage local
  thumbnail_path TEXT,                   -- Path al thumbnail (miniatura)
  
  -- OCR y clasificación
  ocr_text TEXT,                         -- Texto extraído por ML Kit (HU-005)
  doc_type TEXT,                         -- "factura", "recibo", "contrato", "otros" (HU-012)
  extracted_date DATE,                   -- Fecha de vencimiento extraída (HU-013)
  
  -- Organización
  category TEXT DEFAULT 'Otros',        -- Facturas, Recibos, Contratos, Médico, Personal, Otros (HU-011)
  
  -- Timestamps
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  
  -- Constraints
  CONSTRAINT valid_category CHECK (
    category IN ('Facturas', 'Recibos', 'Contratos', 'Médico', 'Personal', 'Otros')
  ),
  CONSTRAINT valid_doc_type CHECK (
    doc_type IS NULL OR doc_type IN ('factura', 'recibo', 'contrato', 'otros')
  )
);
```

---

### 2. notes
Notas vinculadas a documentos (o independientes en Fase 3).

```sql
CREATE TABLE notes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  
  -- Contenido
  title TEXT NOT NULL,
  content TEXT,                          -- Cuerpo de la nota (texto plano por ahora)
  
  -- Timestamps
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

---

### 3. document_notes (Relación many-to-many)
Vincula documentos con notas. Por ahora 1:1, pero preparado para Fase 3.

```sql
CREATE TABLE document_notes (
  document_id INTEGER NOT NULL,
  note_id INTEGER NOT NULL,
  
  -- Foreign keys con cascade delete
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE,
  FOREIGN KEY(note_id) REFERENCES notes(id) ON DELETE CASCADE,
  
  -- Clave primaria compuesta (evita duplicados)
  PRIMARY KEY(document_id, note_id)
);
```

---

### 4. due_dates (Fase 2 - Vencimientos)
**NO se usa en MVP, pero se define ahora para evitar migration compleja después.**

```sql
CREATE TABLE due_dates (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  
  -- Información del vencimiento
  title TEXT NOT NULL,
  due_date DATE NOT NULL,
  notification_days_before INTEGER DEFAULT 1,  -- Días antes de notificar (1, 3, 7)
  is_resolved BOOLEAN DEFAULT 0,               -- TRUE si ya se pagó/resolvió
  
  -- Timestamps
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  
  -- Constraints
  CONSTRAINT valid_notification CHECK (notification_days_before > 0)
);
```

---

### 5. document_due_dates (Relación many-to-many - Fase 2)
**NO se usa en MVP.**

```sql
CREATE TABLE document_due_dates (
  document_id INTEGER NOT NULL,
  due_date_id INTEGER NOT NULL,
  
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE,
  FOREIGN KEY(due_date_id) REFERENCES due_dates(id) ON DELETE CASCADE,
  
  PRIMARY KEY(document_id, due_date_id)
);
```

---

## ÍNDICES FULL-TEXT SEARCH (FTS5)

### 1. documents_fts
Búsqueda rápida en documentos (HU-006).

```sql
-- Tabla virtual FTS5
CREATE VIRTUAL TABLE documents_fts USING fts5(
  title,                                 -- Título del documento
  ocr_text,                              -- Texto extraído por OCR
  content=documents,                     -- Tabla origen
  content_rowid=id                       -- Mapeo con documents.id
);

-- Trigger: INSERT - Mantener FTS5 sincronizado
CREATE TRIGGER documents_ai AFTER INSERT ON documents BEGIN
  INSERT INTO documents_fts(rowid, title, ocr_text)
  VALUES (new.id, new.title, new.ocr_text);
END;

-- Trigger: UPDATE - Actualizar FTS5
CREATE TRIGGER documents_au AFTER UPDATE ON documents BEGIN
  UPDATE documents_fts 
  SET title = new.title, ocr_text = new.ocr_text
  WHERE rowid = new.id;
END;

-- Trigger: DELETE - Limpiar FTS5
CREATE TRIGGER documents_ad AFTER DELETE ON documents BEGIN
  DELETE FROM documents_fts WHERE rowid = old.id;
END;
```

---

### 2. notes_fts
Búsqueda rápida en notas (HU-006).

```sql
-- Tabla virtual FTS5
CREATE VIRTUAL TABLE notes_fts USING fts5(
  title,
  content,
  content=notes,
  content_rowid=id
);

-- Trigger: INSERT
CREATE TRIGGER notes_ai AFTER INSERT ON notes BEGIN
  INSERT INTO notes_fts(rowid, title, content)
  VALUES (new.id, new.title, new.content);
END;

-- Trigger: UPDATE
CREATE TRIGGER notes_au AFTER UPDATE ON notes BEGIN
  UPDATE notes_fts 
  SET title = new.title, content = new.content
  WHERE rowid = new.id;
END;

-- Trigger: DELETE
CREATE TRIGGER notes_ad AFTER DELETE ON notes BEGIN
  DELETE FROM notes_fts WHERE rowid = old.id;
END;
```

---

## ÍNDICES NORMALES (Performance)

```sql
-- Documentos: búsqueda por categoría (HU-011)
CREATE INDEX idx_documents_category ON documents(category);

-- Documentos: búsqueda por tipo (HU-012)
CREATE INDEX idx_documents_doc_type ON documents(doc_type);

-- Documentos: ordenamiento por fecha (HU-008)
CREATE INDEX idx_documents_created_at ON documents(created_at DESC);

-- Documentos: búsqueda por fecha de vencimiento (HU-013)
CREATE INDEX idx_documents_extracted_date ON documents(extracted_date);

-- Notas: foreign key optimization
CREATE INDEX idx_document_notes_document_id ON document_notes(document_id);
CREATE INDEX idx_document_notes_note_id ON document_notes(note_id);

-- Due dates (Fase 2): búsqueda por fecha y pendientes
CREATE INDEX idx_due_dates_due_date ON due_dates(due_date);
CREATE INDEX idx_due_dates_is_resolved ON due_dates(is_resolved);
```

---

## TRIGGER: updated_at automático

```sql
-- Documentos: actualizar updated_at automáticamente
CREATE TRIGGER documents_updated_at 
AFTER UPDATE ON documents
FOR EACH ROW
WHEN NEW.updated_at = OLD.updated_at  -- Solo si no se actualizó manualmente
BEGIN
  UPDATE documents SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Notas: actualizar updated_at automáticamente
CREATE TRIGGER notes_updated_at 
AFTER UPDATE ON notes
FOR EACH ROW
WHEN NEW.updated_at = OLD.updated_at
BEGIN
  UPDATE notes SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Due dates (Fase 2)
CREATE TRIGGER due_dates_updated_at 
AFTER UPDATE ON due_dates
FOR EACH ROW
WHEN NEW.updated_at = OLD.updated_at
BEGIN
  UPDATE due_dates SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;
```

---

## QUERIES COMUNES (Ejemplos)

### 1. Insertar documento (HU-004)
```sql
INSERT INTO documents (title, file_path, thumbnail_path, category)
VALUES (
  'Documento_2026-01-17_14-30',
  '/storage/documents/doc_123.pdf',
  '/storage/thumbnails/doc_123_thumb.jpg',
  'Otros'
);
```

---

### 2. Actualizar con OCR y clasificación (HU-005, HU-012)
```sql
UPDATE documents 
SET 
  ocr_text = 'EDESUR Factura de luz Vencimiento: 15/02/2026...',
  doc_type = 'factura',
  extracted_date = '2026-02-15'
WHERE id = 123;
```

---

### 3. Búsqueda full-text (HU-006)
```sql
-- Buscar "Edesur" en documentos
SELECT 
  d.id, 
  d.title, 
  d.thumbnail_path,
  d.created_at,
  snippet(documents_fts, 1, '<b>', '</b>', '...', 32) AS snippet
FROM documents d
JOIN documents_fts ON documents_fts.rowid = d.id
WHERE documents_fts MATCH 'Edesur'
ORDER BY rank
LIMIT 20;
```

---

### 4. Búsqueda global (docs + notas) (HU-006)
```sql
-- Búsqueda en documentos
SELECT 
  'document' AS type,
  d.id,
  d.title,
  snippet(documents_fts, 1, '<b>', '</b>', '...', 32) AS snippet
FROM documents d
JOIN documents_fts ON documents_fts.rowid = d.id
WHERE documents_fts MATCH ?

UNION ALL

-- Búsqueda en notas
SELECT 
  'note' AS type,
  n.id,
  n.title,
  snippet(notes_fts, 1, '<b>', '</b>', '...', 32) AS snippet
FROM notes n
JOIN notes_fts ON notes_fts.rowid = n.id
WHERE notes_fts MATCH ?

ORDER BY type, id DESC
LIMIT 50;
```

---

### 5. Listar documentos con notas (HU-008, HU-010)
```sql
SELECT 
  d.id,
  d.title,
  d.thumbnail_path,
  d.category,
  d.created_at,
  n.id AS note_id,
  n.title AS note_title,
  n.content AS note_content
FROM documents d
LEFT JOIN document_notes dn ON d.id = dn.document_id
LEFT JOIN notes n ON dn.note_id = n.id
ORDER BY d.created_at DESC;
```

---

### 6. Filtrar por categoría (HU-011)
```sql
SELECT id, title, thumbnail_path, created_at
FROM documents
WHERE category = 'Facturas'
ORDER BY created_at DESC;
```

---

### 7. Documentos por tipo auto-detectado (HU-012)
```sql
SELECT id, title, doc_type, created_at
FROM documents
WHERE doc_type = 'factura'
ORDER BY created_at DESC;
```

---

### 8. Documentos con fecha de vencimiento próxima (HU-013)
```sql
SELECT id, title, extracted_date
FROM documents
WHERE extracted_date IS NOT NULL
  AND extracted_date >= DATE('now')
  AND extracted_date <= DATE('now', '+7 days')
ORDER BY extracted_date ASC;
```

---

### 9. Eliminar documento (HU-015)
```sql
-- Cascade delete se encarga de document_notes automáticamente
DELETE FROM documents WHERE id = 123;
```

---

## DATOS DE PRUEBA (Seed para testing)

```sql
-- Documento 1: Factura Edesur
INSERT INTO documents (title, file_path, thumbnail_path, category, doc_type, ocr_text, extracted_date)
VALUES (
  'Factura Edesur Enero 2026',
  '/storage/documents/edesur_ene2026.pdf',
  '/storage/thumbnails/edesur_ene2026_thumb.jpg',
  'Facturas',
  'factura',
  'EDESUR SA
Factura de Energía Eléctrica
Período: Enero 2026
Vencimiento: 15/02/2026
Total a pagar: $12,500',
  '2026-02-15'
);

-- Documento 2: Recibo médico
INSERT INTO documents (title, file_path, thumbnail_path, category, doc_type, ocr_text)
VALUES (
  'Recibo Consulta Dr. García',
  '/storage/documents/recibo_garcia.pdf',
  '/storage/thumbnails/recibo_garcia_thumb.jpg',
  'Médico',
  'recibo',
  'RECIBO
Dr. Juan García
Consulta médica
Fecha: 10/01/2026
Importe: $5,000'
);

-- Nota para documento 1
INSERT INTO notes (title, content) VALUES (
  'Pagar antes del 15',
  'Recordar pagar antes del vencimiento para evitar recargo. Usar Mercado Pago.'
);

-- Vincular nota con documento
INSERT INTO document_notes (document_id, note_id) VALUES (1, 1);
```

---

## MIGRACIÓN FUTURA (v2 - Fase 2)

Cuando se implemente Fase 2, ya existen `due_dates` y `document_due_dates`.  
Solo faltará:

```sql
-- Agregar campos si es necesario (ejemplo)
ALTER TABLE due_dates ADD COLUMN recurrence_rule TEXT;
```

---

## TAMAÑO ESTIMADO

**Estimación conservadora:**

| Tabla | Registros | Tamaño aprox/registro | Total |
|-------|-----------|---------------------|-------|
| documents | 500 | ~2 KB (con OCR) | ~1 MB |
| notes | 300 | ~500 bytes | ~150 KB |
| documents_fts | 500 | ~1.5 KB | ~750 KB |
| notes_fts | 300 | ~400 bytes | ~120 KB |
| **TOTAL** | - | - | **~2 MB** |

Con 1000 documentos: **~4-5 MB**

---

## RESPALDO Y LIMPIEZA

### Respaldo (implementar en Pro)
```dart
// Copiar archivo .db a cloud storage
final dbPath = await getDatabasesPath();
final dbFile = File('$dbPath/escandoc.db');
// Subir a Firebase Storage
```

### Limpieza de huérfanos (maintenance)
```sql
-- Eliminar notas sin documentos vinculados (solo si se permite notas independientes)
DELETE FROM notes 
WHERE id NOT IN (SELECT note_id FROM document_notes);

-- Eliminar entradas FTS huérfanas (no debería pasar por triggers, pero por si acaso)
DELETE FROM documents_fts 
WHERE rowid NOT IN (SELECT id FROM documents);
```


**Última actualización:** 17 Enero 2026