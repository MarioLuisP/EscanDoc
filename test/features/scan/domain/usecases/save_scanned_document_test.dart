import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/scan/domain/usecases/save_scanned_document.dart';
import 'package:escandoc/core/services/document_classifier.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';
import 'package:escandoc/features/notes/data/models/note_model.dart';
import 'package:escandoc/features/notes/data/repositories/note_repository.dart';

// Mocks
class MockDocumentClassifier extends Mock implements DocumentClassifier {}
class MockDocumentRepository extends Mock implements DocumentRepository {}
class MockNoteRepository extends Mock implements NoteRepository {}

// Fakes para registerFallbackValue
class FakeDocumentModel extends Fake implements DocumentModel {}
class FakeNoteModel extends Fake implements NoteModel {}

void main() {
  late SaveScannedDocument useCase;
  late MockDocumentClassifier mockClassifier;
  late MockDocumentRepository mockRepository;
  late MockNoteRepository mockNoteRepository;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(FakeDocumentModel());
    registerFallbackValue(FakeNoteModel());
  });

  setUp(() {
    mockClassifier = MockDocumentClassifier();
    mockRepository = MockDocumentRepository();
    mockNoteRepository = MockNoteRepository();

    useCase = SaveScannedDocument(
      mockClassifier,
      mockRepository,
      mockNoteRepository,
    );
  });

  // Helper para stubs mínimos en cada test
  void stubDefaults({
    String tfliteClass = 'documento',
    String locale = 'es',
    String displayName = 'Documento',
    int todayCount = 0,
    String generatedName = 'Documento 1 del 25/1',
    int insertedId = 1,
  }) {
    when(() => mockClassifier.getTypeDisplayName(tfliteClass, locale))
        .thenReturn(displayName);
    when(() => mockRepository.countByTypePrefix(displayName, any()))
        .thenAnswer((_) async => todayCount);
    when(() => mockClassifier.generateDocumentName(tfliteClass, any(), locale, todayCount + 1))
        .thenReturn(generatedName);
    when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => insertedId);
  }

  group('SaveScannedDocument - Guardado JPG', () {
    final testImage = File('scanned_image.jpg');
    final now = DateTime(2026, 1, 25);

    test('debe guardar JPG directamente como filePath', () async {
      stubDefaults();

      final result = await useCase.call(testImage, '/test/output', 'es', currentDate: now);

      expect(result.filePath, testImage.path);
      expect(result.filePath, endsWith('.jpg'));
    });

    test('nombre usa el tipo TFLite y número secuencial', () async {
      stubDefaults(
        tfliteClass: 'factura',
        displayName: 'Factura',
        todayCount: 0,
        generatedName: 'Factura 1 del 25/1',
      );

      final result = await useCase.call(
        testImage, '/test/output', 'es',
        currentDate: now,
        tfliteClass: 'factura',
      );

      expect(result.title, 'Factura 1 del 25/1');
    });

    test('si ya hay 2 facturas hoy → nuevo es Factura 3', () async {
      stubDefaults(
        tfliteClass: 'factura',
        displayName: 'Factura',
        todayCount: 2,
        generatedName: 'Factura 3 del 25/1',
      );

      final result = await useCase.call(
        testImage, '/test/output', 'es',
        currentDate: now,
        tfliteClass: 'factura',
      );

      expect(result.title, 'Factura 3 del 25/1');
      verify(() => mockClassifier.generateDocumentName('factura', any(), 'es', 3)).called(1);
    });

    test('manuscrito → nombre es "Nota N del D/M"', () async {
      stubDefaults(
        tfliteClass: 'manuscrito',
        displayName: 'Nota',
        generatedName: 'Nota 1 del 25/1',
      );

      final result = await useCase.call(
        testImage, '/test/output', 'es',
        currentDate: now,
        tfliteClass: 'manuscrito',
      );

      expect(result.title, 'Nota 1 del 25/1');
    });

    test('debe retornar documento con ID de BD', () async {
      stubDefaults(insertedId: 123);

      final result = await useCase.call(testImage, '/test/output', 'es', currentDate: now);

      expect(result.id, 123);
    });

    test('debe guardar en BD', () async {
      stubDefaults();

      await useCase.call(testImage, '/test/output', 'es', currentDate: now);

      verify(() => mockRepository.insertDocument(any())).called(1);
    });

    test('filePath del documento insertado apunta al JPG', () async {
      stubDefaults();

      await useCase.call(testImage, '/test/output', 'es', currentDate: now);

      final captured = verify(() => mockRepository.insertDocument(captureAny()))
          .captured.first as DocumentModel;
      expect(captured.filePath, testImage.path);
    });
  });

  group('SaveScannedDocument - Notas iniciales (TFLite)', () {
    final testImage = File('scanned_image.jpg');
    final now = DateTime(2026, 2, 13);

    test('debe crear nota automática cuando se proporciona initialNotes', () async {
      const initialNotes = 'Clasificado como: ticket (confianza: 85.3%)';
      stubDefaults(insertedId: 123);
      when(() => mockNoteRepository.createNote(any(), any())).thenAnswer(
        (_) async => NoteModel(id: 456, content: initialNotes, createdAt: now),
      );

      await useCase.call(
        testImage, '/test/output', 'es',
        currentDate: now,
        initialNotes: initialNotes,
      );

      verify(() => mockNoteRepository.createNote(any(), 123)).called(1);
    });

    test('debe vincular nota al documento con su ID', () async {
      const initialNotes = 'Clasificado como: document (confianza: 92.1%)';
      stubDefaults(insertedId: 999);
      when(() => mockNoteRepository.createNote(any(), any())).thenAnswer(
        (_) async => NoteModel(id: 111, content: initialNotes, createdAt: now),
      );

      await useCase.call(
        testImage, '/test/output', 'es',
        currentDate: now,
        initialNotes: initialNotes,
      );

      final captured = verify(
        () => mockNoteRepository.createNote(captureAny(), captureAny()),
      ).captured;
      expect((captured[0] as NoteModel).content, initialNotes);
      expect(captured[1] as int, 999);
    });

    test('NO debe crear nota si initialNotes es null', () async {
      stubDefaults(insertedId: 123);

      await useCase.call(
        testImage, '/test/output', 'es',
        currentDate: now,
        initialNotes: null,
      );

      verifyNever(() => mockNoteRepository.createNote(any(), any()));
    });

    test('NO debe crear nota si initialNotes es vacío', () async {
      stubDefaults(insertedId: 123);

      await useCase.call(
        testImage, '/test/output', 'es',
        currentDate: now,
        initialNotes: '',
      );

      verifyNever(() => mockNoteRepository.createNote(any(), any()));
    });

    test('debe lanzar excepción si la nota falla', () async {
      const initialNotes = 'Clasificado como: ticket';
      stubDefaults(insertedId: 123);
      when(() => mockNoteRepository.createNote(any(), any()))
          .thenThrow(Exception('DB error'));

      expect(
        () => useCase.call(
          testImage, '/test/output', 'es',
          currentDate: now,
          initialNotes: initialNotes,
        ),
        throwsException,
      );
    });
  });
}
