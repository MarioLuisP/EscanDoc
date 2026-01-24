import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';
import 'package:escandoc/features/documents/domain/usecases/get_documents.dart';

/// Mock del repository para tests unitarios
class MockDocumentRepository extends Mock implements DocumentRepository {}

void main() {
  late GetDocuments useCase;
  late MockDocumentRepository mockRepository;

  setUp(() {
    mockRepository = MockDocumentRepository();
    useCase = GetDocuments(repository: mockRepository);
  });

  group('GetDocuments UseCase', () {
    final testDocuments = [
      DocumentModel(
        id: 1,
        title: 'factura_20_Ene_2026',
        filePath: '/storage/documents/factura_20_Ene_2026.pdf',
        thumbnailPath: '/storage/thumbnails/factura_20_Ene_2026_thumb.jpg',
        docType: 'factura',
        createdAt: DateTime(2026, 1, 20, 10, 15),
      ),
      DocumentModel(
        id: 2,
        title: 'recibo_17_Ene_2026',
        filePath: '/storage/documents/recibo_17_Ene_2026.pdf',
        thumbnailPath: '/storage/thumbnails/recibo_17_Ene_2026_thumb.jpg',
        docType: 'recibo',
        createdAt: DateTime(2026, 1, 17, 14, 30),
      ),
    ];

    test('Debe retornar lista ordenada por fecha (más reciente primero)', () async {
      // Arrange
      when(() => mockRepository.getAllDocuments())
          .thenAnswer((_) async => testDocuments);

      // Act
      final result = await useCase();

      // Assert
      expect(result, isA<List<DocumentModel>>());
      expect(result.length, 2);

      // Verificar orden descendente (más reciente primero)
      expect(result[0].id, 1); // 20 Ene es más reciente
      expect(result[1].id, 2); // 17 Ene es más antiguo

      verify(() => mockRepository.getAllDocuments()).called(1);
    });

    test('Debe retornar lista vacía si no hay documentos', () async {
      // Arrange
      when(() => mockRepository.getAllDocuments())
          .thenAnswer((_) async => []);

      // Act
      final result = await useCase();

      // Assert
      expect(result, isEmpty);
      verify(() => mockRepository.getAllDocuments()).called(1);
    });

    test('Debe manejar error de BD y retornar lista vacía', () async {
      // Arrange
      when(() => mockRepository.getAllDocuments())
          .thenThrow(Exception('Database error'));

      // Act
      final result = await useCase();

      // Assert
      expect(result, isEmpty);
      verify(() => mockRepository.getAllDocuments()).called(1);
    });
  });
}
