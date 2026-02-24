import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Singleton para gestionar la base de datos SQLite local
/// Schema simplificado: tabla única documents + due_dates (Fase 2)
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
    // TABLA: documents (tabla única — incluye nota y tipo)
    // =========================================================================
    await db.execute('''
      CREATE TABLE documents (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        title           TEXT NOT NULL,
        file_path       TEXT NOT NULL,
        document_type   TEXT,
        note_content    TEXT,
        ocr_text        TEXT,
        extracted_date  DATE,
        created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP
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
