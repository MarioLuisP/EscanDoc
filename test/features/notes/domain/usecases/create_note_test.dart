import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/notes/data/models/note_model.dart';
import 'package:escandoc/features/notes/data/repositories/note_repository.dart';
import 'package:escandoc/features/notes/domain/usecases/create_note.dart';

/// Mock del repository para tests unitarios
class MockNoteRepository extends Mock implements NoteRepository {}

/// Fake para NoteModel (requerido por mocktail)
class FakeNoteModel extends Fake implements NoteModel {}

/// Tests unitarios de CreateNote UseCase
/// Usan mocks, no requieren BD real
void main() {
  late CreateNote useCase;
  late MockNoteRepository mockRepository;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(FakeNoteModel());
  });

  setUp(() {
    mockRepository = MockNoteRepository();
    useCase = CreateNote(repository: mockRepository);
  });

  group('CreateNote UseCase', () {
    final testNote = NoteModel(
      content: 'Recordar pagar antes del vencimiento',
      createdAt: DateTime(2026, 1, 24, 10, 0),
    );

    final createdNote = testNote.copyWith(id: 1);

    test('Debe crear nota y vincularla a documento', () async {
      // Arrange
      const documentId = 1;
      when(() => mockRepository.createNote(any(), documentId))
          .thenAnswer((_) async => createdNote);

      // Act
      final result = await useCase(
        content: testNote.content,
        documentId: documentId,
      );

      // Assert
      expect(result, isNotNull);
      expect(result?.id, 1);
      expect(result?.content, testNote.content);
      verify(() => mockRepository.createNote(any(), documentId)).called(1);
    });

    test('Debe retornar nota creada con ID', () async {
      // Arrange
      const documentId = 1;
      when(() => mockRepository.createNote(any(), documentId))
          .thenAnswer((_) async => createdNote);

      // Act
      final result = await useCase(
        content: testNote.content,
        documentId: documentId,
      );

      // Assert
      expect(result, isA<NoteModel>());
      expect(result?.id, isNotNull);
      expect(result?.id, greaterThan(0));
    });

    test('Debe fallar si documento no existe', () async {
      // Arrange
      const invalidDocumentId = 999;
      when(() => mockRepository.createNote(any(), invalidDocumentId))
          .thenThrow(Exception('Document not found'));

      // Act
      final result = await useCase(
        content: testNote.content,
        documentId: invalidDocumentId,
      );

      // Assert
      expect(result, isNull);
      verify(() => mockRepository.createNote(any(), invalidDocumentId))
          .called(1);
    });
  });
}
