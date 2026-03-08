import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/search/data/models/search_result.dart';
import 'package:escandoc/features/search/domain/usecases/search_documents.dart';
import 'package:escandoc/features/search/domain/usecases/voice_search.dart';
import 'package:escandoc/features/search/presentation/providers/search_provider.dart';

class MockSearchDocuments extends Mock implements SearchDocuments {}

class MockVoiceSearch extends Mock implements VoiceSearch {}

void main() {
  late MockSearchDocuments mockSearchDocuments;
  late MockVoiceSearch mockVoiceSearch;
  late SearchProvider provider;

  const testResult = SearchResult(
    id: 1,
    type: 'document',
    title: 'Factura enero',
    snippet: 'resultado de búsqueda',
  );

  setUp(() {
    mockSearchDocuments = MockSearchDocuments();
    mockVoiceSearch = MockVoiceSearch();
    provider = SearchProvider(
      searchDocuments: mockSearchDocuments,
      voiceSearch: mockVoiceSearch,
    );
  });

  tearDown(() {
    provider.dispose();
  });

  group('search', () {
    test('con menos de 3 caracteres limpia resultados sin buscar', () {
      provider.search('ab');

      expect(provider.isLoading, false);
      expect(provider.results, isEmpty);
      verifyNever(() => mockSearchDocuments.execute(any()));
    });

    test('con query vacío limpia resultados', () {
      provider.search('');

      expect(provider.isLoading, false);
      expect(provider.results, isEmpty);
    });

    test('con 3+ chars establece isLoading antes del debounce', () {
      when(() => mockSearchDocuments.execute(any())).thenAnswer((_) async => []);

      provider.search('abc');

      expect(provider.isLoading, true);
    });

    test('ejecuta búsqueda después del debounce y popula resultados', () {
      when(() => mockSearchDocuments.execute('abc'))
          .thenAnswer((_) async => [testResult]);

      fakeAsync((fake) {
        provider.search('abc');
        fake.elapse(const Duration(milliseconds: 350));
        fake.flushMicrotasks();

        verify(() => mockSearchDocuments.execute('abc')).called(1);
        expect(provider.results, [testResult]);
        expect(provider.isLoading, false);
      });
    });

    test('debounce cancela búsqueda anterior si cambia el query', () {
      when(() => mockSearchDocuments.execute(any())).thenAnswer((_) async => []);

      fakeAsync((fake) {
        provider.search('abc');
        fake.elapse(const Duration(milliseconds: 100));
        provider.search('abcd'); // reemplaza debounce
        fake.elapse(const Duration(milliseconds: 350));
        fake.flushMicrotasks();

        verify(() => mockSearchDocuments.execute('abcd')).called(1);
        verifyNever(() => mockSearchDocuments.execute('abc'));
      });
    });

    test('sets errorMessage en excepción durante búsqueda', () {
      when(() => mockSearchDocuments.execute(any())).thenThrow(Exception('error'));

      fakeAsync((fake) {
        provider.search('abc');
        fake.elapse(const Duration(milliseconds: 350));
        fake.flushMicrotasks();

        expect(provider.errorMessage, isNotNull);
        expect(provider.results, isEmpty);
        expect(provider.isLoading, false);
      });
    });
  });

  group('searchByVoice', () {
    test('ejecuta búsqueda con el texto reconocido', () async {
      when(() => mockVoiceSearch.execute()).thenAnswer((_) async => 'factura');
      when(() => mockSearchDocuments.execute('factura'))
          .thenAnswer((_) async => [testResult]);

      await provider.searchByVoice();

      expect(provider.query, 'factura');
      expect(provider.isListening, false);
      expect(provider.results, [testResult]);
      verify(() => mockSearchDocuments.execute('factura')).called(1);
    });

    test('sets error cuando no se reconoce texto', () async {
      when(() => mockVoiceSearch.execute()).thenAnswer((_) async => null);

      await provider.searchByVoice();

      expect(provider.errorMessage, isNotNull);
      expect(provider.isListening, false);
      verifyNever(() => mockSearchDocuments.execute(any()));
    });

    test('sets error en excepción de micrófono', () async {
      when(() => mockVoiceSearch.execute()).thenThrow(Exception('mic error'));

      await provider.searchByVoice();

      expect(provider.errorMessage, isNotNull);
      expect(provider.isListening, false);
    });
  });

  group('clearResults', () {
    test('resetea query, results, isLoading y cancela debounce', () {
      when(() => mockSearchDocuments.execute(any())).thenAnswer((_) async => []);

      fakeAsync((fake) {
        provider.search('abc');
        provider.clearResults();

        expect(provider.query, isEmpty);
        expect(provider.results, isEmpty);
        expect(provider.isLoading, false);

        // Timer cancelado — no debe ejecutar búsqueda
        fake.elapse(const Duration(milliseconds: 350));
        fake.flushMicrotasks();
        verifyNever(() => mockSearchDocuments.execute(any()));
      });
    });
  });

  group('clearError', () {
    test('limpia errorMessage', () async {
      when(() => mockVoiceSearch.execute()).thenAnswer((_) async => null);
      await provider.searchByVoice();
      expect(provider.errorMessage, isNotNull);

      provider.clearError();

      expect(provider.errorMessage, isNull);
    });
  });
}
