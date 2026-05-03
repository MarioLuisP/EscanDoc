import 'dart:io';
import 'package:escandoc/features/documents/data/models/document_model.dart';

class BackupReadResult {
  final int schemaVersion;
  final String exportDate;
  final List<DocumentModel> documents;

  const BackupReadResult({
    required this.schemaVersion,
    required this.exportDate,
    required this.documents,
  });
}

abstract class BackupRepository {
  Future<File> createBackup(List<DocumentModel> documents);
  Future<BackupReadResult> readBackup(File zipFile, String documentsDir);
}
