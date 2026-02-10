import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Singleton para gestionar la base de datos SQLite local
/// Implementa schema completo con FTS4 para búsqueda full-text
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('escandoc.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  /// Crea todas las tablas, índices y triggers
  Future<void> _createDB(Database db, int version) async {
    // =========================================================================
    // TABLA: documents
    // =========================================================================
    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        -- Metadata básica
        title TEXT NOT NULL,
        file_path TEXT NOT NULL,

        -- OCR
        ocr_text TEXT,
        extracted_date DATE,

        -- Timestamps
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // =========================================================================
    // TABLA: notes
    // =========================================================================
    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        -- Contenido (bloc de notas, sin título)
        content TEXT,

        -- Timestamps
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // =========================================================================
    // TABLA: document_notes (Relación many-to-many)
    // =========================================================================
    await db.execute('''
      CREATE TABLE document_notes (
        document_id INTEGER NOT NULL,
        note_id INTEGER NOT NULL,

        FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE,
        FOREIGN KEY(note_id) REFERENCES notes(id) ON DELETE CASCADE,

        PRIMARY KEY(document_id, note_id)
      )
    ''');

    // =========================================================================
    // TABLA: due_dates (Fase 2 - Preparada para futuro)
    // =========================================================================
    await db.execute('''
      CREATE TABLE due_dates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        title TEXT NOT NULL,
        due_date DATE NOT NULL,
        notification_days_before INTEGER DEFAULT 1,
        is_resolved BOOLEAN DEFAULT 0,

        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,

        CONSTRAINT valid_notification CHECK (notification_days_before > 0)
      )
    ''');

    // =========================================================================
    // TABLA: document_due_dates (Fase 2 - Preparada para futuro)
    // =========================================================================
    await db.execute('''
      CREATE TABLE document_due_dates (
        document_id INTEGER NOT NULL,
        due_date_id INTEGER NOT NULL,

        FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE,
        FOREIGN KEY(due_date_id) REFERENCES due_dates(id) ON DELETE CASCADE,

        PRIMARY KEY(document_id, due_date_id)
      )
    ''');

    // =========================================================================
    // FTS4: documents_fts
    // =========================================================================
    await db.execute('''
      CREATE VIRTUAL TABLE documents_fts USING fts4(
        title,
        ocr_text,
        content=documents
      )
    ''');

    // =========================================================================
    // FTS4: notes_fts
    // =========================================================================
    await db.execute('''
      CREATE VIRTUAL TABLE notes_fts USING fts4(
        content,
        content=notes
      )
    ''');

    // =========================================================================
    // TRIGGERS: FTS4 para documents
    // =========================================================================
    await db.execute('''
      CREATE TRIGGER documents_ai AFTER INSERT ON documents BEGIN
        INSERT INTO documents_fts(docid, title, ocr_text)
        VALUES (new.id, new.title, new.ocr_text);
      END
    ''');

    // DESHABILITADO: Bug conocido de FTS + UPDATE triggers en SQLite
    // La búsqueda FTS funciona con el trigger INSERT, solo no se actualiza en cambios
    // await db.execute('''
    //   CREATE TRIGGER documents_au AFTER UPDATE ON documents BEGIN
    //     DELETE FROM documents_fts WHERE docid = old.id;
    //     INSERT INTO documents_fts(docid, title, ocr_text)
    //     VALUES (new.id, new.title, new.ocr_text);
    //   END
    // ''');

    await db.execute('''
      CREATE TRIGGER documents_ad AFTER DELETE ON documents BEGIN
        DELETE FROM documents_fts WHERE docid = old.id;
      END
    ''');

    // =========================================================================
    // TRIGGERS: FTS4 para notes
    // =========================================================================
    await db.execute('''
      CREATE TRIGGER notes_ai AFTER INSERT ON notes BEGIN
        INSERT INTO notes_fts(docid, content)
        VALUES (new.id, new.content);
      END
    ''');

    await db.execute('''
      CREATE TRIGGER notes_au AFTER UPDATE ON notes BEGIN
        UPDATE notes_fts
        SET content = new.content
        WHERE docid = new.id;
      END
    ''');

    await db.execute('''
      CREATE TRIGGER notes_ad AFTER DELETE ON notes BEGIN
        DELETE FROM notes_fts WHERE docid = old.id;
      END
    ''');

    // =========================================================================
    // TRIGGERS: updated_at automático
    // =========================================================================
    await db.execute('''
      CREATE TRIGGER documents_updated_at
      AFTER UPDATE ON documents
      FOR EACH ROW
      WHEN NEW.updated_at = OLD.updated_at
      BEGIN
        UPDATE documents SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
      END
    ''');

    await db.execute('''
      CREATE TRIGGER notes_updated_at
      AFTER UPDATE ON notes
      FOR EACH ROW
      WHEN NEW.updated_at = OLD.updated_at
      BEGIN
        UPDATE notes SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
      END
    ''');

    await db.execute('''
      CREATE TRIGGER due_dates_updated_at
      AFTER UPDATE ON due_dates
      FOR EACH ROW
      WHEN NEW.updated_at = OLD.updated_at
      BEGIN
        UPDATE due_dates SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
      END
    ''');

    // =========================================================================
    // ÍNDICES: Performance
    // =========================================================================
    await db.execute(
        'CREATE INDEX idx_documents_created_at ON documents(created_at DESC)');
    await db.execute(
        'CREATE INDEX idx_documents_extracted_date ON documents(extracted_date)');

    // Índices para foreign keys
    await db.execute(
        'CREATE INDEX idx_document_notes_document_id ON document_notes(document_id)');
    await db.execute(
        'CREATE INDEX idx_document_notes_note_id ON document_notes(note_id)');

    // Índices para due_dates (Fase 2)
    await db.execute(
        'CREATE INDEX idx_due_dates_due_date ON due_dates(due_date)');
    await db.execute(
        'CREATE INDEX idx_due_dates_is_resolved ON due_dates(is_resolved)');
  }

  /// Migraciones futuras
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // TODO: Implementar migrations cuando sea necesario
  }

  /// Cierra la base de datos
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
