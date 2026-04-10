import 'package:flutter/foundation.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';
import 'package:escandoc/features/documents/domain/usecases/get_documents.dart';
import 'package:escandoc/features/documents/domain/usecases/get_document_by_id.dart';
import 'package:escandoc/features/documents/domain/usecases/delete_document.dart';
import 'package:escandoc/features/documents/domain/usecases/rename_document.dart';
import 'package:escandoc/features/documents/domain/usecases/update_expiry_date.dart';

/// Provider para gestionar estado de la lista de documentos
/// Conecta los UseCases (Domain) con la UI (Presentation)
class DocumentsProvider extends ChangeNotifier {
  // Dependencies
  late final DocumentRepository _repository;
  late final GetDocuments _getDocuments;
  late final GetDocumentById _getDocumentById;
  late final DeleteDocument _deleteDocument;
  late final RenameDocument _renameDocument;
  late final UpdateExpiryDate _updateExpiryDate;

  // State
  List<DocumentModel> _documents = [];
  DocumentModel? _selectedDocument;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<DocumentModel> get documents => _documents;
  DocumentModel? get selectedDocument => _selectedDocument;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasDocuments => _documents.isNotEmpty;

  // Constructor con dependency injection
  DocumentsProvider({DocumentRepository? repository}) {
    final repo = repository ?? DocumentRepository();
    _repository = repo;
    _getDocuments = GetDocuments(repository: repo);
    _getDocumentById = GetDocumentById(repository: repo);
    _deleteDocument = DeleteDocument(repository: repo);
    _renameDocument = RenameDocument(repository: repo);
    _updateExpiryDate = UpdateExpiryDate(repository: repo);
  }

  /// Carga todos los documentos de la BD
  Future<void> loadDocuments() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _documents = await _getDocuments();
    } catch (e) {
      _errorMessage = 'Error al cargar documentos';
      _documents = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Selecciona un documento por ID (para vista detalle)
  Future<void> selectDocument(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedDocument = await _getDocumentById(id);
      if (_selectedDocument == null) {
        _errorMessage = 'Documento no encontrado';
      }
    } catch (e) {
      _errorMessage = 'Error al cargar documento';
      _selectedDocument = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Elimina un documento y actualiza la lista
  Future<bool> deleteDocument(int id) async {
    try {
      final success = await _deleteDocument(id);

      if (success) {
        // Actualizar lista local (remover el documento eliminado)
        _documents = _documents.where((doc) => doc.id != id).toList();

        // Si era el documento seleccionado, limpiarlo
        if (_selectedDocument?.id == id) {
          _selectedDocument = null;
        }

        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      _errorMessage = 'Error al eliminar documento';
      notifyListeners();
      return false;
    }
  }

  /// Renombra un documento y actualiza estado local
  Future<bool> renameDocument(int id, String newTitle) async {
    try {
      final success = await _renameDocument(id, newTitle);
      if (success) {
        final trimmed = newTitle.trim();
        final capitalized = trimmed[0].toUpperCase() + trimmed.substring(1);
        if (_selectedDocument?.id == id) {
          _selectedDocument = _selectedDocument!.copyWith(title: capitalized);
        }
        final index = _documents.indexWhere((d) => d.id == id);
        if (index != -1) {
          _documents[index] = _documents[index].copyWith(title: capitalized);
        }
        notifyListeners();
      }
      return success;
    } catch (e) {
      _errorMessage = 'Error al renombrar documento';
      notifyListeners();
      return false;
    }
  }

  /// Actualiza la nota del documento seleccionado
  Future<bool> updateNote(int documentId, String? content) async {
    try {
      await _repository.updateNote(documentId, content);
      if (_selectedDocument?.id == documentId) {
        _selectedDocument = _selectedDocument!.copyWith(noteContent: content);
      }
      final index = _documents.indexWhere((d) => d.id == documentId);
      if (index != -1) {
        _documents[index] = _documents[index].copyWith(noteContent: content);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al guardar nota';
      notifyListeners();
      return false;
    }
  }

  /// Limpia el documento seleccionado
  void clearSelectedDocument() {
    _selectedDocument = null;
    notifyListeners();
  }

  /// Asigna o quita la fecha de vencimiento de un documento.
  /// Retorna true si se actualizó correctamente.
  Future<bool> updateExpiryDate(int documentId, DateTime? date) async {
    try {
      final success = await _updateExpiryDate(documentId, date);
      if (success) {
        if (_selectedDocument?.id == documentId) {
          _selectedDocument = date == null
              ? _selectedDocument!.copyWith(clearExpiryDate: true)
              : _selectedDocument!.copyWith(expiryDate: date);
        }
        final index = _documents.indexWhere((d) => d.id == documentId);
        if (index != -1) {
          _documents[index] = date == null
              ? _documents[index].copyWith(clearExpiryDate: true)
              : _documents[index].copyWith(expiryDate: date);
        }
        notifyListeners();
      }
      return success;
    } catch (e) {
      _errorMessage = e is ArgumentError ? e.message : 'Error al guardar vencimiento';
      notifyListeners();
      return false;
    }
  }

  /// Retorna cuántos documentos vencen en cada día del rango.
  /// Útil para cargar los marcadores del calendario.
  Future<Map<DateTime, int>> getExpiryCounts(DateTime start, DateTime end) async {
    try {
      final docs = await _repository.getDocumentsExpiringInRange(start, end);
      final counts = <DateTime, int>{};
      for (final doc in docs) {
        if (doc.expiryDate == null) continue;
        final key = DateTime(doc.expiryDate!.year, doc.expiryDate!.month, doc.expiryDate!.day);
        counts[key] = (counts[key] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      debugPrint('[DocumentsProvider] ERROR getExpiryCounts: $e');
      return {};
    }
  }

  /// Retorna documentos que vencen en el día indicado.
  Future<List<DocumentModel>> getDocumentsExpiringOn(DateTime day) async {
    try {
      final dayOnly = DateTime(day.year, day.month, day.day);
      final nextDay = dayOnly.add(const Duration(days: 1));
      return await _repository.getDocumentsExpiringInRange(dayOnly, nextDay.subtract(const Duration(seconds: 1)));
    } catch (e) {
      debugPrint('[DocumentsProvider] ERROR getDocumentsExpiringOn: $e');
      return [];
    }
  }

  /// Limpia el mensaje de error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
