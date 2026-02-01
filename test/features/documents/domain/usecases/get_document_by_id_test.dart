import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';
import 'package:escandoc/features/documents/domain/usecases/get_document_by_id.dart';

/// Mock del repository para tests unitarios
class MockDocumentRepository extends Mock implements DocumentRepository {}

/// NOTA: Tests skippeados porque usan repositorio real que requiere sqflite_sqlcipher nativo
/// Para correrlos: flutter test --device-id=<device>
void main() {
  late GetDocumentById useCase;
  late MockDocumentRepository mockRepository;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    mockRepository = MockDocumentRepository();
    useCase = GetDocumentById(repository: mockRepository);
  });

  group('GetDocumentById UseCase', skip: 'Usa repositorio real con sqflite_sqlcipher (device/emulador)', () {
    final testDocument = DocumentModel(
      id: 1,
      title: 'factura_20_Ene_2026',
      filePath: '/storage/documents/factura_20_Ene_2026.pdf',
      thumbnailPath: '/storage/thumbnails/factura_20_Ene_2026_thumb.jpg',
      docType: 'factura',
      createdAt: DateTime(2026, 1, 20, 10, 15),
    );

    test('Debe retornar documento si existe', () async {
      // Arrange
      const documentId = 1;
      when(() => mockRepository.getDocumentById(documentId))
          .thenAnswer((_) async => testDocument);

      // Act
      final result = await useCase(documentId);

      // Assert
      expect(result, isNotNull);
      expect(result, isA<DocumentModel>());
      expect(result?.id, documentId);
      expect(result?.title, 'factura_20_Ene_2026');
      verify(() => mockRepository.getDocumentById(documentId)).called(1);
    });

    test('Debe retornar null si no existe', () async {
      // Arrange
      const nonExistentId = 999;
      when(() => mockRepository.getDocumentById(nonExistentId))
          .thenAnswer((_) async => null);

      // Act
      final result = await useCase(nonExistentId);

      // Assert
      expect(result, isNull);
      verify(() => mockRepository.getDocumentById(nonExistentId)).called(1);
    });

    test('Debe manejar error de BD', () async {
      // Arrange
      const documentId = 1;
      when(() => mockRepository.getDocumentById(documentId))
          .thenThrow(Exception('Database connection error'));

      // Act
      final result = await useCase(documentId);

      // Assert
      expect(result, isNull);
      verify(() => mockRepository.getDocumentById(documentId)).called(1);
    });
  });
}
