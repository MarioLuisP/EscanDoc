import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:escandoc/features/backup/domain/repositories/backup_repository.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';

class BackupRepositoryImpl implements BackupRepository {
  final Future<String> Function()? _getOutputDir;

  BackupRepositoryImpl({Future<String> Function()? getOutputDir})
      : _getOutputDir = getOutputDir;

  Future<String> _resolveOutputDir() async {
    if (_getOutputDir != null) return await _getOutputDir!();
    final dir = await getTemporaryDirectory();
    return dir.path;
  }

  @override
  Future<File> createBackup(List<DocumentModel> documents) async {
    final archive = Archive();

    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
    final meta = {
      'schema_version': 3,
      'export_date': dateStr,
      'count': documents.length,
    };
    _addBytes(archive, 'meta.json', utf8.encode(jsonEncode(meta)));

    final docsJson = documents.map((doc) {
      final map = doc.toMap();
      map.remove('id');
      map['file_path'] = p.basename(doc.filePath);
      return map;
    }).toList();
    _addBytes(archive, 'documents.json', utf8.encode(jsonEncode(docsJson)));

    for (final doc in documents) {
      final imageFile = File(doc.filePath);
      if (imageFile.existsSync()) {
        final bytes = await imageFile.readAsBytes();
        final filename = p.basename(doc.filePath);
        _addBytes(archive, 'images/$filename', bytes);
      }
    }

    final zipBytes = ZipEncoder().encode(archive);
    final outputDir = await _resolveOutputDir();
    final zipFile = File('$outputDir/escandoc_$dateStr.escdc');
    await zipFile.writeAsBytes(zipBytes);
    return zipFile;
  }

  @override
  Future<BackupReadResult> readBackup(File zipFile, String documentsDir) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final metaEntry = _findFile(archive, 'meta.json');
    if (metaEntry == null) throw Exception('Invalid backup: missing meta.json');
    final meta = jsonDecode(utf8.decode(metaEntry.content as List<int>)) as Map<String, dynamic>;

    final docsEntry = _findFile(archive, 'documents.json');
    if (docsEntry == null) throw Exception('Invalid backup: missing documents.json');
    final docsList = jsonDecode(utf8.decode(docsEntry.content as List<int>)) as List<dynamic>;

    // Extract images and build filename → absolute path map
    final pathMap = <String, String>{};
    for (final entry in archive) {
      if (!entry.isFile) continue;
      if (!entry.name.startsWith('images/')) continue;
      final filename = p.basename(entry.name);
      final targetPath = _resolveTargetPath(documentsDir, filename);
      await File(targetPath).writeAsBytes(entry.content as List<int>);
      pathMap[filename] = targetPath;
    }

    final documents = docsList.map((raw) {
      final map = Map<String, dynamic>.from(raw as Map<String, dynamic>);
      final originalFilename = map['file_path'] as String? ?? '';
      map['file_path'] = pathMap[originalFilename] ?? '$documentsDir/$originalFilename';
      return DocumentModel.fromMap(map);
    }).toList();

    return BackupReadResult(
      schemaVersion: meta['schema_version'] as int? ?? 0,
      exportDate: meta['export_date'] as String? ?? '',
      documents: documents,
    );
  }

  void _addBytes(Archive archive, String name, List<int> bytes) {
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  ArchiveFile? _findFile(Archive archive, String name) {
    for (final f in archive) {
      if (f.name == name) return f;
    }
    return null;
  }

  String _resolveTargetPath(String dir, String filename) {
    final ext = p.extension(filename);
    final base = p.basenameWithoutExtension(filename);

    final original = '$dir/$filename';
    if (!File(original).existsSync()) return original;

    final withBk = '$dir/${base}_bk$ext';
    if (!File(withBk).existsSync()) return withBk;

    var counter = 2;
    while (File('$dir/${base}_bk$counter$ext').existsSync()) {
      counter++;
    }
    return '$dir/${base}_bk$counter$ext';
  }
}
