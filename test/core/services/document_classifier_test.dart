import 'package:flutter_test/flutter_test.dart';
import 'package:escandoc/core/services/document_classifier.dart';

void main() {
  late DocumentClassifier classifier;

  setUp(() {
    classifier = DocumentClassifier();
  });

  group('DocumentClassifier - detectType', () {
    test('debe detectar "factura" con keywords correctas', () {
      final result1 = classifier.detectType('Este es un texto con FACTURA número 123');
      final result2 = classifier.detectType('INVOICE for services rendered');

      expect(result1, 'factura');
      expect(result2, 'factura');
    });

    test('debe detectar "recibo" con keywords correctas', () {
      final result1 = classifier.detectType('RECIBO de pago mensual');
      final result2 = classifier.detectType('Payment RECEIPT attached');

      expect(result1, 'recibo');
      expect(result2, 'recibo');
    });

    test('debe detectar "contrato" con keywords correctas', () {
      final result1 = classifier.detectType('CONTRATO de alquiler vigente');
      final result2 = classifier.detectType('This is a legal CONTRACT document');

      expect(result1, 'contrato');
      expect(result2, 'contrato');
    });

    test('debe detectar "médico" con keywords correctas', () {
      final result1 = classifier.detectType('Informe MÉDICO del paciente');
      final result2 = classifier.detectType('MEDICAL report for consultation');
      final result3 = classifier.detectType('CONSULTA médica realizada');
      final result4 = classifier.detectType('PRESCRIPTION for medication');

      expect(result1, 'médico');
      expect(result2, 'médico');
      expect(result3, 'médico');
      expect(result4, 'médico');
    });

    test('debe retornar "documento" por default', () {
      final result1 = classifier.detectType('Este es un texto sin palabras clave');
      final result2 = classifier.detectType('');
      final result3 = classifier.detectType('Random text here');

      expect(result1, 'documento');
      expect(result2, 'documento');
      expect(result3, 'documento');
    });

    test('debe ser case-insensitive', () {
      final result1 = classifier.detectType('factura');
      final result2 = classifier.detectType('FACTURA');
      final result3 = classifier.detectType('FaCtuRa');

      expect(result1, 'factura');
      expect(result2, 'factura');
      expect(result3, 'factura');
    });
  });

  group('DocumentClassifier - generateDocumentName', () {
    test('debe generar nombre ES: "factura_25_Ene_2026"', () {
      final date = DateTime(2026, 1, 25);
      final result = classifier.generateDocumentName('factura', date, 'es');

      expect(result, 'factura_25_Ene_2026');
    });

    test('debe generar nombre EN: "invoice_25_Jan_2026"', () {
      final date = DateTime(2026, 1, 25);
      final result = classifier.generateDocumentName('factura', date, 'en');

      expect(result, 'invoice_25_Jan_2026');
    });

    test('debe generar nombres correctos para todos los tipos en ES', () {
      final date = DateTime(2026, 2, 10);

      expect(classifier.generateDocumentName('factura', date, 'es'), 'factura_10_Feb_2026');
      expect(classifier.generateDocumentName('recibo', date, 'es'), 'recibo_10_Feb_2026');
      expect(classifier.generateDocumentName('contrato', date, 'es'), 'contrato_10_Feb_2026');
      expect(classifier.generateDocumentName('médico', date, 'es'), 'médico_10_Feb_2026');
      expect(classifier.generateDocumentName('documento', date, 'es'), 'documento_10_Feb_2026');
    });

    test('debe generar nombres correctos para todos los tipos en EN', () {
      final date = DateTime(2026, 3, 15);

      expect(classifier.generateDocumentName('factura', date, 'en'), 'invoice_15_Mar_2026');
      expect(classifier.generateDocumentName('recibo', date, 'en'), 'receipt_15_Mar_2026');
      expect(classifier.generateDocumentName('contrato', date, 'en'), 'contract_15_Mar_2026');
      expect(classifier.generateDocumentName('médico', date, 'en'), 'medical_15_Mar_2026');
      expect(classifier.generateDocumentName('documento', date, 'en'), 'document_15_Mar_2026');
    });

    test('debe usar meses correctos en español', () {
      expect(classifier.generateDocumentName('factura', DateTime(2026, 1, 1), 'es'), 'factura_1_Ene_2026');
      expect(classifier.generateDocumentName('factura', DateTime(2026, 6, 30), 'es'), 'factura_30_Jun_2026');
      expect(classifier.generateDocumentName('factura', DateTime(2026, 12, 31), 'es'), 'factura_31_Dic_2026');
    });

    test('debe usar meses correctos en inglés', () {
      expect(classifier.generateDocumentName('recibo', DateTime(2026, 1, 1), 'en'), 'receipt_1_Jan_2026');
      expect(classifier.generateDocumentName('recibo', DateTime(2026, 6, 30), 'en'), 'receipt_30_Jun_2026');
      expect(classifier.generateDocumentName('recibo', DateTime(2026, 12, 31), 'en'), 'receipt_31_Dec_2026');
    });
  });

  group('DocumentClassifier - extractDueDate', () {
    test('debe extraer fecha DD/MM/YYYY', () {
      final result1 = classifier.extractDueDate('Vencimiento: 15/02/2026');
      final result2 = classifier.extractDueDate('Pagar antes de: 31/12/2026');

      expect(result1, DateTime(2026, 2, 15));
      expect(result2, DateTime(2026, 12, 31));
    });

    test('debe extraer fecha DD-MM-YYYY', () {
      final result = classifier.extractDueDate('Due date: 20-03-2026');

      expect(result, DateTime(2026, 3, 20));
    });

    test('debe extraer fecha YYYY-MM-DD', () {
      final result = classifier.extractDueDate('Vence: 2026-04-10');

      expect(result, DateTime(2026, 4, 10));
    });

    test('debe ignorar fechas pasadas', () {
      final result = classifier.extractDueDate('Vencimiento: 15/02/2020');

      expect(result, isNull);
    });

    test('debe retornar null si no encuentra fecha', () {
      final result1 = classifier.extractDueDate('Este texto no tiene fechas');
      final result2 = classifier.extractDueDate('');

      expect(result1, isNull);
      expect(result2, isNull);
    });

    test('debe reconocer diferentes keywords de vencimiento', () {
      final result1 = classifier.extractDueDate('vencimiento: 15/06/2026');
      final result2 = classifier.extractDueDate('vence: 20/06/2026');
      final result3 = classifier.extractDueDate('pagar antes de: 25/06/2026');
      final result4 = classifier.extractDueDate('due date: 30/06/2026');

      expect(result1, DateTime(2026, 6, 15));
      expect(result2, DateTime(2026, 6, 20));
      expect(result3, DateTime(2026, 6, 25));
      expect(result4, DateTime(2026, 6, 30));
    });
  });
}
