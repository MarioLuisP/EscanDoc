import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/notes/data/models/note_model.dart';
import 'package:escandoc/features/notes/data/repositories/note_repository.dart';
import 'package:escandoc/features/notes/domain/usecases/update_note.dart';

/// Mock del repository para tests unitarios
class MockNoteRepository extends Mock implements NoteRepository {}

/// Fake para NoteModel (requerido por mocktail)
class FakeNoteModel extends Fake implements NoteModel {}

/// Tests unitarios de UpdateNote UseCase
/// Usan mocks, no requieren BD real
void main() {
  late UpdateNote useCase;
  late MockNoteRepository mockRepository;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(FakeNoteModel());
  });

  setUp(() {
    mockRepository = MockNoteRepository();
    useCase = UpdateNote(repository: mockRepository);
  });

  group('UpdateNote UseCase', () {
    final existingNote = NoteModel(
      id: 1,
      content: 'Contenido original',
      createdAt: DateTime(2026, 1, 24, 10, 0),
    );

    final updatedNote = existingNote.copyWith(
      content: 'Contenido actualizado',
      updatedAt: DateTime(2026, 1, 24, 11, 0),
    );

    test('Debe actualizar nota existente', () async {
      // Arrange
      when(() => mockRepository.updateNote(any()))
          .thenAnswer((_) async => updatedNote);

      // Act
      final result = await useCase(
        noteId: existingNote.id!,
        content: updatedNote.content,
      );

      // Assert
      expect(result, isNotNull);
      expect(result?.content, updatedNote.content);
      verify(() => mockRepository.updateNote(any())).called(1);
    });

    test('Debe retornar nota actualizada', () async {
      // Arrange
      when(() => mockRepository.updateNote(any()))
          .thenAnswer((_) async => updatedNote);

      // Act
      final result = await useCase(
        noteId: existingNote.id!,
        content: 'Nuevo contenido',
      );

      // Assert
      expect(result, isA<NoteModel>());
      expect(result?.id, existingNote.id);
    });

    test('Debe fallar si nota no existe', () async {
      // Arrange
      const invalidNoteId = 999;
      when(() => mockRepository.updateNote(any()))
          .thenThrow(Exception('Note not found'));

      // Act
      final result = await useCase(
        noteId: invalidNoteId,
        content: 'Contenido',
      );

      // Assert
      expect(result, isNull);
      verify(() => mockRepository.updateNote(any())).called(1);
    });
  });
}
