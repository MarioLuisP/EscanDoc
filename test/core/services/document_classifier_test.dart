import 'package:flutter_test/flutter_test.dart';
import 'package:escandoc/core/services/document_classifier.dart';
import 'package:escandoc/features/image_processing/classification/domain/classification_result.dart';

void main() {
  late DocumentClassifier classifier;

  setUp(() {
    classifier = DocumentClassifier();
  });

  group('DocumentClassifier - detectType', () {
    test('debe detectar "factura" con keywords correctas', () {
      expect(classifier.detectType('Este es un texto con FACTURA número 123'), 'factura');
      expect(classifier.detectType('INVOICE for services rendered'), 'factura');
    });

    test('debe detectar "recibo" con keywords correctas', () {
      expect(classifier.detectType('RECIBO de pago mensual'), 'recibo');
      expect(classifier.detectType('Payment RECEIPT attached'), 'recibo');
    });

    test('debe detectar "contrato" con keywords correctas', () {
      expect(classifier.detectType('CONTRATO de alquiler vigente'), 'contrato');
      expect(classifier.detectType('This is a legal CONTRACT document'), 'contrato');
    });

    test('debe detectar "médico" con keywords correctas', () {
      expect(classifier.detectType('Informe MÉDICO del paciente'), 'médico');
      expect(classifier.detectType('MEDICAL report for consultation'), 'médico');
      expect(classifier.detectType('CONSULTA médica realizada'), 'médico');
      expect(classifier.detectType('PRESCRIPTION for medication'), 'médico');
    });

    test('debe retornar "documento" por default', () {
      expect(classifier.detectType('Este es un texto sin palabras clave'), 'documento');
      expect(classifier.detectType(''), 'documento');
      expect(classifier.detectType('Random text here'), 'documento');
    });

    test('debe ser case-insensitive', () {
      expect(classifier.detectType('factura'), 'factura');
      expect(classifier.detectType('FACTURA'), 'factura');
      expect(classifier.detectType('FaCtuRa'), 'factura');
    });
  });

  group('DocumentClassifier - getTypeDisplayName', () {
    test('español: tipos principales', () {
      expect(classifier.getTypeDisplayName(DocumentType.factura, 'es'), 'Factura');
      expect(classifier.getTypeDisplayName(DocumentType.recibo, 'es'), 'Recibo');
      expect(classifier.getTypeDisplayName(DocumentType.manuscrito, 'es'), 'Nota');
      expect(classifier.getTypeDisplayName(DocumentType.folleto, 'es'), 'Folleto');
      expect(classifier.getTypeDisplayName(DocumentType.foto, 'es'), 'Foto');
      expect(classifier.getTypeDisplayName(DocumentType.documento, 'es'), 'Documento');
    });

    test('inglés: tipos principales', () {
      expect(classifier.getTypeDisplayName(DocumentType.factura, 'en'), 'Invoice');
      expect(classifier.getTypeDisplayName(DocumentType.recibo, 'en'), 'Receipt');
      expect(classifier.getTypeDisplayName(DocumentType.manuscrito, 'en'), 'Note');
      expect(classifier.getTypeDisplayName(DocumentType.folleto, 'en'), 'Brochure');
      expect(classifier.getTypeDisplayName(DocumentType.foto, 'en'), 'Photo');
      expect(classifier.getTypeDisplayName(DocumentType.documento, 'en'), 'Document');
    });

    test('manuscrito se muestra como Nota (no como Manuscrito)', () {
      expect(classifier.getTypeDisplayName(DocumentType.manuscrito, 'es'), 'Nota');
      expect(classifier.getTypeDisplayName(DocumentType.manuscrito, 'en'), 'Note');
    });
  });

  group('DocumentClassifier - generateDocumentName', () {
    test('formato ES: "Factura 1 del 17/2"', () {
      final date = DateTime(2026, 2, 17);
      expect(classifier.generateDocumentName(DocumentType.factura, date, 'es', 1), 'Factura 1 del 17/2');
    });

    test('formato EN: "Invoice 1 of 17/2"', () {
      final date = DateTime(2026, 2, 17);
      expect(classifier.generateDocumentName(DocumentType.factura, date, 'en', 1), 'Invoice 1 of 17/2');
    });

    test('número secuencial se refleja en el nombre', () {
      final date = DateTime(2026, 2, 17);
      expect(classifier.generateDocumentName(DocumentType.factura, date, 'es', 1), 'Factura 1 del 17/2');
      expect(classifier.generateDocumentName(DocumentType.factura, date, 'es', 2), 'Factura 2 del 17/2');
      expect(classifier.generateDocumentName(DocumentType.factura, date, 'es', 3), 'Factura 3 del 17/2');
    });

    test('manuscrito genera "Nota N del D/M"', () {
      final date = DateTime(2026, 11, 5);
      expect(classifier.generateDocumentName(DocumentType.manuscrito, date, 'es', 1), 'Nota 1 del 5/11');
      expect(classifier.generateDocumentName(DocumentType.manuscrito, date, 'en', 1), 'Note 1 of 5/11');
    });

    test('todos los tipos en ES', () {
      final date = DateTime(2026, 2, 17);
      expect(classifier.generateDocumentName(DocumentType.documento, date, 'es', 1), 'Documento 1 del 17/2');
      expect(classifier.generateDocumentName(DocumentType.factura, date, 'es', 1), 'Factura 1 del 17/2');
      expect(classifier.generateDocumentName(DocumentType.recibo, date, 'es', 1), 'Recibo 1 del 17/2');
      expect(classifier.generateDocumentName(DocumentType.manuscrito, date, 'es', 1), 'Nota 1 del 17/2');
      expect(classifier.generateDocumentName(DocumentType.folleto, date, 'es', 1), 'Folleto 1 del 17/2');
      expect(classifier.generateDocumentName(DocumentType.foto, date, 'es', 1), 'Foto 1 del 17/2');
    });

    test('todos los tipos en EN', () {
      final date = DateTime(2026, 2, 17);
      expect(classifier.generateDocumentName(DocumentType.documento, date, 'en', 1), 'Document 1 of 17/2');
      expect(classifier.generateDocumentName(DocumentType.factura, date, 'en', 1), 'Invoice 1 of 17/2');
      expect(classifier.generateDocumentName(DocumentType.recibo, date, 'en', 1), 'Receipt 1 of 17/2');
      expect(classifier.generateDocumentName(DocumentType.manuscrito, date, 'en', 1), 'Note 1 of 17/2');
      expect(classifier.generateDocumentName(DocumentType.folleto, date, 'en', 1), 'Brochure 1 of 17/2');
      expect(classifier.generateDocumentName(DocumentType.foto, date, 'en', 1), 'Photo 1 of 17/2');
    });
  });

  group('DocumentClassifier - extractDueDate', () {
    test('debe extraer fecha DD/MM/YYYY', () {
      expect(classifier.extractDueDate('Vencimiento: 15/03/2099'), DateTime(2099, 3, 15));
      expect(classifier.extractDueDate('Pagar antes de: 31/12/2099'), DateTime(2099, 12, 31));
    });

    test('debe extraer fecha DD-MM-YYYY', () {
      expect(classifier.extractDueDate('Due date: 20-03-2099'), DateTime(2099, 3, 20));
    });

    test('debe extraer fecha YYYY-MM-DD', () {
      expect(classifier.extractDueDate('Vence: 2099-04-10'), DateTime(2099, 4, 10));
    });

    test('debe ignorar fechas pasadas', () {
      expect(classifier.extractDueDate('Vencimiento: 15/02/2020'), isNull);
    });

    test('debe retornar null si no encuentra fecha', () {
      expect(classifier.extractDueDate('Este texto no tiene fechas'), isNull);
      expect(classifier.extractDueDate(''), isNull);
    });

    test('debe reconocer diferentes keywords de vencimiento', () {
      expect(classifier.extractDueDate('vencimiento: 15/06/2026'), DateTime(2026, 6, 15));
      expect(classifier.extractDueDate('vence: 20/06/2026'), DateTime(2026, 6, 20));
      expect(classifier.extractDueDate('pagar antes de: 25/06/2026'), DateTime(2026, 6, 25));
      expect(classifier.extractDueDate('due date: 30/06/2026'), DateTime(2026, 6, 30));
    });
  });
}
