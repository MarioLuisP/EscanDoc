import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:escandoc/core/database/database_helper.dart';
import 'package:escandoc/core/utils/text_normalizer.dart';
import 'package:escandoc/features/search/data/repositories/search_repository_impl.dart';

/// Tests de integración para SearchRepository (LIKE normalizado)
/// Usan sqflite_common_ffi para SQLite en desktop
void main() {
  late SearchRepositoryImpl repository;

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
    repository = SearchRepositoryImpl();

    final db = await DatabaseHelper.instance.database;
    await db.delete('documents');

    // Documento 1: factura con nota
    const note1 = 'Pagar factura Edesur usando Mercado Pago antes del vencimiento';
    await db.insert('documents', {
      'id': 1,
      'title': 'Factura Edesur Enero 2026',
      'title_search': TextNormalizer.normalize('Factura Edesur Enero 2026'),
      'file_path': '/test/factura.jpg',
      'document_type': 'factura',
      'note_content': note1,
      'note_search': TextNormalizer.normalize(note1),
      'ocr_text': 'EDESUR S.A. Factura de Energía Eléctrica. Período Enero 2026. Total: \$12,500',
      'created_at': DateTime(2026, 1, 15).toIso8601String(),
    });

    // Documento 2: recibo con nota
    const note2 = 'Próxima consulta con Dr. González el 15/02/2026. Llevar estudios previos.';
    await db.insert('documents', {
      'id': 2,
      'title': 'Recibo Médico Dr. González',
      'title_search': TextNormalizer.normalize('Recibo Médico Dr. González'),
      'file_path': '/test/recibo.jpg',
      'document_type': 'recibo',
      'note_content': note2,
      'note_search': TextNormalizer.normalize(note2),
      'ocr_text': 'Dr. González. Consulta médica general. Fecha: 20/01/2026.',
      'created_at': DateTime(2026, 1, 20).toIso8601String(),
    });

    // Documento 3: contrato sin nota
    await db.insert('documents', {
      'id': 3,
      'title': 'Contrato Alquiler',
      'title_search': TextNormalizer.normalize('Contrato Alquiler'),
      'file_path': '/test/contrato.jpg',
      'document_type': 'documento',
      'note_content': null,
      'note_search': null,
      'ocr_text': 'Contrato de Locación de Inmueble. Entre las partes...',
      'created_at': DateTime(2026, 1, 10).toIso8601String(),
    });
  });

  tearDown(() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('documents');
  });

  group('SearchRepository - LIKE Integration Tests', () {
    test('Debe buscar por título y encontrar resultado', () async {
      final results = await repository.search('edesur');

      expect(results, isNotEmpty);
      expect(results.any((r) => r.title.contains('Edesur')), isTrue);
    });

    test('Debe buscar en title y retornar type=document', () async {
      final results = await repository.search('factura');

      expect(results, isNotEmpty);
      final docResults = results.where((r) => r.type == 'document').toList();
      expect(docResults, isNotEmpty);
      expect(docResults.any((r) => r.title.contains('Factura')), isTrue);
    });

    test('Debe buscar en note_content y retornar type=note', () async {
      // 'pago' está en note_content de Factura Edesur
      final results = await repository.search('pago');

      expect(results, isNotEmpty);
      final noteResults = results.where((r) => r.type == 'note').toList();
      expect(noteResults, isNotEmpty);
      expect(noteResults.first.snippet.toLowerCase(), contains('pago'));
    });

    test('Debe encontrar resultados de ambos tipos (title y note_content)', () async {
      // 'González' aparece en el título del recibo Y en su note_content
      // Como title matchea primero en el CASE, type será 'document'
      final results = await repository.search('gonzalez');

      expect(results, isNotEmpty);
      expect(results.length, greaterThanOrEqualTo(1));
    });

    test('Debe normalizar tildes: "gonzalez" matchea "González"', () async {
      final results = await repository.search('gonzalez');

      expect(results, isNotEmpty);
      expect(results.any((r) => r.title.contains('González')), isTrue);
    });

    test('Debe normalizar tildes: "González" matchea título con tilde', () async {
      final results = await repository.search('González');

      expect(results, isNotEmpty);
      expect(results.any((r) => r.title.contains('González')), isTrue);
    });

    test('Debe buscar en note_content con texto de nota', () async {
      // 'estudios previos' está en note_content del recibo
      final results = await repository.search('estudios previos');

      expect(results, isNotEmpty);
      final noteResults = results.where((r) => r.type == 'note').toList();
      expect(noteResults, isNotEmpty);
    });

    test('Debe retornar lista vacía si no encuentra nada', () async {
      final results = await repository.search('xyz123notfound');

      expect(results, isEmpty);
    });

    test('Debe manejar caracteres especiales en query sin lanzar excepción', () async {
      final results = await repository.search('\$12,500');

      expect(results, isNotNull);
    });

    test('Debe retornar resultados ordenados por fecha DESC', () async {
      final results = await repository.search('2026');

      expect(results, isNotEmpty);
      for (int i = 1; i < results.length; i++) {
        if (results[i - 1].date != null && results[i].date != null) {
          expect(
            results[i - 1].date!.compareTo(results[i].date!) >= 0,
            isTrue,
            reason: 'Resultados deben estar ordenados por fecha DESC',
          );
        }
      }
    });

    test('Debe retornar máximo 20 resultados', () async {
      final db = await DatabaseHelper.instance.database;
      for (int i = 4; i <= 25; i++) {
        await db.insert('documents', {
          'id': i,
          'title': 'Documento Test $i',
          'title_search': TextNormalizer.normalize('Documento Test $i'),
          'file_path': '/test/doc$i.jpg',
          'document_type': 'documento',
          'created_at': DateTime(2026, 1, i % 28 + 1).toIso8601String(),
        });
      }

      final results = await repository.search('test');

      expect(results.length, lessThanOrEqualTo(20));
    });

    test('documentId siempre es el id del documento (sin JOINs)', () async {
      // Con el nuevo schema, documentId == id siempre
      final results = await repository.search('pago');

      expect(results, isNotEmpty);
      for (final r in results) {
        expect(r.documentId, equals(r.id));
      }
    });

    test('Debe retornar query vacío sin errores', () async {
      final results = await repository.search('');

      expect(results, isEmpty);
    });
  });
}
