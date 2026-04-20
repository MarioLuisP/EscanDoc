import 'package:flutter_test/flutter_test.dart';
import 'package:escandoc/features/notes/domain/note_marker.dart';

void main() {
  group('NoteMarker.isDefault', () {
    test('retorna true si el contenido empieza con el marker', () {
      expect(NoteMarker.isDefault('\u200BTexto OCR'), isTrue);
    });

    test('retorna false si el contenido no tiene marker', () {
      expect(NoteMarker.isDefault('Texto editado por usuario'), isFalse);
    });

    test('retorna false si el contenido es null', () {
      expect(NoteMarker.isDefault(null), isFalse);
    });

    test('retorna false si el contenido es vacío', () {
      expect(NoteMarker.isDefault(''), isFalse);
    });

    test('retorna false si el marker está en el medio', () {
      expect(NoteMarker.isDefault('Texto\u200BOtro'), isFalse);
    });
  });

  group('NoteMarker.strip', () {
    test('elimina el marker del inicio', () {
      expect(NoteMarker.strip('\u200BTexto OCR'), equals('Texto OCR'));
    });

    test('no modifica texto sin marker', () {
      expect(NoteMarker.strip('Texto normal'), equals('Texto normal'));
    });

    test('no elimina marker en el medio', () {
      expect(NoteMarker.strip('Texto\u200BOtro'), equals('Texto\u200BOtro'));
    });

    test('retorna vacío si solo era el marker', () {
      expect(NoteMarker.strip('\u200B'), equals(''));
    });
  });

  group('NoteMarker.mark', () {
    test('agrega el marker al inicio del contenido', () {
      expect(NoteMarker.mark('Texto OCR'), equals('\u200BTexto OCR'));
    });

    test('no duplica el marker si ya lo tiene', () {
      expect(NoteMarker.mark('\u200BTexto'), equals('\u200BTexto'));
    });

    test('funciona con string vacío', () {
      expect(NoteMarker.mark(''), equals('\u200B'));
    });
  });
}
