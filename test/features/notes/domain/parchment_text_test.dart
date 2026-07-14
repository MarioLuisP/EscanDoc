import 'package:flutter_test/flutter_test.dart';
import 'package:escandoc/features/notes/domain/parchment_text.dart';

void main() {
  group('ParchmentText.softenAllCaps', () {
    test('capitaliza una palabra entera en mayúscula', () {
      expect(ParchmentText.softenAllCaps('URGENTE'), 'Urgente');
    });

    test('capitaliza acrónimos cortos (DNI → Dni), por decisión de producto', () {
      expect(ParchmentText.softenAllCaps('DNI'), 'Dni');
      expect(ParchmentText.softenAllCaps('PAMI'), 'Pami');
      expect(ParchmentText.softenAllCaps('OSDE'), 'Osde');
    });

    test('solo toca las palabras en mayúscula, el resto queda igual', () {
      expect(
        ParchmentText.softenAllCaps('pagar la factura URGENTE hoy'),
        'pagar la factura Urgente hoy',
      );
    });

    test('no toca palabras normales ni con mayúscula inicial', () {
      expect(ParchmentText.softenAllCaps('Hola mundo'), 'Hola mundo');
      expect(ParchmentText.softenAllCaps('iPhone'), 'iPhone');
    });

    test('respeta acentos y Ñ del español', () {
      expect(ParchmentText.softenAllCaps('AÑO'), 'Año');
      expect(ParchmentText.softenAllCaps('ÁRBOL'), 'Árbol');
      expect(ParchmentText.softenAllCaps('ATENCIÓN'), 'Atención');
    });

    test('preserva signos de puntuación alrededor', () {
      expect(ParchmentText.softenAllCaps('¡URGENTE!'), '¡Urgente!');
      expect(ParchmentText.softenAllCaps('OSDE.'), 'Osde.');
      expect(ParchmentText.softenAllCaps('DNI/CUIT'), 'Dni/Cuit');
    });

    test('no toca números ni palabras con dígitos pegados a letras', () {
      expect(ParchmentText.softenAllCaps('12345'), '12345');
      expect(ParchmentText.softenAllCaps('DNI 12345'), 'Dni 12345');
    });

    test('preserva saltos de línea y capitaliza en cada línea', () {
      expect(ParchmentText.softenAllCaps('PAGAR\nLUZ'), 'Pagar\nLuz');
    });

    test('una sola letra en mayúscula queda igual', () {
      expect(ParchmentText.softenAllCaps('A'), 'A');
    });

    test('texto vacío no rompe', () {
      expect(ParchmentText.softenAllCaps(''), '');
    });
  });
}
