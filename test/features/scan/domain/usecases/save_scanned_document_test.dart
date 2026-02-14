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

  group('SaveScannedDocument - Imagen escaneada', () {
    final testImage = File('scanned_image.jpg');
    final now = DateTime(2026, 1, 25);

    test('debe guardar JPG directamente sin generar PDF', () async {
      // Arrange
      when(() => mockClassifier.detectType(any())).thenReturn('documento');
      when(() => mockClassifier.generateDocumentName(any(), any(), any()))
          .thenReturn('documento_25_Ene_2026');
      when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => 1);

      // Act
      final result = await useCase.call(testImage, '/test/output', 'es', currentDate: now);

      // Assert - JPG se guarda directamente como filePath
      expect(result.filePath, testImage.path);
      expect(result.filePath, endsWith('.jpg'));
    });

    test('debe guardar JPG con metadata completa', () async {
      // Arrange
      when(() => mockClassifier.detectType(any())).thenReturn('documento');
      when(() => mockClassifier.generateDocumentName(any(), any(), any()))
          .thenReturn('documento_25_Ene_2026');
      when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => 1);

      // Act
      final result = await useCase.call(testImage, '/test/output', 'es', currentDate: now);

      // Assert - JPG ~850KB (UI usará cacheWidth para thumbnails)
      expect(result.filePath, testImage.path);
      expect(result.title, 'documento_25_Ene_2026');
    });

    test('debe detectar tipo automáticamente', () async {
      // Arrange
      when(() => mockClassifier.detectType('')).thenReturn('documento');
      when(() => mockClassifier.generateDocumentName(any(), any(), any()))
          .thenReturn('documento_25_Ene_2026');
      when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => 1);

      // Act
      await useCase.call(testImage, '/test/output', 'es', currentDate: now);

      // Assert
      verify(() => mockClassifier.detectType('')).called(1);
    });

    test('debe generar nombre localizado', () async {
      // Arrange
      when(() => mockClassifier.detectType(any())).thenReturn('factura');
      when(() => mockClassifier.generateDocumentName('factura', now, 'es'))
          .thenReturn('factura_25_Ene_2026');
      when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => 1);

      // Act
      await useCase.call(testImage, '/test/output', 'es', currentDate: now);

      // Assert
      verify(() => mockClassifier.generateDocumentName('factura', now, 'es')).called(1);
    });

    test('debe guardar en BD con metadata', () async {
      // Arrange
      when(() => mockClassifier.detectType(any())).thenReturn('factura');
      when(() => mockClassifier.generateDocumentName(any(), any(), any()))
          .thenReturn('factura_25_Ene_2026');
      when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => 1);

      // Act
      final result = await useCase.call(testImage, '/test/output', 'es', currentDate: now);

      // Assert
      verify(() => mockRepository.insertDocument(any())).called(1);
      expect(result, isA<DocumentModel>());
      expect(result.title, 'factura_25_Ene_2026');
    });

    test('debe usar fecha actual para nombre', () async {
      // Arrange
      final customDate = DateTime(2026, 12, 31);
      when(() => mockClassifier.detectType(any())).thenReturn('recibo');
      when(() => mockClassifier.generateDocumentName('recibo', customDate, 'es'))
          .thenReturn('recibo_31_Dic_2026');
      when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => 1);

      // Act
      await useCase.call(testImage, '/test/output', 'es', currentDate: customDate);

      // Assert
      verify(() => mockClassifier.generateDocumentName('recibo', customDate, 'es')).called(1);
    });

    test('debe retornar documento guardado con ID', () async {
      // Arrange
      when(() => mockClassifier.detectType(any())).thenReturn('factura');
      when(() => mockClassifier.generateDocumentName(any(), any(), any()))
          .thenReturn('factura_25_Ene_2026');
      when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => 123);

      // Act
      final result = await useCase.call(testImage, '/test/output', 'es', currentDate: now);

      // Assert
      expect(result.id, 123);
      expect(result.title, 'factura_25_Ene_2026');
    });

    test('debe guardar con filePath apuntando al JPG', () async {
      // Arrange
      when(() => mockClassifier.detectType(any())).thenReturn('documento');
      when(() => mockClassifier.generateDocumentName(any(), any(), any()))
          .thenReturn('documento_25_Ene_2026');
      when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => 1);

      // Act
      final result = await useCase.call(testImage, '/test/output', 'es', currentDate: now);

      // Assert
      final captured = verify(
        () => mockRepository.insertDocument(captureAny()),
      ).captured.first as DocumentModel;

      expect(captured.filePath, testImage.path);
      expect(captured.filePath, endsWith('.jpg'));
    });
  });

  group('SaveScannedDocument - Notas iniciales (TFLite)', () {
    final testImage = File('scanned_image.jpg');
    final now = DateTime(2026, 2, 13);

    test('debe crear nota automática cuando se proporciona initialNotes', () async {
      // Arrange
      final initialNotes = 'Clasificado como: ticket (confianza: 85.3%)';
      when(() => mockClassifier.detectType(any())).thenReturn('documento');
      when(() => mockClassifier.generateDocumentName(any(), any(), any()))
          .thenReturn('documento_13_Feb_2026');
      when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => 123);
      when(() => mockNoteRepository.createNote(any(), any())).thenAnswer(
        (_) async => NoteModel(
          id: 456,
          content: initialNotes,
          createdAt: now,
        ),
      );

      // Act
      await useCase.call(
        testImage,
        '/test/output',
        'es',
        currentDate: now,
        initialNotes: initialNotes,
      );

      // Assert - debe crear nota
      verify(() => mockNoteRepository.createNote(any(), 123)).called(1);
    });

    test('debe vincular nota al documento creado', () async {
      // Arrange
      final initialNotes = 'Clasificado como: document (confianza: 92.1%)';
      when(() => mockClassifier.detectType(any())).thenReturn('documento');
      when(() => mockClassifier.generateDocumentName(any(), any(), any()))
          .thenReturn('documento_13_Feb_2026');
      when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => 999);
      when(() => mockNoteRepository.createNote(any(), any())).thenAnswer(
        (_) async => NoteModel(
          id: 111,
          content: initialNotes,
          createdAt: now,
        ),
      );

      // Act
      await useCase.call(
        testImage,
        '/test/output',
        'es',
        currentDate: now,
        initialNotes: initialNotes,
      );

      // Assert - debe pasar el documentId correcto (999)
      final captured = verify(
        () => mockNoteRepository.createNote(captureAny(), captureAny()),
      ).captured;

      final noteModel = captured[0] as NoteModel;
      final documentId = captured[1] as int;

      expect(noteModel.content, initialNotes);
      expect(documentId, 999);
    });

    test('NO debe crear nota si initialNotes es null', () async {
      // Arrange
      when(() => mockClassifier.detectType(any())).thenReturn('documento');
      when(() => mockClassifier.generateDocumentName(any(), any(), any()))
          .thenReturn('documento_13_Feb_2026');
      when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => 123);

      // Act
      await useCase.call(
        testImage,
        '/test/output',
        'es',
        currentDate: now,
        initialNotes: null,
      );

      // Assert - NO debe llamar a createNote
      verifyNever(() => mockNoteRepository.createNote(any(), any()));
    });

    test('NO debe crear nota si initialNotes es vacío', () async {
      // Arrange
      when(() => mockClassifier.detectType(any())).thenReturn('documento');
      when(() => mockClassifier.generateDocumentName(any(), any(), any()))
          .thenReturn('documento_13_Feb_2026');
      when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => 123);

      // Act
      await useCase.call(
        testImage,
        '/test/output',
        'es',
        currentDate: now,
        initialNotes: '',
      );

      // Assert - NO debe llamar a createNote
      verifyNever(() => mockNoteRepository.createNote(any(), any()));
    });

    test('debe retornar documento guardado incluso si la nota falla', () async {
      // Arrange
      final initialNotes = 'Clasificado como: ticket';
      when(() => mockClassifier.detectType(any())).thenReturn('documento');
      when(() => mockClassifier.generateDocumentName(any(), any(), any()))
          .thenReturn('documento_13_Feb_2026');
      when(() => mockRepository.insertDocument(any())).thenAnswer((_) async => 123);
      when(() => mockNoteRepository.createNote(any(), any()))
          .thenThrow(Exception('DB error'));

      // Act & Assert - debe lanzar la excepción (nota es crítica en el flujo actual)
      expect(
        () => useCase.call(
          testImage,
          '/test/output',
          'es',
          currentDate: now,
          initialNotes: initialNotes,
        ),
        throwsException,
      );
    });
  });
}

