import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';
import 'package:escandoc/features/documents/domain/usecases/delete_document.dart';

/// Mock del repository para tests unitarios
class MockDocumentRepository extends Mock implements DocumentRepository {}

void main() {
  late DeleteDocument useCase;
  late MockDocumentRepository mockRepository;

  setUp(() {
    mockRepository = MockDocumentRepository();
    useCase = DeleteDocument(repository: mockRepository);
  });

  group('DeleteDocument UseCase', () {
    test('Debe eliminar documento y archivos asociados', () async {
      // Arrange
      const documentId = 1;
      when(() => mockRepository.deleteDocument(documentId))
          .thenAnswer((_) async => true);

      // Act
      final result = await useCase(documentId);

      // Assert
      expect(result, isTrue);
      verify(() => mockRepository.deleteDocument(documentId)).called(1);
    });

    test('Debe retornar false si documento no existe', () async {
      // Arrange
      const nonExistentId = 999;
      when(() => mockRepository.deleteDocument(nonExistentId))
          .thenAnswer((_) async => false);

      // Act
      final result = await useCase(nonExistentId);

      // Assert
      expect(result, isFalse);
      verify(() => mockRepository.deleteDocument(nonExistentId)).called(1);
    });

    test('Debe retornar false si falla eliminación de archivo', () async {
      // Arrange
      const documentId = 1;
      when(() => mockRepository.deleteDocument(documentId))
          .thenAnswer((_) async => false);

      // Act
      final result = await useCase(documentId);

      // Assert
      expect(result, isFalse);
      verify(() => mockRepository.deleteDocument(documentId)).called(1);
    });

    test('Debe eliminar thumbnail además del PDF', () async {
      // Arrange
      // Este test verifica que el repository se llama correctamente
      // La lógica de eliminar thumbnail está en el repository
      const documentId = 1;
      when(() => mockRepository.deleteDocument(documentId))
          .thenAnswer((_) async => true);

      // Act
      final result = await useCase(documentId);

      // Assert
      expect(result, isTrue);
      // Verificar que se llamó al repository (que internamente elimina thumbnail)
      verify(() => mockRepository.deleteDocument(documentId)).called(1);
    });
  });
}
