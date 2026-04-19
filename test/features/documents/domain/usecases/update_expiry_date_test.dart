import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:escandoc/features/documents/domain/usecases/update_expiry_date.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';

class MockDocumentRepository extends Mock implements DocumentRepository {}

void main() {
  late UpdateExpiryDate useCase;
  late MockDocumentRepository mockRepository;

  final today = DateTime.now();
  final tomorrow = DateTime(today.year, today.month, today.day + 1);
  final yesterday = DateTime(today.year, today.month, today.day - 1);

  final testDoc = DocumentModel(
    id: 1,
    title: 'DNI',
    filePath: '/test/dni.jpg',
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    mockRepository = MockDocumentRepository();
    useCase = UpdateExpiryDate(repository: mockRepository);
  });

  group('UpdateExpiryDate', () {
    group('fecha válida (futura)', () {
      test('asigna fecha de vencimiento y retorna true', () async {
        when(() => mockRepository.getDocumentById(1))
            .thenAnswer((_) async => testDoc);
        when(() => mockRepository.updateExpiryDate(1, any()))
            .thenAnswer((_) async {});

        final result = await useCase(1, tomorrow);

        expect(result, isTrue);
        verify(() => mockRepository.updateExpiryDate(1, tomorrow)).called(1);
      });

      test('acepta la fecha de hoy', () async {
        final todayOnly = DateTime(today.year, today.month, today.day);
        when(() => mockRepository.getDocumentById(1))
            .thenAnswer((_) async => testDoc);
        when(() => mockRepository.updateExpiryDate(1, any()))
            .thenAnswer((_) async {});

        final result = await useCase(1, todayOnly);

        expect(result, isTrue);
      });
    });

    group('fecha pasada', () {
      test('lanza ArgumentError sin llamar al repositorio', () async {
        expect(
          () => useCase(1, yesterday),
          throwsA(isA<ArgumentError>()),
        );

        verifyNever(() => mockRepository.getDocumentById(any()));
        verifyNever(() => mockRepository.updateExpiryDate(any(), any()));
      });
    });

    group('quitar vencimiento (null)', () {
      test('null → llama updateExpiryDate con null y retorna true', () async {
        when(() => mockRepository.getDocumentById(1))
            .thenAnswer((_) async => testDoc);
        when(() => mockRepository.updateExpiryDate(1, null))
            .thenAnswer((_) async {});

        final result = await useCase(1, null);

        expect(result, isTrue);
        verify(() => mockRepository.updateExpiryDate(1, null)).called(1);
      });
    });

    group('documento no existe', () {
      test('retorna false sin llamar updateExpiryDate', () async {
        when(() => mockRepository.getDocumentById(999))
            .thenAnswer((_) async => null);

        final result = await useCase(999, tomorrow);

        expect(result, isFalse);
        verifyNever(() => mockRepository.updateExpiryDate(any(), any()));
      });
    });

    group('error en repositorio', () {
      test('retorna false si updateExpiryDate lanza excepción', () async {
        when(() => mockRepository.getDocumentById(1))
            .thenAnswer((_) async => testDoc);
        when(() => mockRepository.updateExpiryDate(1, any()))
            .thenThrow(Exception('DB error'));

        final result = await useCase(1, tomorrow);

        expect(result, isFalse);
      });
    });
  });
}
