import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:escandoc/features/documents/presentation/pages/ocr_fullscreen_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildWidget({String? ocrText}) {
    return MaterialApp(
      home: OcrFullscreenPage(ocrText: ocrText),
    );
  }

  group('OcrFullscreenPage', () {
    testWidgets('debe mostrar texto OCR en TextField', (tester) async {
      const ocrText = 'Texto extraído del documento';

      await tester.pumpWidget(buildWidget(ocrText: ocrText));
      await tester.pumpAndSettle();

      // Debe mostrar el texto en el TextField
      expect(find.text(ocrText), findsOneWidget);

      // El TextField debe ser de solo lectura
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.readOnly, true);
    });

    testWidgets('debe mostrar botón copiar cuando hay texto', (tester) async {
      await tester.pumpWidget(buildWidget(ocrText: 'Texto de prueba'));
      await tester.pumpAndSettle();

      // Debe mostrar botón copiar en AppBar
      expect(find.byIcon(Icons.copy), findsAtLeastNWidgets(1));
    });

    testWidgets('NO debe mostrar botón copiar cuando no hay texto', (tester) async {
      await tester.pumpWidget(buildWidget(ocrText: null));
      await tester.pumpAndSettle();

      // NO debe mostrar el botón grande de copiar
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('debe mostrar snackbar al presionar botón copiar', (tester) async {
      const ocrText = 'Texto a copiar';

      await tester.pumpWidget(buildWidget(ocrText: ocrText));

      // Tocar el botón copiar en el AppBar
      await tester.tap(find.byIcon(Icons.copy).first);
      await tester.pumpAndSettle();

      // Verificar que se muestra el snackbar de confirmación
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('debe tener scrollbar visible', (tester) async {
      await tester.pumpWidget(buildWidget(ocrText: 'Texto largo'));
      await tester.pumpAndSettle();

      // Debe tener Scrollbar
      expect(find.byType(Scrollbar), findsOneWidget);

      // Verificar que thumbVisibility está en true
      final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));
      expect(scrollbar.thumbVisibility, true);
    });

    testWidgets('debe mostrar botón volver en AppBar', (tester) async {
      await tester.pumpWidget(buildWidget(ocrText: 'test'));
      await tester.pumpAndSettle();

      // Debe mostrar botón volver
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });
}
