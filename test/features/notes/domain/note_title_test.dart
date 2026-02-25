import 'package:flutter_test/flutter_test.dart';
import 'package:escandoc/features/notes/domain/note_title.dart';

void main() {
  group('NoteTitle.generate', () {
    final fixedDate = DateTime(2026, 2, 25);

    test('toma las primeras 5 palabras del texto', () {
      expect(
        NoteTitle.generate('Hola mundo como estás hoy amigo', fixedDate),
        'Hola mundo como estás hoy',
      );
    });

    test('retorna texto completo si tiene menos de 5 palabras', () {
      expect(NoteTitle.generate('Solo tres palabras', fixedDate), 'Solo tres palabras');
    });

    test('retorna texto completo si tiene exactamente 5 palabras', () {
      expect(NoteTitle.generate('Una dos tres cuatro cinco', fixedDate), 'Una dos tres cuatro cinco');
    });

    test('retorna "Nota {dia} {mes}" si el texto está vacío', () {
      expect(NoteTitle.generate('', fixedDate), 'Nota 25 feb');
    });

    test('retorna "Nota {dia} {mes}" si el texto es solo espacios', () {
      expect(NoteTitle.generate('   ', fixedDate), 'Nota 25 feb');
    });

    test('ignora espacios extra al inicio y fin', () {
      expect(NoteTitle.generate('  Hola mundo  ', fixedDate), 'Hola mundo');
    });

    test('mes en español abreviado', () {
      expect(NoteTitle.generate('', DateTime(2026, 12, 1)), 'Nota 1 dic');
      expect(NoteTitle.generate('', DateTime(2026, 1, 15)), 'Nota 15 ene');
      expect(NoteTitle.generate('', DateTime(2026, 6, 10)), 'Nota 10 jun');
    });
  });
}
