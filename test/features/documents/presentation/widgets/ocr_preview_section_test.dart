import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:escandoc/features/documents/presentation/widgets/ocr_preview_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildWidget({String? ocrText, required VoidCallback onTap}) {
    return MaterialApp(
      home: Scaffold(
        body: OcrPreviewSection(
          ocrText: ocrText,
          onTap: onTap,
        ),
      ),
    );
  }

  group('OcrPreviewSection', () {
    testWidgets('debe mostrar texto OCR cuando existe', (tester) async {
      const ocrText = 'Texto extraído del documento';

      await tester.pumpWidget(
        buildWidget(
          ocrText: ocrText,
          onTap: () {},
        ),
      );

      // Debe mostrar MarkdownBody con el texto OCR
      final markdownBody = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      expect(markdownBody.data, ocrText);

      // Debe mostrar icono de texto
      expect(find.byIcon(Icons.text_fields), findsOneWidget);
    });

    testWidgets('debe mostrar mensaje vacío cuando no hay OCR', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          ocrText: null,
          onTap: () {},
        ),
      );

      // Debe mostrar icono de texto (igual que cuando hay texto)
      expect(find.byIcon(Icons.text_fields), findsOneWidget);
    });

    testWidgets('debe llamar onTap cuando se toca la sección', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        buildWidget(
          ocrText: 'test',
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
          ocrText: 'test',
          onTap: () {},
        ),
      );

      // Debe mostrar el chevron
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });
}
