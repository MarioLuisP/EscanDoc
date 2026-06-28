import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';
import 'package:escandoc/features/documents/domain/usecases/delete_documents.dart';

/// Mock del repository para tests unitarios
class MockDocumentRepository extends Mock implements DocumentRepository {}

/// Tests unitarios de DeleteDocuments UseCase (borrado por lote).
/// Usan mocks, no requieren BD real.
void main() {
  late DeleteDocuments useCase;
  late MockDocumentRepository mockRepository;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(<int>[]);
  });

  setUp(() {
    mockRepository = MockDocumentRepository();
    useCase = DeleteDocuments(repository: mockRepository);
  });

  group('DeleteDocuments UseCase', () {
    test('borra el lote en una sola llamada y devuelve los ids borrados', () async {
      // Arrange
      final ids = [1, 2, 3];
      when(() => mockRepository.deleteDocuments(any()))
          .thenAnswer((_) async => [1, 2, 3]);

      // Act
      final result = await useCase(ids);

      // Assert
      expect(result, [1, 2, 3]);
      final captured = verify(() => mockRepository.deleteDocuments(captureAny()))
          .captured
          .single as List<int>;
      expect(captured, [1, 2, 3]);
    });

    test('lista vacía: no llama al repositorio y devuelve []', () async {
      // Act
      final result = await useCase([]);

      // Assert
      expect(result, isEmpty);
      verifyNever(() => mockRepository.deleteDocuments(any()));
    });

    test('fallo parcial: devuelve solo los ids que el repositorio reporta borrados', () async {
      // Arrange — el id 2 no se pudo borrar
      when(() => mockRepository.deleteDocuments(any()))
          .thenAnswer((_) async => [1, 3]);

      // Act
      final result = await useCase([1, 2, 3]);

      // Assert
      expect(result, [1, 3]);
    });

    test('excepción del repositorio: fail-safe devuelve []', () async {
      // Arrange
      when(() => mockRepository.deleteDocuments(any()))
          .thenThrow(Exception('DB error'));

      // Act
      final result = await useCase([1, 2, 3]);

      // Assert
      expect(result, isEmpty);
    });
  });
}
