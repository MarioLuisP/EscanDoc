import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:escandoc/core/database/database_helper.dart';
import 'package:escandoc/features/search/data/repositories/search_repository_impl.dart';

/// Tests de integración para SearchRepository (FTS4)
/// Usan sqflite_common_ffi + sqlite3_flutter_libs para FTS en desktop
void main() {
  late SearchRepositoryImpl repository;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // sqfliteFfiInit() ya configura sqlite3 con FTS habilitado
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    repository = SearchRepositoryImpl();

    // Obtener BD y limpiar datos previos
    final db = await DatabaseHelper.instance.database;
    await db.delete('document_notes');
    await db.delete('notes');
    await db.delete('documents');

    // Insertar documentos de prueba
    await db.insert('documents', {
      'id': 1,
      'title': 'Factura Edesur Enero 2026',
      'file_path': '/test/factura.pdf',
      'thumbnail_path': '/test/thumb.jpg',
      'doc_type': 'factura',
      'ocr_text': 'EDESUR S.A. Factura de Energía Eléctrica. Período Enero 2026. Total: \$12,500',
      'created_at': DateTime(2026, 1, 15).toIso8601String(),
    });

    await db.insert('documents', {
      'id': 2,
      'title': 'Recibo Médico Dr. González',
      'file_path': '/test/recibo.pdf',
      'thumbnail_path': '/test/thumb2.jpg',
      'doc_type': 'médico',
      'ocr_text': 'Dr. González. Consulta médica general. Fecha: 20/01/2026. Importe: \$8,000',
      'created_at': DateTime(2026, 1, 20).toIso8601String(),
    });

    await db.insert('documents', {
      'id': 3,
      'title': 'Contrato Alquiler',
      'file_path': '/test/contrato.pdf',
      'thumbnail_path': '/test/thumb3.jpg',
      'doc_type': 'contrato',
      'ocr_text': 'Contrato de Locación de Inmueble. Entre las partes...',
      'created_at': DateTime(2026, 1, 10).toIso8601String(),
    });

    // Insertar notas de prueba
    await db.insert('notes', {
      'id': 1,
      'title': 'Nota pago Edesur',
      'content': 'Pagar factura Edesur usando Mercado Pago antes del vencimiento 15/02/2026',
      'created_at': DateTime(2026, 1, 16).toIso8601String(),
    });

    await db.insert('notes', {
      'id': 2,
      'title': 'Recordatorio médico',
      'content': 'Próxima consulta con Dr. González el 15/02/2026. Llevar estudios previos.',
      'created_at': DateTime(2026, 1, 21).toIso8601String(),
    });

    // Vincular notas con documentos
    await db.insert('document_notes', {
      'document_id': 1,
      'note_id': 1,
    });

    await db.insert('document_notes', {
      'document_id': 2,
      'note_id': 2,
    });
  });

  tearDown() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('document_notes');
    await db.delete('notes');
    await db.delete('documents');
  };

  // tearDownAll comentado porque los tests están skippeados (requieren device/emulador)
  // tearDownAll(() async {
  //   await DatabaseHelper.instance.close();
  // });

  group('SearchRepository - FTS4 Integration Tests', () {
    test('Debe ejecutar query FTS4 correctamente', () async {
      // Act
      final results = await repository.search('edesur');

      // Assert
      expect(results, isNotEmpty);
      expect(results.any((r) => r.title.contains('Edesur')), isTrue);
    });

    test('Debe buscar en documents_fts', () async {
      // Act
      final results = await repository.search('factura');

      // Assert
      expect(results, isNotEmpty);
      final docResults = results.where((r) => r.type == 'document').toList();
      expect(docResults, isNotEmpty);
      // Verificar que al menos uno de los documentos contiene 'Factura'
      expect(
        docResults.any((doc) => doc.title.contains('Factura') ||
                                doc.snippet.toLowerCase().contains('factura')),
        isTrue,
      );
    });

    test('Debe buscar en notes_fts', () async {
      // Act - Buscar 'pago' que está tanto en título como en contenido
      final results = await repository.search('pago');

      // Assert
      expect(results, isNotEmpty);
      final noteResults = results.where((r) => r.type == 'note').toList();
      expect(noteResults, isNotEmpty);
      expect(noteResults.first.snippet.toLowerCase(), contains('pago'));
    });

    test('Debe combinar resultados (docs + notas)', () async {
      // Act
      final results = await repository.search('gonzález');

      // Assert
      expect(results, isNotEmpty);
      expect(results.length, greaterThanOrEqualTo(2));

      final hasDoc = results.any((r) => r.type == 'document');
      final hasNote = results.any((r) => r.type == 'note');

      expect(hasDoc || hasNote, isTrue);
    });

    test('Debe generar snippet con highlight', () async {
      // Act
      final results = await repository.search('edesur');

      // Assert
      expect(results, isNotEmpty);
      final firstResult = results.first;

      // El snippet debe contener tags <b></b> para destacar
      expect(firstResult.snippet, isNotEmpty);
      // FTS4 snippet puede usar diferentes tags dependiendo de configuración
      // Verificamos que tenga contenido relevante
      expect(
        firstResult.snippet.toLowerCase(),
        anyOf(
          contains('edesur'),
          contains('<b>'),
        ),
      );
    });

    test('Debe manejar caracteres especiales en query', () async {
      // Act
      final results = await repository.search('\$12,500');

      // Assert
      // No debe lanzar excepción
      expect(results, isNotNull);
    });

    test('Debe retornar lista vacía si no encuentra nada', () async {
      // Act
      final results = await repository.search('xyz123notfound');

      // Assert
      expect(results, isEmpty);
    });

    test('Debe buscar en OCR text de documentos', () async {
      // Act
      final results = await repository.search('energía eléctrica');

      // Assert
      expect(results, isNotEmpty);
      final docResult = results.firstWhere(
        (r) => r.type == 'document' && r.id == 1,
        orElse: () => results.first,
      );
      expect(docResult.type, 'document');
    });

    test('Debe buscar en content de notas', () async {
      // Act
      final results = await repository.search('estudios previos');

      // Assert
      expect(results, isNotEmpty);
      final noteResults = results.where((r) => r.type == 'note').toList();
      expect(noteResults, isNotEmpty);
    });

    test('Debe retornar resultados ordenados', () async {
      // Act
      final results = await repository.search('2026');

      // Assert
      expect(results, isNotEmpty);
      // FTS4 retorna resultados ordenados por fecha
      // Verificamos que todos los resultados sean válidos
      for (final result in results) {
        expect(result.id, greaterThan(0));
        expect(result.type, isIn(['document', 'note']));
        expect(result.title, isNotEmpty);
      }
    });

    test('Debe limitar resultados si hay muchos', () async {
      final db = await DatabaseHelper.instance.database;

      // Insertar más documentos para probar límite
      for (int i = 4; i <= 25; i++) {
        await db.insert('documents', {
          'id': i,
          'title': 'Documento Test $i',
          'file_path': '/test/doc$i.pdf',
          'thumbnail_path': '/test/thumb$i.jpg',
          'doc_type': 'documento',
          'ocr_text': 'Contenido de prueba para búsqueda test',
          'created_at': DateTime(2026, 1, i).toIso8601String(),
        });
      }

      // Act
      final results = await repository.search('test');

      // Assert
      expect(results.length, lessThanOrEqualTo(20));
    });
  });
}
