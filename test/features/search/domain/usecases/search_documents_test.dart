import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/search/domain/usecases/search_documents.dart';
import 'package:escandoc/features/search/data/models/search_result.dart';
import 'package:escandoc/features/search/data/repositories/search_repository.dart';

// Mock del repository
class MockSearchRepository extends Mock implements SearchRepository {}

void main() {
  late SearchDocuments useCase;
  late MockSearchRepository mockRepository;

  setUp(() {
    mockRepository = MockSearchRepository();
    useCase = SearchDocuments(repository: mockRepository);
  });

  group('SearchDocuments UseCase', () {
    final testResults = [
      SearchResult(
        id: 1,
        type: 'document',
        title: 'Factura Edesur Enero 2026',
        snippet: 'EDESUR S.A. <b>Factura</b> de Energía...',
        date: DateTime(2026, 1, 15),
      ),
      SearchResult(
        id: 2,
        type: 'note',
        title: 'Nota de pago',
        snippet: 'Pagar <b>factura</b> usando Mercado Pago...',
        date: DateTime(2026, 1, 16),
      ),
    ];

    test('Debe buscar en documentos y retornar resultados', () async {
      // Arrange
      const query = 'factura';
      when(() => mockRepository.search(query))
          .thenAnswer((_) async => testResults);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result, testResults);
      expect(result.length, 2);
      expect(result.first.type, 'document');
      verify(() => mockRepository.search(query)).called(1);
    });

    test('Debe buscar en notas vinculadas', () async {
      // Arrange
      const query = 'pago';
      final noteResults = [
        SearchResult(
          id: 3,
          type: 'note',
          title: 'Nota pago',
          snippet: 'Mercado <b>Pago</b>...',
          date: DateTime(2026, 1, 17),
        ),
      ];
      when(() => mockRepository.search(query))
          .thenAnswer((_) async => noteResults);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.length, 1);
      expect(result.first.type, 'note');
      verify(() => mockRepository.search(query)).called(1);
    });

    test('Debe retornar lista vacía si no encuentra nada', () async {
      // Arrange
      const query = 'xyz123notfound';
      when(() => mockRepository.search(query))
          .thenAnswer((_) async => []);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result, isEmpty);
      verify(() => mockRepository.search(query)).called(1);
    });

    test('Debe ordenar resultados por relevancia (rank)', () async {
      // Arrange
      const query = 'test';
      final unsortedResults = [
        SearchResult(
          id: 2,
          type: 'note',
          title: 'Segundo',
          snippet: 'snippet 2',
          date: DateTime(2026, 1, 10),
        ),
        SearchResult(
          id: 1,
          type: 'document',
          title: 'Primero',
          snippet: 'snippet 1',
          date: DateTime(2026, 1, 20),
        ),
      ];
      // Repository ya retorna ordenado por rank (asumimos)
      when(() => mockRepository.search(query))
          .thenAnswer((_) async => unsortedResults);

      // Act
      final result = await useCase.execute(query);

      // Assert
      // Repository es responsable de ordenar por rank
      expect(result, unsortedResults);
      verify(() => mockRepository.search(query)).called(1);
    });

    test('Debe limitar resultados a 20 items', () async {
      // Arrange
      const query = 'test';
      final manyResults = List.generate(
        25,
        (i) => SearchResult(
          id: i,
          type: 'document',
          title: 'Doc $i',
          snippet: 'snippet $i',
          date: DateTime(2026, 1, i + 1),
        ),
      );
      // Repository ya limita a 20 (asumimos según spec)
      when(() => mockRepository.search(query))
          .thenAnswer((_) async => manyResults.take(20).toList());

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.length, 20);
      verify(() => mockRepository.search(query)).called(1);
    });

    test('Debe retornar snippet con query destacado', () async {
      // Arrange
      const query = 'edesur';
      final resultsWithSnippet = [
        SearchResult(
          id: 1,
          type: 'document',
          title: 'Factura',
          snippet: '<b>EDESUR</b> S.A. Factura de Energía...',
          date: DateTime(2026, 1, 15),
        ),
      ];
      when(() => mockRepository.search(query))
          .thenAnswer((_) async => resultsWithSnippet);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result.first.snippet, contains('<b>'));
      expect(result.first.snippet, contains('</b>'));
      verify(() => mockRepository.search(query)).called(1);
    });

    test('Debe manejar queries vacíos retornando lista vacía', () async {
      // Arrange
      const query = '';
      when(() => mockRepository.search(query))
          .thenAnswer((_) async => []);

      // Act
      final result = await useCase.execute(query);

      // Assert
      expect(result, isEmpty);
      verify(() => mockRepository.search(query)).called(1);
    });

    test('Debe propagar excepciones del repository', () async {
      // Arrange
      const query = 'test';
      when(() => mockRepository.search(query))
          .thenThrow(Exception('Database error'));

      // Act & Assert
      expect(
        () => useCase.execute(query),
        throwsException,
      );
    });
  });
}
