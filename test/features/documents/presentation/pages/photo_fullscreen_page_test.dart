import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:escandoc/features/documents/presentation/pages/photo_fullscreen_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildWidget({required String filePath}) {
    return MaterialApp(
      home: PhotoFullscreenPage(filePath: filePath),
    );
  }

  group('PhotoFullscreenPage', () {
    testWidgets('debe mostrar AppBar con fondo negro', (tester) async {
      await tester.pumpWidget(buildWidget(filePath: 'test.pdf'));

      // Debe tener AppBar
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, Colors.black);
    });

    testWidgets('debe mostrar botón cerrar en AppBar', (tester) async {
      await tester.pumpWidget(buildWidget(filePath: 'test.pdf'));

      // Debe mostrar botón cerrar
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('debe mostrar botón compartir en AppBar', (tester) async {
      await tester.pumpWidget(buildWidget(filePath: 'test.pdf'));

      // Debe mostrar botón compartir
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('debe tener fondo negro en Scaffold', (tester) async {
      await tester.pumpWidget(buildWidget(filePath: 'test.pdf'));

      // Verificar que el Scaffold tiene fondo negro
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.black);
    });
  });
}
