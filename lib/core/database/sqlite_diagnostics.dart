import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Diagnóstico de capacidades de SQLite en el dispositivo
class SQLiteDiagnostics {
  static Future<Map<String, dynamic>> runDiagnostics() async {
    final results = <String, dynamic>{};
    Database? db;

    try {
      // Crear base de datos temporal
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'diagnostics_temp.db');

      db = await openDatabase(path, version: 1);

      // 1. Versión de SQLite
      final versionResult = await db.rawQuery('SELECT sqlite_version() as version');
      results['sqlite_version'] = versionResult.first['version'];

      // 2. Lista de módulos disponibles (si está disponible pragma_module_list)
      try {
        final modules = await db.rawQuery('PRAGMA module_list');
        results['modules'] = modules.map((m) => m['name']).toList();
      } catch (e) {
        results['modules_error'] = e.toString();
      }

      // 3. Probar crear tabla FTS5
      try {
        await db.execute('''
          CREATE VIRTUAL TABLE test_fts5 USING fts5(content)
        ''');
        results['fts5_available'] = true;

        // Limpiar
        await db.execute('DROP TABLE test_fts5');
      } catch (e) {
        results['fts5_available'] = false;
        results['fts5_error'] = e.toString();
      }

      // 4. Probar crear tabla FTS4 (más antigua, más compatible)
      try {
        await db.execute('''
          CREATE VIRTUAL TABLE test_fts4 USING fts4(content)
        ''');
        results['fts4_available'] = true;

        // Limpiar
        await db.execute('DROP TABLE test_fts4');
      } catch (e) {
        results['fts4_available'] = false;
        results['fts4_error'] = e.toString();
      }

      // 5. Probar crear tabla FTS3 (la más antigua)
      try {
        await db.execute('''
          CREATE VIRTUAL TABLE test_fts3 USING fts3(content)
        ''');
        results['fts3_available'] = true;

        // Limpiar
        await db.execute('DROP TABLE test_fts3');
      } catch (e) {
        results['fts3_available'] = false;
        results['fts3_error'] = e.toString();
      }

      // 6. Compilación de opciones (PRAGMA compile_options)
      try {
        final compileOptions = await db.rawQuery('PRAGMA compile_options');
        results['compile_options'] = compileOptions.map((opt) => opt['compile_option']).toList();
      } catch (e) {
        results['compile_options_error'] = e.toString();
      }

    } catch (e) {
      results['general_error'] = e.toString();
    } finally {
      // Cerrar y eliminar base de datos temporal
      if (db != null) {
        await db.close();
        final dbPath = await getDatabasesPath();
        final path = join(dbPath, 'diagnostics_temp.db');
        await deleteDatabase(path);
      }
    }

    return results;
  }

  /// Imprime los resultados de forma legible
  static void printResults(Map<String, dynamic> results) {
    print('═══════════════════════════════════════════════════════════');
    print('SQLite DIAGNOSTICS');
    print('═══════════════════════════════════════════════════════════');

    print('\n📌 SQLite Version: ${results['sqlite_version'] ?? 'Unknown'}');

    print('\n📦 FTS Support:');
    print('  • FTS3: ${results['fts3_available'] == true ? '✅' : '❌'}');
    print('  • FTS4: ${results['fts4_available'] == true ? '✅' : '❌'}');
    print('  • FTS5: ${results['fts5_available'] == true ? '✅' : '❌'}');

    if (results['fts5_error'] != null) {
      print('\n⚠️  FTS5 Error:');
      print('  ${results['fts5_error']}');
    }

    if (results['modules'] != null) {
      print('\n🔧 Available Modules:');
      for (var module in results['modules']) {
        print('  • $module');
      }
    }

    if (results['compile_options'] != null) {
      print('\n⚙️  Compile Options (FTS related):');
      final ftsOptions = (results['compile_options'] as List)
          .where((opt) => opt.toString().contains('FTS'))
          .toList();

      if (ftsOptions.isEmpty) {
        print('  (No FTS-related compile options found)');
      } else {
        for (var opt in ftsOptions) {
          print('  • $opt');
        }
      }
    }

    if (results['general_error'] != null) {
      print('\n❌ General Error:');
      print('  ${results['general_error']}');
    }

    print('\n═══════════════════════════════════════════════════════════');
  }
}
