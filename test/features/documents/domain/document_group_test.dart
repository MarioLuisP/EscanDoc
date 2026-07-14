import 'package:flutter_test/flutter_test.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/domain/document_group.dart';

/// Helper: crea un DocumentModel mínimo con título y createdAt controlados.
DocumentModel _doc({
  required int id,
  required String title,
  required DateTime createdAt,
}) {
  return DocumentModel(
    id: id,
    title: title,
    filePath: '/tmp/$id.jpg',
    createdAt: createdAt,
  );
}

void main() {
  // Instante base de una ráfaga de import. Las páginas de un mismo PDF comparten
  // baseTime + offset de milisegundos (verificado en device: ~9ms para 10 págs).
  final burst = DateTime(2026, 7, 14, 10, 0, 0);

  group('DocumentGroup.baseOf', () {
    test('extrae el prefijo de un título con patrón base_N', () {
      expect(DocumentGroup.baseOf('tutorial_1'), 'tutorial');
      expect(DocumentGroup.baseOf('tutorial_10'), 'tutorial');
      expect(DocumentGroup.baseOf('mi_doc_3'), 'mi_doc');
    });

    test('devuelve null si el título no termina en _N', () {
      expect(DocumentGroup.baseOf('tutorial'), isNull);
      expect(DocumentGroup.baseOf('recibo_luz'), isNull);
      expect(DocumentGroup.baseOf('doc_'), isNull);
      expect(DocumentGroup.baseOf('123'), isNull);
    });
  });

  group('DocumentGroup.pageNumberOf', () {
    test('extrae el número de página de un título base_N', () {
      expect(DocumentGroup.pageNumberOf('tutorial_1'), 1);
      expect(DocumentGroup.pageNumberOf('tutorial_10'), 10);
      expect(DocumentGroup.pageNumberOf('mi_doc_3'), 3);
    });

    test('devuelve null si el título no termina en _N', () {
      expect(DocumentGroup.pageNumberOf('tutorial'), isNull);
      expect(DocumentGroup.pageNumberOf('recibo_luz'), isNull);
    });
  });

  group('DocumentGroup.membersOf — solitarios', () {
    test('título sin patrón _N devuelve solo el propio documento', () {
      final solo = _doc(id: 1, title: 'recibo_luz', createdAt: burst);
      final all = [solo];

      expect(DocumentGroup.membersOf(all, solo), [solo]);
      expect(DocumentGroup.isGrouped(all, solo), false);
    });

    test('patrón _N pero sin hermanos en la lista devuelve solo el propio', () {
      final solo = _doc(id: 1, title: 'informe_2024', createdAt: burst);
      final all = [
        solo,
        _doc(id: 2, title: 'otra_cosa', createdAt: burst),
      ];

      expect(DocumentGroup.membersOf(all, solo), [solo]);
      expect(DocumentGroup.isGrouped(all, solo), false);
    });
  });

  group('DocumentGroup.membersOf — grupo real', () {
    test('agrupa las páginas del mismo import (misma base + ventana)', () {
      final p1 = _doc(id: 1, title: 'tutorial_1', createdAt: burst);
      final p2 = _doc(
          id: 2, title: 'tutorial_2', createdAt: burst.add(const Duration(milliseconds: 3)));
      final p3 = _doc(
          id: 3, title: 'tutorial_3', createdAt: burst.add(const Duration(milliseconds: 7)));
      final all = [p1, p2, p3];

      final members = DocumentGroup.membersOf(all, p2);

      expect(members.length, 3);
      expect(members, containsAll([p1, p2, p3]));
      expect(DocumentGroup.isGrouped(all, p2), true);
    });

    test('devuelve las páginas ordenadas por número, sin importar el orden de entrada', () {
      final p1 = _doc(id: 1, title: 'tutorial_1', createdAt: burst);
      final p2 = _doc(
          id: 2, title: 'tutorial_2', createdAt: burst.add(const Duration(milliseconds: 3)));
      final p10 = _doc(
          id: 10, title: 'tutorial_10', createdAt: burst.add(const Duration(milliseconds: 9)));
      // Entrada desordenada + numérico (no lexicográfico: 10 va después de 2).
      final all = [p10, p2, p1];

      final members = DocumentGroup.membersOf(all, p1);

      expect(members, [p1, p2, p10]);
    });
  });

  group('DocumentGroup.membersOf — no fusiona imports distintos', () {
    test('misma base pero fuera de la ventana de tiempo NO se agrupa', () {
      final hoy1 = _doc(id: 1, title: 'cosa_1', createdAt: burst);
      final hoy2 = _doc(
          id: 2, title: 'cosa_2', createdAt: burst.add(const Duration(milliseconds: 5)));
      // Mismo prefijo "cosa" pero otro día → import distinto.
      final otroDia = _doc(
          id: 3, title: 'cosa_3', createdAt: burst.add(const Duration(days: 1)));
      final all = [hoy1, hoy2, otroDia];

      // El grupo de hoy no arrastra al doc de otro día.
      expect(DocumentGroup.membersOf(all, hoy1), containsAll([hoy1, hoy2]));
      expect(DocumentGroup.membersOf(all, hoy1), isNot(contains(otroDia)));

      // Y el doc de otro día queda solitario respecto de la ráfaga de hoy.
      expect(DocumentGroup.membersOf(all, otroDia), [otroDia]);
      expect(DocumentGroup.isGrouped(all, otroDia), false);
    });
  });
}
