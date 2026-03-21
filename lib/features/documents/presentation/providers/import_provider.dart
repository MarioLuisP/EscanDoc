import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:escandoc/features/documents/domain/services/pdf_import_service.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/image_processing/classification/domain/classification_result.dart';
import 'package:escandoc/core/services/document_pipeline.dart';

export 'package:escandoc/core/services/document_pipeline.dart' show PreparationResult;

/// Provider para manejar el flujo de importación de documentos.
///
/// Flujo optimizado en 2 fases:
/// 1. PREPARACIÓN: pipeline.prepare() (convert + classify + thumbnail)
/// 2. GUARDADO: pipeline.complete() (comprimir si foto + guardar BD) + OCR background
///
/// Funcionalidad exclusiva: importación de PDFs multi-página, tracking de
/// OCR simultáneos (_processingOcrIds) y mensajes de estado detallados.
class ImportProvider with ChangeNotifier {
  final DocumentPipeline _pipeline;
  final PdfImportService? _pdfImportService;

  ImportProvider({
    required DocumentPipeline pipeline,
    PdfImportService? pdfImportService,
  })  : _pipeline = pipeline,
        _pdfImportService = pdfImportService;

  // Estado
  bool _isImporting = false;
  bool _isSaving = false;
  bool _isProcessingOCR = false;
  String? _error;
  String? _statusMessage;
  DocumentModel? _lastImportedDocument;
  ClassificationResult? _lastClassification;

  // Estado PDF multi-página
  int _pdfCurrentPage = 0;
  int _pdfTotalPages = 0;

  // IDs de documentos con OCR en curso (soporta múltiples simultáneos)
  final Set<int> _processingOcrIds = {};

  // Getters
  bool get isImporting => _isImporting;
  bool get isSaving => _isSaving;
  bool get isProcessingOCR => _isProcessingOCR;
  bool get isBusy => _isImporting || _isSaving || _isProcessingOCR;
  String? get error => _error;
  String? get statusMessage => _statusMessage;
  DocumentModel? get lastImportedDocument => _lastImportedDocument;
  ClassificationResult? get lastClassification => _lastClassification;
  int get pdfCurrentPage => _pdfCurrentPage;
  int get pdfTotalPages => _pdfTotalPages;
  Set<int> get processingOcrIds => Set.unmodifiable(_processingOcrIds);

  /// FASE 1: Prepara documento importado (convert + classify + thumbnail).
  ///
  /// NO guarda en BD. Retorna resultado con clasificación para que la UI
  /// pueda decidir si continuar o cancelar.
  ///
  /// Retorna null si hay un error.
  Future<PreparationResult?> prepareImport(File importedFile) async {
    try {
      _error = null;
      _isImporting = true;
      _statusMessage = 'status_preparing';
      notifyListeners();

      final startTotal = DateTime.now();
      debugPrint('[ImportProvider] 🟢 START: Preparación - ${startTotal.millisecondsSinceEpoch}');

      final result = await _pipeline.prepare(importedFile, onStatus: (msg) {
        _statusMessage = msg;
        notifyListeners();
      });
      _lastClassification = result.classification;

      _isImporting = false;
      _statusMessage = null;
      notifyListeners();

      debugPrint('[ImportProvider] 🔴 END: Preparación TOTAL - ${DateTime.now().difference(startTotal).inMilliseconds}ms');
      return result;
    } catch (e, stackTrace) {
      _error = e.toString();
      _isImporting = false;
      _statusMessage = null;
      notifyListeners();
      debugPrint('[ImportProvider] ERROR en prepareImport: $e\n$stackTrace');
      return null;
    }
  }

  /// FASE 2: Guarda el documento en BD y lanza OCR en background.
  ///
  /// Debe llamarse después de prepareImport() y confirmación del usuario.
  ///
  /// [onOcrComplete]: callback opcional al finalizar el OCR.
  /// [currentDate]: permite asignar fecha personalizada (usado en PDFs).
  ///
  /// Retorna el [DocumentModel] guardado, o null si hay un error.
  Future<DocumentModel?> completeImport(
    PreparationResult preparation,
    String locale, {
    VoidCallback? onOcrComplete,
    DateTime? currentDate,
  }) async {
    try {
      _error = null;
      _isSaving = true;
      notifyListeners();

      final startTotal = DateTime.now();
      debugPrint('[ImportProvider] 🟢 START: Completar - ${startTotal.millisecondsSinceEpoch}');

      final document = await _pipeline.complete(
        preparation,
        locale,
        currentDate: currentDate,
        onStatus: (msg) {
          _statusMessage = msg;
          notifyListeners();
        },
      );

      _isSaving = false;
      _statusMessage = null;
      _lastImportedDocument = document;
      notifyListeners();

      debugPrint('[ImportProvider] 🔴 END: Completar TOTAL - ${DateTime.now().difference(startTotal).inMilliseconds}ms');
      debugPrint('[ImportProvider] Documento guardado. ID: ${document.id}');

      _processOCRInBackground(document.id!, preparation.classification.type, locale, onComplete: onOcrComplete);

      return document;
    } catch (e, stackTrace) {
      _error = e.toString();
      _isSaving = false;
      _statusMessage = null;
      notifyListeners();
      debugPrint('[ImportProvider] ERROR en completeImport: $e\n$stackTrace');
      return null;
    }
  }

  Future<void> _processOCRInBackground(
      int documentId, DocumentType tfliteKind, String locale, {
      bool skipRefinement = false,
      VoidCallback? onComplete,
    }) async {
    _processingOcrIds.add(documentId);
    _isProcessingOCR = true;
    _statusMessage = 'status_extracting';
    notifyListeners();

    await _pipeline.processOCRBackground(
      documentId,
      tfliteKind,
      locale,
      skipRefinement: skipRefinement,
      onStatus: (msg) {
        _statusMessage = msg;
        notifyListeners();
      },
    );

    _processingOcrIds.remove(documentId);
    _isProcessingOCR = _processingOcrIds.isNotEmpty;
    if (_processingOcrIds.isEmpty) _statusMessage = null;
    notifyListeners();
    onComplete?.call();
  }

  /// Retorna el número de páginas del PDF para que la UI decida si mostrar dialog.
  ///
  /// Retorna 0 si el servicio no está disponible o el PDF no es válido.
  Future<int> checkPdfPageCount(String pdfPath) async {
    if (_pdfImportService == null) return 0;
    try {
      return await _pdfImportService!.getPageCount(pdfPath);
    } catch (e) {
      debugPrint('[ImportProvider] Error leyendo páginas PDF: $e');
      return 0;
    }
  }

  /// Importa N páginas de un PDF, cada una como documento independiente.
  ///
  /// Flujo por página:
  ///   renderizar JPG → prepareImport (classify) → completeImport (guardar + OCR)
  ///
  /// Retorna lista de documentos guardados (puede ser menor a [pagesToImport]
  /// si alguna página falla — las demás se procesan igual).
  Future<List<DocumentModel>> importPdfPages(
    String pdfPath,
    int pagesToImport,
    String locale,
  ) async {
    if (_pdfImportService == null) return [];

    final tempDir = await getTemporaryDirectory();
    final docsDir = await getApplicationDocumentsDirectory();

    int actualPages;
    try {
      final pageCount = await _pdfImportService!.getPageCount(pdfPath);
      actualPages = pageCount < pagesToImport ? pageCount : pagesToImport;
    } catch (e) {
      _error = e.toString();
      _statusMessage = null;
      notifyListeners();
      debugPrint('[ImportProvider] Error leyendo páginas PDF: $e');
      return [];
    }

    _pdfCurrentPage = 0;
    _pdfTotalPages = actualPages;
    _statusMessage = 'status_reading_pdf';
    notifyListeners();

    final savedDocuments = <DocumentModel>[];

    // Timestamps decrecientes → p1 queda arriba (más reciente) en la UI.
    final baseTime = DateTime.now();

    // Para PDFs multipágina: nombre base del archivo (sin extensión).
    // Cada página hereda ese nombre + número: "tutorial_1", "tutorial_2"…
    final isMultiPage = actualPages > 1;
    final pdfBaseName = isMultiPage ? p.basenameWithoutExtension(pdfPath) : '';

    for (var i = 0; i < actualPages; i++) {
      _pdfCurrentPage = i + 1;
      _statusMessage = isMultiPage ? null : 'status_processing_pdf';
      notifyListeners();

      // 1. Renderizar solo esta página
      File tempPageFile;
      try {
        tempPageFile = await _pdfImportService!.renderPageToJpg(pdfPath, i, tempDir.path);
      } catch (e) {
        debugPrint('[ImportProvider] Error renderizando página ${i + 1}: $e');
        continue;
      }

      // 2. Copiar a directorio permanente antes de procesar.
      // normalize() puede devolver el mismo path, y si luego borramos el temp
      // la BD quedaría con un path inexistente.
      final permPath = p.join(docsDir.path, p.basename(tempPageFile.path));
      File permFile;
      try {
        permFile = await tempPageFile.copy(permPath);
      } catch (e) {
        debugPrint('[ImportProvider] Error copiando página ${i + 1} a docs: $e');
        await tempPageFile.delete().catchError((_) {});
        continue;
      }

      // 3. Limpiar temp inmediatamente (ya tenemos copia permanente)
      await tempPageFile.delete().catchError((_) {});

      // 4. Procesar
      final pageDate = baseTime.add(Duration(milliseconds: actualPages - 1 - i));
      try {
        if (isMultiPage) {
          // PDF multipágina: sin TFLite, sin refinador, nombre heredado del PDF.
          final title = '${pdfBaseName}_${i + 1}';
          final document = await _pipeline.completePdfPage(permFile, title, locale, pageDate);
          savedDocuments.add(document);
          _processOCRInBackground(
            document.id!,
            DocumentType.documento,
            locale,
            skipRefinement: true,
          );
        } else {
          // PDF de 1 página: pipeline normal con TFLite y refinador.
          final preparation = await prepareImport(permFile);
          if (preparation == null) {
            await permFile.delete().catchError((_) {});
            continue;
          }
          final document = await completeImport(preparation, locale, currentDate: pageDate);
          if (document != null) savedDocuments.add(document);
        }
      } catch (e) {
        debugPrint('[ImportProvider] Error importando página ${i + 1}: $e');
        await permFile.delete().catchError((_) {});
      }
    }

    _pdfCurrentPage = 0;
    _pdfTotalPages = 0;
    _statusMessage = null;
    notifyListeners();

    debugPrint('[ImportProvider] PDF importado: ${savedDocuments.length}/$actualPages páginas guardadas');
    return savedDocuments;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
