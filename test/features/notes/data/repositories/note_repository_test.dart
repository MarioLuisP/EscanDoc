import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:escandoc/core/database/database_helper.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';
import 'package:escandoc/features/notes/data/models/note_model.dart';
import 'package:escandoc/features/notes/data/repositories/note_repository.dart';

/// Tests de integración para NoteRepository
/// Usan sqflite_common_ffi para ejecutar en desktop
void main() {
  late NoteRepository noteRepository;
  late DocumentRepository documentRepository;

  // Inicializar FFI para tests en desktop
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Crear repositorios
    noteRepository = NoteRepository();
    documentRepository = DocumentRepository();

    // Limpiar tablas antes de cada test
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;
    await db.delete('document_notes');
    await db.delete('notes');
    await db.delete('documents');
  });

  tearDown(() async {
    // Limpiar tablas después de cada test
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;
    await db.delete('document_notes');
    await db.delete('notes');
    await db.delete('documents');
  });

  group('NoteRepository Integration Tests', () {
    late DocumentModel testDocument;
    late int documentId;

    setUp(() async {
      // Crear un documento para las pruebas
      testDocument = DocumentModel(
        title: 'documento_test',
        filePath: '/test/documento_test.pdf',
        docType: 'documento',
        createdAt: DateTime(2026, 1, 24, 10, 0),
      );
      documentId = await documentRepository.insertDocument(testDocument);
    });

    final testNote = NoteModel(
      title: 'Pagar antes del 15',
      content: 'Recordar pagar antes del vencimiento',
      createdAt: DateTime(2026, 1, 24, 10, 0),
    );

    test('Debe insertar nota en BD', () async {
      // Act
      final createdNote = await noteRepository.createNote(testNote, documentId);

      // Assert
      expect(createdNote.id, greaterThan(0));
      expect(createdNote.title, testNote.title);
      expect(createdNote.content, testNote.content);

      // Verificar que se insertó correctamente
      final retrieved = await noteRepository.getNoteById(createdNote.id!);
      expect(retrieved, isNotNull);
      expect(retrieved!.title, testNote.title);
    });

    test('Debe insertar vinculación en document_notes', () async {
      // Act
      final createdNote = await noteRepository.createNote(testNote, documentId);

      // Assert - Verificar que se puede recuperar por documento
      final noteByDoc = await noteRepository.getNoteByDocument(documentId);
      expect(noteByDoc, isNotNull);
      expect(noteByDoc!.id, createdNote.id);
      expect(noteByDoc.title, testNote.title);
    });

    test('Debe recuperar nota por documento_id', () async {
      // Arrange
      await noteRepository.createNote(testNote, documentId);

      // Act
      final result = await noteRepository.getNoteByDocument(documentId);

      // Assert
      expect(result, isNotNull);
      expect(result!.title, testNote.title);
      expect(result.content, testNote.content);
    });

    test('Debe actualizar contenido de nota', () async {
      // Arrange
      final createdNote = await noteRepository.createNote(testNote, documentId);
      final updatedNote = createdNote.copyWith(
        title: 'Título actualizado',
        content: 'Contenido actualizado',
      );

      // Act
      await noteRepository.updateNote(updatedNote);

      // Assert
      final retrieved = await noteRepository.getNoteById(createdNote.id!);
      expect(retrieved!.title, 'Título actualizado');
      expect(retrieved.content, 'Contenido actualizado');
    });

    test('Debe eliminar nota y vinculación (CASCADE)', () async {
      // Arrange
      final createdNote = await noteRepository.createNote(testNote, documentId);
      final noteId = createdNote.id!;

      // Verificar que existe antes de eliminar
      final beforeDelete = await noteRepository.getNoteById(noteId);
      expect(beforeDelete, isNotNull);

      final beforeDeleteByDoc = await noteRepository.getNoteByDocument(documentId);
      expect(beforeDeleteByDoc, isNotNull);

      // Act
      final deleted = await noteRepository.deleteNote(noteId);

      // Assert
      expect(deleted, isTrue);

      // Verificar que la nota ya no existe
      final afterDelete = await noteRepository.getNoteById(noteId);
      expect(afterDelete, isNull);

      // Verificar que la vinculación también se eliminó (CASCADE)
      final afterDeleteByDoc = await noteRepository.getNoteByDocument(documentId);
      expect(afterDeleteByDoc, isNull);
    });

    test('Debe retornar null si documento no tiene nota', () async {
      // Act
      final result = await noteRepository.getNoteByDocument(documentId);

      // Assert
      expect(result, isNull);
    });
  });
}
