import 'dart:convert';
import 'dart:io';
import 'package:escandoc/core/services/blocks_to_markdown.dart';

/// Carga un fixture JSON desde test/fixtures/ y retorna List<OcrBlock>.
/// El nombre no incluye el prefijo "fixture_" ni la extensión ".json".
/// Ejemplo: loadFixture('horario') → lee fixture_horario.json
List<OcrBlock> loadFixture(String name) {
  final file = File('test/fixtures/fixture_$name.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return (json['blocks'] as List).map((b) {
    final lines = (b['lines'] as List).map((l) {
      final bbox = l['bbox'] as Map<String, dynamic>;
      return OcrLine(
        text:   l['text'] as String,
        left:   (bbox['left']   as num).toDouble(),
        top:    (bbox['top']    as num).toDouble(),
        right:  (bbox['right']  as num).toDouble(),
        bottom: (bbox['bottom'] as num).toDouble(),
      );
    }).toList();
    return OcrBlock(lines: lines);
  }).toList();
}

/// Compara [actual] con el golden file en test/fixtures/golden/[name].md.
/// Si el golden no existe lo crea (primera corrida).
/// Para actualizar un golden: borrar el archivo y correr el test de nuevo.
void expectMatchesGolden(String name, String actual) {
  final goldenFile = File('test/fixtures/golden/$name.md');
  if (!goldenFile.existsSync()) {
    goldenFile.createSync(recursive: true);
    goldenFile.writeAsStringSync(actual);
    // ignore: avoid_print
    print('[golden] Creado: ${goldenFile.path}');
    return;
  }
  final expected = goldenFile.readAsStringSync();
  if (actual != expected) {
    throw TestFailure(
      'Golden mismatch para "$name".\n'
      'Para actualizar: borrar test/fixtures/golden/$name.md y correr de nuevo.\n'
      '--- ESPERADO ---\n$expected\n'
      '--- ACTUAL ---\n$actual',
    );
  }
}

class TestFailure implements Exception {
  final String message;
  TestFailure(this.message);
  @override
  String toString() => message;
}
