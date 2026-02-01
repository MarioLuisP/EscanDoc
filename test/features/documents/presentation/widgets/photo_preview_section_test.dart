import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:escandoc/features/documents/presentation/widgets/photo_preview_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildWidget({String? thumbnailPath, required VoidCallback onTap}) {
    return MaterialApp(
      home: Scaffold(
        body: PhotoPreviewSection(
          thumbnailPath: thumbnailPath,
          onTap: onTap,
        ),
      ),
    );
  }

  group('PhotoPreviewSection', () {
    testWidgets('debe mostrar placeholder cuando thumbnailPath es null', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          thumbnailPath: null,
          onTap: () {},
        ),
      );

      // Debe mostrar el icono de placeholder
      expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
    });

    testWidgets('debe llamar onTap cuando se toca la sección', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        buildWidget(
          thumbnailPath: 'test.jpg',
          onTap: () => tapped = true,
        ),
      );

      // Tocar la sección
      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      expect(tapped, true);
    });

    testWidgets('debe mostrar overlay con hint de zoom', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          thumbnailPath: 'test.jpg',
          onTap: () {},
        ),
      );

      // Debe mostrar el icono de zoom
      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
    });
  });
}
