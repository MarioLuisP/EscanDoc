import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:escandoc/features/backup/data/repositories/backup_repository_impl.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';

void main() {
  late Directory tempDir;
  late Directory outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_test_');
    outputDir = await Directory.systemTemp.createTemp('backup_out_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
    if (await outputDir.exists()) await outputDir.delete(recursive: true);
  });

  BackupRepositoryImpl makeRepo() => BackupRepositoryImpl(
        getOutputDir: () async => tempDir.path,
      );

  group('createBackup', () {
    test('crea un ZIP con meta.json, documents.json e images/', () async {
      final imageFile = File('${tempDir.path}/factura.jpg');
      await imageFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);

      final doc = DocumentModel(
        title: 'Factura Luz',
        filePath: imageFile.path,
        documentType: 'factura',
        createdAt: DateTime(2026, 5, 3),
      );

      final repo = makeRepo();
      final zipFile = await repo.createBackup([doc]);

      expect(zipFile.existsSync(), isTrue);

      final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
      final names = archive.map((f) => f.name).toList();
      expect(names, contains('meta.json'));
      expect(names, contains('documents.json'));
      expect(names.any((n) => n.startsWith('images/')), isTrue);
    });

    test('meta.json tiene schema_version 3 y count correcto', () async {
      final imageFile = File('${tempDir.path}/doc.jpg');
      await imageFile.writeAsBytes([0xFF, 0xD8, 0xFF]);

      final doc = DocumentModel(
        title: 'Doc',
        filePath: imageFile.path,
        createdAt: DateTime(2026, 5, 3),
      );

      final repo = makeRepo();
      final zipFile = await repo.createBackup([doc]);
      final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());

      final metaFile = archive.firstWhere((f) => f.name == 'meta.json');
      final meta = jsonDecode(utf8.decode(metaFile.content as List<int>)) as Map<String, dynamic>;

      expect(meta['schema_version'], 3);
      expect(meta['count'], 1);
    });

    test('documents.json contiene file_path relativo (solo nombre de archivo)', () async {
      final imageFile = File('${tempDir.path}/recibo_gas.jpg');
      await imageFile.writeAsBytes([0xFF, 0xD8, 0xFF]);

      final doc = DocumentModel(
        title: 'Recibo Gas',
        filePath: imageFile.path,
        createdAt: DateTime(2026, 5, 3),
      );

      final repo = makeRepo();
      final zipFile = await repo.createBackup([doc]);
      final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());

      final docsFile = archive.firstWhere((f) => f.name == 'documents.json');
      final docsList = jsonDecode(utf8.decode(docsFile.content as List<int>)) as List<dynamic>;

      expect(docsList.length, 1);
      final filePath = (docsList[0] as Map<String, dynamic>)['file_path'] as String;
      expect(filePath, 'recibo_gas.jpg');
      expect(filePath.contains('/'), isFalse);
    });

    test('documents.json no incluye id', () async {
      final imageFile = File('${tempDir.path}/doc.jpg');
      await imageFile.writeAsBytes([0xFF, 0xD8, 0xFF]);

      final doc = DocumentModel(
        id: 99,
        title: 'Doc',
        filePath: imageFile.path,
        createdAt: DateTime(2026, 5, 3),
      );

      final repo = makeRepo();
      final zipFile = await repo.createBackup([doc]);
      final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());

      final docsFile = archive.firstWhere((f) => f.name == 'documents.json');
      final docsList = jsonDecode(utf8.decode(docsFile.content as List<int>)) as List<dynamic>;
      expect((docsList[0] as Map<String, dynamic>).containsKey('id'), isFalse);
    });

    test('no incluye imagen si el archivo no existe', () async {
      final doc = DocumentModel(
        title: 'Doc',
        filePath: '${tempDir.path}/inexistente.jpg',
        createdAt: DateTime(2026, 5, 3),
      );

      final repo = makeRepo();
      final zipFile = await repo.createBackup([doc]);
      final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());

      final names = archive.map((f) => f.name).toList();
      expect(names.any((n) => n.startsWith('images/')), isFalse);
    });

    test('backup vacío genera ZIP con meta.json y documents.json vacío', () async {
      final repo = makeRepo();
      final zipFile = await repo.createBackup([]);

      final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
      final names = archive.map((f) => f.name).toList();
      expect(names, contains('meta.json'));
      expect(names, contains('documents.json'));
    });
  });

  group('readBackup', () {
    Future<File> _buildZip({
      required Directory dir,
      required List<Map<String, dynamic>> docs,
      Map<String, List<int>>? images,
      int schemaVersion = 3,
    }) async {
      final archive = Archive();

      final meta = {'schema_version': schemaVersion, 'export_date': '2026-05-03', 'count': docs.length};
      final metaBytes = utf8.encode(jsonEncode(meta));
      archive.addFile(ArchiveFile('meta.json', metaBytes.length, metaBytes));

      final docsBytes = utf8.encode(jsonEncode(docs));
      archive.addFile(ArchiveFile('documents.json', docsBytes.length, docsBytes));

      for (final entry in (images ?? {}).entries) {
        archive.addFile(ArchiveFile('images/${entry.key}', entry.value.length, entry.value));
      }

      final zipBytes = ZipEncoder().encode(archive);
      final zipFile = File('${dir.path}/test_backup.zip');
      await zipFile.writeAsBytes(zipBytes);
      return zipFile;
    }

    test('extrae imágenes al directorio de destino', () async {
      final imageBytes = [0xFF, 0xD8, 0xFF, 0xE0];
      final zipFile = await _buildZip(
        dir: tempDir,
        docs: [
          {
            'title': 'Factura',
            'file_path': 'factura.jpg',
            'created_at': '2026-01-01T00:00:00.000',
          }
        ],
        images: {'factura.jpg': imageBytes},
      );

      final repo = BackupRepositoryImpl();
      final result = await repo.readBackup(zipFile, outputDir.path);

      final extractedFile = File('${outputDir.path}/factura.jpg');
      expect(extractedFile.existsSync(), isTrue);
      expect(result.documents.length, 1);
      expect(result.documents[0].filePath, extractedFile.path);
    });

    test('renombra con _bk si hay colisión de nombre', () async {
      // Crear archivo pre-existente
      await File('${outputDir.path}/factura.jpg').writeAsBytes([0x00]);

      final zipFile = await _buildZip(
        dir: tempDir,
        docs: [
          {
            'title': 'Factura',
            'file_path': 'factura.jpg',
            'created_at': '2026-01-01T00:00:00.000',
          }
        ],
        images: {'factura.jpg': [0xFF, 0xD8, 0xFF]},
      );

      final repo = BackupRepositoryImpl();
      final result = await repo.readBackup(zipFile, outputDir.path);

      expect(result.documents[0].filePath, endsWith('factura_bk.jpg'));
      expect(File('${outputDir.path}/factura_bk.jpg').existsSync(), isTrue);
    });

    test('usa _bk2 si _bk también existe', () async {
      await File('${outputDir.path}/factura.jpg').writeAsBytes([0x00]);
      await File('${outputDir.path}/factura_bk.jpg').writeAsBytes([0x00]);

      final zipFile = await _buildZip(
        dir: tempDir,
        docs: [
          {
            'title': 'Factura',
            'file_path': 'factura.jpg',
            'created_at': '2026-01-01T00:00:00.000',
          }
        ],
        images: {'factura.jpg': [0xFF, 0xD8, 0xFF]},
      );

      final repo = BackupRepositoryImpl();
      final result = await repo.readBackup(zipFile, outputDir.path);

      expect(result.documents[0].filePath, endsWith('factura_bk2.jpg'));
    });

    test('retorna schemaVersion y exportDate del meta.json', () async {
      final zipFile = await _buildZip(dir: tempDir, docs: [], schemaVersion: 3);

      final repo = BackupRepositoryImpl();
      final result = await repo.readBackup(zipFile, outputDir.path);

      expect(result.schemaVersion, 3);
      expect(result.exportDate, '2026-05-03');
    });

    test('lanza excepción si falta meta.json', () async {
      // ZIP sin meta.json
      final archive = Archive();
      final b = utf8.encode('[]');
      archive.addFile(ArchiveFile('documents.json', b.length, b));
      final zipBytes = ZipEncoder().encode(archive);
      final zipFile = File('${tempDir.path}/invalid.zip');
      await zipFile.writeAsBytes(zipBytes);

      final repo = BackupRepositoryImpl();
      expect(
        () => repo.readBackup(zipFile, outputDir.path),
        throwsException,
      );
    });
  });
}
