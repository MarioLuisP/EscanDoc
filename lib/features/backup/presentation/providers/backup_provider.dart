import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:escandoc/features/backup/domain/repositories/backup_repository.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';

class BackupProvider extends ChangeNotifier {
  final BackupRepository _backupRepository;
  final DocumentRepository _documentRepository;

  bool isExporting = false;
  bool isImporting = false;
  String? error;

  BackupProvider({
    required BackupRepository backupRepository,
    required DocumentRepository documentRepository,
  })  : _backupRepository = backupRepository,
        _documentRepository = documentRepository;

  Future<File?> export() async {
    isExporting = true;
    error = null;
    notifyListeners();
    try {
      final documents = await _documentRepository.getAllDocuments();
      return await _backupRepository.createBackup(documents);
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      isExporting = false;
      notifyListeners();
    }
  }

  Future<int> importBackup(File zipFile, String documentsDir) async {
    isImporting = true;
    error = null;
    notifyListeners();
    try {
      final result = await _backupRepository.readBackup(zipFile, documentsDir);
      var count = 0;
      for (final doc in result.documents) {
        await _documentRepository.insertDocument(doc);
        count++;
      }
      return count;
    } catch (e) {
      error = e.toString();
      return 0;
    } finally {
      isImporting = false;
      notifyListeners();
    }
  }
}
