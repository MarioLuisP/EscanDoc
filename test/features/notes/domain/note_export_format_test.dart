import 'package:flutter_test/flutter_test.dart';
import 'package:escandoc/features/notes/domain/note_export_format.dart';

void main() {
  group('noteShareFormatFor', () {
    test('nota corta se comparte como imagen pergamino', () {
      expect(noteShareFormatFor('nota breve'), NoteShareFormat.parchmentImage);
    });

    test('nota vacía se comparte como imagen', () {
      expect(noteShareFormatFor(''), NoteShareFormat.parchmentImage);
    });

    test('nota justo en el tope (1500) sigue siendo imagen', () {
      final text = 'a' * kNoteParchmentMaxChars;
      expect(text.length, 1500);
      expect(noteShareFormatFor(text), NoteShareFormat.parchmentImage);
    });

    test('nota que pasa el tope (1501) se comparte como PDF paginado', () {
      final text = 'a' * (kNoteParchmentMaxChars + 1);
      expect(noteShareFormatFor(text), NoteShareFormat.paginatedPdf);
    });

    test('nota muy larga se comparte como PDF paginado', () {
      final text = 'a' * 8000;
      expect(noteShareFormatFor(text), NoteShareFormat.paginatedPdf);
    });
  });
}
