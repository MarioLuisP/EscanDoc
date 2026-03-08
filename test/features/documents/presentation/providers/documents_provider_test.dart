import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';
import 'package:escandoc/features/documents/presentation/providers/documents_provider.dart';

class MockDocumentRepository extends Mock implements DocumentRepository {}

void main() {
  late MockDocumentRepository repository;
  late DocumentsProvider provider;

  final doc1 = DocumentModel(
    id: 1,
    title: 'Factura',
    filePath: '/docs/factura.jpg',
    createdAt: DateTime(2026, 1, 1),
  );
  final doc2 = DocumentModel(
    id: 2,
    title: 'Recibo',
    filePath: '/docs/recibo.jpg',
    createdAt: DateTime(2026, 1, 2),
  );

  setUpAll(() {
    registerFallbackValue(doc1);
  });

  setUp(() {
    repository = MockDocumentRepository();
    provider = DocumentsProvider(repository: repository);
  });

  group('loadDocuments', () {
    test('populates documents on success', () async {
      when(() => repository.getAllDocuments()).thenAnswer((_) async => [doc1, doc2]);

      await provider.loadDocuments();

      expect(provider.documents, [doc1, doc2]);
      expect(provider.isLoading, false);
      expect(provider.errorMessage, isNull);
    });

    test('retorna lista vacía sin error cuando el repo falla (GetDocuments fail-safe)', () async {
      when(() => repository.getAllDocuments()).thenThrow(Exception('DB error'));

      await provider.loadDocuments();

      // GetDocuments tiene try-catch propio → retorna [] sin propagar el error
      expect(provider.documents, isEmpty);
      expect(provider.errorMessage, isNull);
      expect(provider.isLoading, false);
    });
  });

  group('selectDocument', () {
    test('sets selectedDocument on success', () async {
      when(() => repository.getDocumentById(1)).thenAnswer((_) async => doc1);

      await provider.selectDocument(1);

      expect(provider.selectedDocument, doc1);
      expect(provider.errorMessage, isNull);
    });

    test('sets errorMessage when document not found', () async {
      when(() => repository.getDocumentById(99)).thenAnswer((_) async => null);

      await provider.selectDocument(99);

      expect(provider.selectedDocument, isNull);
      expect(provider.errorMessage, isNotNull);
    });
  });

  group('deleteDocument', () {
    test('removes document from list on success', () async {
      when(() => repository.getAllDocuments()).thenAnswer((_) async => [doc1, doc2]);
      when(() => repository.deleteDocument(1)).thenAnswer((_) async => true);

      await provider.loadDocuments();
      final result = await provider.deleteDocument(1);

      expect(result, true);
      expect(provider.documents.length, 1);
      expect(provider.documents.first.id, 2);
    });

    test('clears selectedDocument if it was the deleted one', () async {
      when(() => repository.getAllDocuments()).thenAnswer((_) async => [doc1]);
      when(() => repository.getDocumentById(1)).thenAnswer((_) async => doc1);
      when(() => repository.deleteDocument(1)).thenAnswer((_) async => true);

      await provider.loadDocuments();
      await provider.selectDocument(1);
      expect(provider.selectedDocument?.id, 1);

      await provider.deleteDocument(1);

      expect(provider.selectedDocument, isNull);
    });

    test('returns false and keeps list when delete fails', () async {
      when(() => repository.getAllDocuments()).thenAnswer((_) async => [doc1]);
      when(() => repository.deleteDocument(1)).thenAnswer((_) async => false);

      await provider.loadDocuments();
      final result = await provider.deleteDocument(1);

      expect(result, false);
      expect(provider.documents.length, 1);
    });
  });

  group('renameDocument', () {
    test('updates title in list and selectedDocument', () async {
      when(() => repository.getAllDocuments()).thenAnswer((_) async => [doc1]);
      when(() => repository.getDocumentById(1)).thenAnswer((_) async => doc1);
      when(() => repository.updateDocument(any())).thenAnswer((_) async => 1);

      await provider.loadDocuments();
      await provider.selectDocument(1);
      final result = await provider.renameDocument(1, 'Nuevo título');

      expect(result, true);
      expect(provider.documents.first.title, 'Nuevo título');
      expect(provider.selectedDocument?.title, 'Nuevo título');
    });

    test('returns false for empty title without calling repository', () async {
      final result = await provider.renameDocument(1, '   ');

      expect(result, false);
      verifyNever(() => repository.updateDocument(any()));
    });
  });

  group('updateNote', () {
    test('updates noteContent in list and selectedDocument', () async {
      when(() => repository.getAllDocuments()).thenAnswer((_) async => [doc1]);
      when(() => repository.getDocumentById(1)).thenAnswer((_) async => doc1);
      when(() => repository.updateNote(any(), any())).thenAnswer((_) async {});

      await provider.loadDocuments();
      await provider.selectDocument(1);
      final result = await provider.updateNote(1, 'mi nota');

      expect(result, true);
      expect(provider.documents.first.noteContent, 'mi nota');
      expect(provider.selectedDocument?.noteContent, 'mi nota');
    });

    test('sets errorMessage on exception', () async {
      when(() => repository.updateNote(any(), any())).thenThrow(Exception('error'));

      final result = await provider.updateNote(1, 'nota');

      expect(result, false);
      expect(provider.errorMessage, isNotNull);
    });
  });

  group('clearSelectedDocument', () {
    test('clears selectedDocument', () async {
      when(() => repository.getDocumentById(1)).thenAnswer((_) async => doc1);
      await provider.selectDocument(1);
      expect(provider.selectedDocument, isNotNull);

      provider.clearSelectedDocument();

      expect(provider.selectedDocument, isNull);
    });
  });

  group('clearError', () {
    test('clears errorMessage', () async {
      // selectDocument con doc inexistente → sets errorMessage vía null check
      when(() => repository.getDocumentById(99)).thenAnswer((_) async => null);
      await provider.selectDocument(99);
      expect(provider.errorMessage, isNotNull);

      provider.clearError();

      expect(provider.errorMessage, isNull);
    });
  });
}
