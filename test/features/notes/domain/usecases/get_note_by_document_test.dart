import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/notes/data/models/note_model.dart';
import 'package:escandoc/features/notes/data/repositories/note_repository.dart';
import 'package:escandoc/features/notes/domain/usecases/get_note_by_document.dart';

/// Mock del repository para tests unitarios
class MockNoteRepository extends Mock implements NoteRepository {}

void main() {
  late GetNoteByDocument useCase;
  late MockNoteRepository mockRepository;

  setUp(() {
    mockRepository = MockNoteRepository();
    useCase = GetNoteByDocument(repository: mockRepository);
  });

  group('GetNoteByDocument UseCase', () {
    final testNote = NoteModel(
      id: 1,
      content: 'Recordar pagar antes del vencimiento',
      createdAt: DateTime(2026, 1, 24, 10, 0),
    );

    test('Debe retornar nota vinculada a documento', () async {
      // Arrange
      const documentId = 1;
      when(() => mockRepository.getNoteByDocument(documentId))
          .thenAnswer((_) async => testNote);

      // Act
      final result = await useCase(documentId);

      // Assert
      expect(result, isNotNull);
      expect(result, isA<NoteModel>());
      expect(result?.id, testNote.id);
      expect(result?.content, testNote.content);
      verify(() => mockRepository.getNoteByDocument(documentId)).called(1);
    });

    test('Debe retornar null si no tiene nota', () async {
      // Arrange
      const documentId = 2;
      when(() => mockRepository.getNoteByDocument(documentId))
          .thenAnswer((_) async => null);

      // Act
      final result = await useCase(documentId);

      // Assert
      expect(result, isNull);
      verify(() => mockRepository.getNoteByDocument(documentId)).called(1);
    });

    test('Debe manejar error de BD', () async {
      // Arrange
      const documentId = 1;
      when(() => mockRepository.getNoteByDocument(documentId))
          .thenThrow(Exception('Database error'));

      // Act
      final result = await useCase(documentId);

      // Assert
      expect(result, isNull);
      verify(() => mockRepository.getNoteByDocument(documentId)).called(1);
    });
  });
}
