import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/backup/domain/repositories/backup_repository.dart';
import 'package:escandoc/features/backup/presentation/providers/backup_provider.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';

class MockBackupRepository extends Mock implements BackupRepository {}
class MockDocumentRepository extends Mock implements DocumentRepository {}

void main() {
  late MockBackupRepository backupRepo;
  late MockDocumentRepository documentRepo;
  late BackupProvider provider;

  final doc = DocumentModel(
    id: 1,
    title: 'Factura',
    filePath: '/docs/factura.jpg',
    createdAt: DateTime(2026, 5, 3),
  );

  setUpAll(() {
    registerFallbackValue(doc);
    registerFallbackValue(File('/tmp/backup.zip'));
  });

  setUp(() {
    backupRepo = MockBackupRepository();
    documentRepo = MockDocumentRepository();
    provider = BackupProvider(
      backupRepository: backupRepo,
      documentRepository: documentRepo,
    );
  });

  group('export', () {
    test('retorna File al exportar exitosamente', () async {
      final fakeZip = File('/tmp/escandoc_backup_2026-05-03.zip');
      when(() => documentRepo.getAllDocuments()).thenAnswer((_) async => [doc]);
      when(() => backupRepo.createBackup(any())).thenAnswer((_) async => fakeZip);

      final result = await provider.export();

      expect(result, fakeZip);
      expect(provider.isExporting, false);
      expect(provider.error, isNull);
    });

    test('setea isExporting = true durante la operación', () async {
      final fakeZip = File('/tmp/escandoc_backup.zip');
      when(() => documentRepo.getAllDocuments()).thenAnswer((_) async => [doc]);
      when(() => backupRepo.createBackup(any())).thenAnswer((_) async {
        expect(provider.isExporting, true);
        return fakeZip;
      });

      await provider.export();
      expect(provider.isExporting, false);
    });

    test('retorna null y setea error cuando falla', () async {
      when(() => documentRepo.getAllDocuments()).thenThrow(Exception('DB error'));

      final result = await provider.export();

      expect(result, isNull);
      expect(provider.error, isNotNull);
      expect(provider.isExporting, false);
    });
  });

  group('importBackup', () {
    test('inserta cada documento y retorna cantidad importada', () async {
      final zipFile = File('/tmp/backup.zip');
      final importedDoc = DocumentModel(
        title: 'Factura',
        filePath: '/docs/factura.jpg',
        createdAt: DateTime(2026, 1, 1),
      );
      when(() => backupRepo.readBackup(any(), any())).thenAnswer(
        (_) async => BackupReadResult(
          schemaVersion: 3,
          exportDate: '2026-05-01',
          documents: [importedDoc],
        ),
      );
      when(() => documentRepo.insertDocument(any())).thenAnswer((_) async => 1);

      final count = await provider.importBackup(zipFile, '/app/docs');

      expect(count, 1);
      verify(() => documentRepo.insertDocument(importedDoc)).called(1);
      expect(provider.isImporting, false);
    });

    test('retorna 0 y setea error cuando falla', () async {
      final zipFile = File('/tmp/backup.zip');
      when(() => backupRepo.readBackup(any(), any())).thenThrow(Exception('invalid zip'));

      final count = await provider.importBackup(zipFile, '/app/docs');

      expect(count, 0);
      expect(provider.error, isNotNull);
      expect(provider.isImporting, false);
    });

    test('setea isImporting = true durante la operación', () async {
      final zipFile = File('/tmp/backup.zip');
      when(() => backupRepo.readBackup(any(), any())).thenAnswer((_) async {
        expect(provider.isImporting, true);
        return BackupReadResult(schemaVersion: 3, exportDate: '', documents: []);
      });

      await provider.importBackup(zipFile, '/app/docs');
      expect(provider.isImporting, false);
    });
  });
}
