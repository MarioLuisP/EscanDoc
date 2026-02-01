import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:escandoc/features/documents/presentation/widgets/note_preview_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildWidget({String? noteContent, required VoidCallback onTap}) {
    return MaterialApp(
      home: Scaffold(
        body: NotePreviewSection(
          noteContent: noteContent,
          onTap: onTap,
        ),
      ),
    );
  }

  group('NotePreviewSection', () {
    testWidgets('debe mostrar contenido de nota cuando existe', (tester) async {
      const noteText = 'Esta es mi nota importante';

      await tester.pumpWidget(
        buildWidget(
          noteContent: noteText,
          onTap: () {},
        ),
      );

      // Debe mostrar el texto de la nota
      expect(find.text(noteText), findsOneWidget);

      // Debe mostrar icono de nota
      expect(find.byIcon(Icons.note), findsOneWidget);
    });

    testWidgets('debe mostrar mensaje vacío cuando no hay nota', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          noteContent: null,
          onTap: () {},
        ),
      );

      // Debe mostrar icono de agregar nota
      expect(find.byIcon(Icons.note_add), findsOneWidget);
    });

    testWidgets('debe llamar onTap cuando se toca la sección', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        buildWidget(
          noteContent: 'test',
          onTap: () => tapped = true,
        ),
      );

      // Tocar la sección
      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      expect(tapped, true);
    });

    testWidgets('debe mostrar chevron indicador de navegación', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          noteContent: 'test',
          onTap: () {},
        ),
      );

      // Debe mostrar el chevron
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });
}
