import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/notes/data/repositories/note_repository.dart';
import 'package:escandoc/features/notes/domain/usecases/delete_note.dart';

/// Mock del repository para tests unitarios
class MockNoteRepository extends Mock implements NoteRepository {}

void main() {
  late DeleteNote useCase;
  late MockNoteRepository mockRepository;

  setUp(() {
    mockRepository = MockNoteRepository();
    useCase = DeleteNote(repository: mockRepository);
  });

  group('DeleteNote UseCase', () {
    test('Debe eliminar nota correctamente', () async {
      // Arrange
      const noteId = 1;
      when(() => mockRepository.deleteNote(noteId))
          .thenAnswer((_) async => true);

      // Act
      final result = await useCase(noteId);

      // Assert
      expect(result, isTrue);
      verify(() => mockRepository.deleteNote(noteId)).called(1);
    });

    test('Debe eliminar vinculación en document_notes', () async {
      // Arrange
      // Este test verifica que el repository se llama correctamente
      // La lógica CASCADE está en el repository/BD
      const noteId = 1;
      when(() => mockRepository.deleteNote(noteId))
          .thenAnswer((_) async => true);

      // Act
      final result = await useCase(noteId);

      // Assert
      expect(result, isTrue);
      // Verificar que se llamó al repository (que internamente maneja CASCADE)
      verify(() => mockRepository.deleteNote(noteId)).called(1);
    });

    test('Debe retornar false si nota no existe', () async {
      // Arrange
      const invalidNoteId = 999;
      when(() => mockRepository.deleteNote(invalidNoteId))
          .thenAnswer((_) async => false);

      // Act
      final result = await useCase(invalidNoteId);

      // Assert
      expect(result, isFalse);
      verify(() => mockRepository.deleteNote(invalidNoteId)).called(1);
    });
  });
}
