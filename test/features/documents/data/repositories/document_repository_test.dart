import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:escandoc/core/database/database_helper.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';

/// Tests de integración para DocumentRepository
/// Usan sqflite_common_ffi para ejecutar en desktop
void main() {
  late DocumentRepository repository;

  // Inicializar FFI para tests en desktop
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Borrar DB existente (puede tener schema viejo) y resetear singleton
    final dbPath = await databaseFactory.getDatabasesPath();
    final file = File('$dbPath/escandoc.db');
    if (file.existsSync()) await file.delete();
    DatabaseHelper.resetForTesting();
  });

  setUp(() async {
    // Crear repository con DatabaseHelper por defecto
    repository = DocumentRepository();

    // Limpiar tabla documents antes de cada test
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;
    await db.delete('documents');
  });

  tearDown(() async {
    // Limpiar tabla documents después de cada test
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;
    await db.delete('documents');
  });

  group('DocumentRepository Integration Tests', () {
    final testDocument = DocumentModel(
      title: 'factura_20_Ene_2026',
      filePath: '/test/documents/factura_20_Ene_2026.jpg',
      ocrText: 'FACTURA Total: \$1000',
      createdAt: DateTime(2026, 1, 20, 10, 15),
    );

    test('Debe insertar documento en BD correctamente', () async {
      // Act
      final insertedId = await repository.insertDocument(testDocument);

      // Assert
      expect(insertedId, greaterThan(0));

      // Verificar que se insertó correctamente
      final retrieved = await repository.getDocumentById(insertedId);
      expect(retrieved, isNotNull);
      expect(retrieved!.title, testDocument.title);
      expect(retrieved.filePath, testDocument.filePath);
    });

    test('Debe recuperar documento por ID', () async {
      // Arrange
      final insertedId = await repository.insertDocument(testDocument);

      // Act
      final result = await repository.getDocumentById(insertedId);

      // Assert
      expect(result, isNotNull);
      expect(result!.id, insertedId);
      expect(result.title, testDocument.title);
      expect(result.filePath, testDocument.filePath);
      expect(result.ocrText, testDocument.ocrText);
    });

    test('Debe recuperar lista de documentos ordenada', () async {
      // Arrange - Insertar múltiples documentos en orden no cronológico
      final doc1 = testDocument.copyWith(
        title: 'documento_17_Ene_2026',
        createdAt: DateTime(2026, 1, 17, 14, 30),
      );
      final doc2 = testDocument.copyWith(
        title: 'documento_20_Ene_2026',
        createdAt: DateTime(2026, 1, 20, 10, 15),
      );
      final doc3 = testDocument.copyWith(
        title: 'documento_15_Ene_2026',
        createdAt: DateTime(2026, 1, 15, 9, 0),
      );

      await repository.insertDocument(doc1);
      await repository.insertDocument(doc2);
      await repository.insertDocument(doc3);

      // Act
      final result = await repository.getAllDocuments();

      // Assert
      expect(result.length, 3);

      // Verificar orden descendente (más reciente primero)
      expect(result[0].title, 'documento_20_Ene_2026'); // 20 Ene
      expect(result[1].title, 'documento_17_Ene_2026'); // 17 Ene
      expect(result[2].title, 'documento_15_Ene_2026'); // 15 Ene
    });

    test('Debe actualizar documento existente', () async {
      // Arrange
      final insertedId = await repository.insertDocument(testDocument);
      final documentToUpdate = testDocument.copyWith(
        id: insertedId,
        title: 'factura_actualizada_20_Ene_2026',
        ocrText: 'FACTURA ACTUALIZADA Total: \$2000',
      );

      // Act
      final updatedRows = await repository.updateDocument(documentToUpdate);

      // Assert
      expect(updatedRows, 1);

      // Verificar que se actualizó correctamente
      final retrieved = await repository.getDocumentById(insertedId);
      expect(retrieved!.title, 'factura_actualizada_20_Ene_2026');
      expect(retrieved.ocrText, 'FACTURA ACTUALIZADA Total: \$2000');
    });

    test('Debe eliminar documento de BD', () async {
      // Arrange
      final insertedId = await repository.insertDocument(testDocument);

      // Verificar que existe
      final beforeDelete = await repository.getDocumentById(insertedId);
      expect(beforeDelete, isNotNull);

      // Act
      // Nota: Este test no puede probar la eliminación de archivos reales
      // porque los paths son de prueba. Solo verifica la eliminación de BD.
      await repository.deleteDocument(insertedId);

      // Assert
      // El resultado puede ser false porque el archivo no existe (esperado en test)
      // Lo importante es verificar que se eliminó de BD
      final afterDelete = await repository.getDocumentById(insertedId);
      expect(afterDelete, isNull);
    });

    test('Debe retornar null si documento no existe', () async {
      // Act
      final result = await repository.getDocumentById(999);

      // Assert
      expect(result, isNull);
    });
  });
}
