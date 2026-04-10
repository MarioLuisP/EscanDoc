import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:escandoc/core/utils/text_normalizer.dart';

/// Singleton para gestionar la base de datos SQLite local
/// Schema: tabla única documents con expiry_date incorporado
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
      version: 3,
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
        expiry_date     TEXT,
        created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
        title_search    TEXT,
        note_search     TEXT
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

    // =========================================================================
    // ÍNDICES: Performance
    // =========================================================================
    await db.execute(
        'CREATE INDEX idx_documents_created_at ON documents(created_at DESC)');
    await db.execute(
        'CREATE INDEX idx_documents_extracted_date ON documents(extracted_date)');
    await db.execute(
        'CREATE INDEX idx_documents_expiry_date ON documents(expiry_date)');
  }

  /// Migraciones incrementales por versión
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE documents ADD COLUMN title_search TEXT');
      await db.execute(
          'ALTER TABLE documents ADD COLUMN note_search TEXT');

      // Poblar shadow columns para documentos existentes
      final rows = await db.query('documents', columns: ['id', 'title', 'note_content']);
      for (final row in rows) {
        final id = row['id'] as int;
        final title = row['title'] as String? ?? '';
        final note = row['note_content'] as String?;
        await db.update(
          'documents',
          {
            'title_search': TextNormalizer.normalize(title),
            'note_search': note != null ? TextNormalizer.normalize(note) : null,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
    if (oldVersion < 3) {
      // Agregar expiry_date a documents
      await db.execute(
          'ALTER TABLE documents ADD COLUMN expiry_date TEXT');
      await db.execute(
          'CREATE INDEX idx_documents_expiry_date ON documents(expiry_date)');

      // Eliminar tablas de Fase 2 que quedaron sin uso
      await db.execute('DROP TABLE IF EXISTS document_due_dates');
      await db.execute('DROP TABLE IF EXISTS due_dates');
    }
  }

  /// Cierra la base de datos
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  /// Solo para tests: resetea la instancia cacheada de la BD
  static void resetForTesting() {
    _database = null;
  }
}
