import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/documents/domain/usecases/rename_document.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';

class MockDocumentRepository extends Mock implements DocumentRepository {}
class FakeDocumentModel extends Fake implements DocumentModel {}

void main() {
  late RenameDocument useCase;
  late MockDocumentRepository mockRepository;

  final testDoc = DocumentModel(
    id: 1,
    title: 'Documento 1 del 17/2',
    filePath: '/test/doc.jpg',
    createdAt: DateTime(2026, 2, 17),
    updatedAt: DateTime(2026, 2, 17),
  );

  setUpAll(() {
    registerFallbackValue(FakeDocumentModel());
  });

  setUp(() {
    mockRepository = MockDocumentRepository();
    useCase = RenameDocument(repository: mockRepository);
  });

  group('RenameDocument', () {
    test('renombra correctamente y retorna true', () async {
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockRepository.updateDocument(any()))
          .thenAnswer((_) async => 1);

      final result = await useCase(1, 'Factura Luz Febrero');

      expect(result, isTrue);
    });

    test('guarda el título exactamente como lo escribe el usuario', () async {
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockRepository.updateDocument(any()))
          .thenAnswer((_) async => 1);

      await useCase(1, 'Mi factura del gas');

      final captured = verify(() => mockRepository.updateDocument(captureAny()))
          .captured.single as DocumentModel;
      expect(captured.title, 'Mi factura del gas');
    });

    test('hace trim del título', () async {
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockRepository.updateDocument(any()))
          .thenAnswer((_) async => 1);

      await useCase(1, '  Factura Luz  ');

      final captured = verify(() => mockRepository.updateDocument(captureAny()))
          .captured.single as DocumentModel;
      expect(captured.title, 'Factura Luz');
    });

    test('título vacío → retorna false sin tocar BD', () async {
      final result = await useCase(1, '');

      expect(result, isFalse);
      verifyNever(() => mockRepository.getDocumentById(any()));
      verifyNever(() => mockRepository.updateDocument(any()));
    });

    test('título solo espacios → retorna false sin tocar BD', () async {
      final result = await useCase(1, '   ');

      expect(result, isFalse);
      verifyNever(() => mockRepository.updateDocument(any()));
    });

    test('documento no existe → retorna false', () async {
      when(() => mockRepository.getDocumentById(999))
          .thenAnswer((_) async => null);

      final result = await useCase(999, 'Nuevo nombre');

      expect(result, isFalse);
      verifyNever(() => mockRepository.updateDocument(any()));
    });

    test('error en BD → retorna false', () async {
      when(() => mockRepository.getDocumentById(1))
          .thenAnswer((_) async => testDoc);
      when(() => mockRepository.updateDocument(any()))
          .thenThrow(Exception('DB error'));

      final result = await useCase(1, 'Nuevo nombre');

      expect(result, isFalse);
    });
  });
}
