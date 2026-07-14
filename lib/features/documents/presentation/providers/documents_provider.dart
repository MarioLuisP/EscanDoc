import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:escandoc/core/services/notification_prompt_service.dart';
import 'package:escandoc/core/services/notification_service.dart';
import 'package:escandoc/features/documents/data/models/document_model.dart';
import 'package:escandoc/features/documents/data/repositories/document_repository.dart';
import 'package:escandoc/features/documents/domain/usecases/get_documents.dart';
import 'package:escandoc/features/documents/domain/usecases/get_document_by_id.dart';
import 'package:escandoc/features/documents/domain/usecases/delete_document.dart';
import 'package:escandoc/features/documents/domain/usecases/delete_documents.dart';
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
  late final DeleteDocuments _deleteDocuments;
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
    _deleteDocuments = DeleteDocuments(repository: repo);
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

  /// Elimina varios documentos en un solo lote.
  ///
  /// Una sola operación de borrado en BD + un único [notifyListeners], en vez
  /// de N. Devuelve la cantidad de documentos efectivamente eliminados.
  Future<int> deleteDocuments(List<int> ids) async {
    try {
      final deletedIds = await _deleteDocuments(ids);
      if (deletedIds.isEmpty) return 0;

      final deletedSet = deletedIds.toSet();
      _documents =
          _documents.where((doc) => !deletedSet.contains(doc.id)).toList();
      if (deletedSet.contains(_selectedDocument?.id)) {
        _selectedDocument = null;
      }

      notifyListeners();
      return deletedIds.length;
    } catch (e) {
      _errorMessage = 'Error al eliminar documentos';
      notifyListeners();
      return 0;
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

  /// Actualiza el texto de una nota y su imagen regenerada (nuevo [newFilePath]).
  ///
  /// A diferencia de [updateNote], acá el texto cambió → el pergamino se
  /// regeneró como un archivo nuevo. Apunta el documento a la imagen nueva y
  /// borra la vieja (best-effort) para no acumular archivos huérfanos.
  Future<bool> updateNoteImage(
      int documentId, String? content, String newFilePath) async {
    try {
      final index = _documents.indexWhere((d) => d.id == documentId);
      final oldPath = index != -1
          ? _documents[index].filePath
          : _selectedDocument?.filePath;

      await _repository.updateNoteImage(documentId, content, newFilePath);

      if (_selectedDocument?.id == documentId) {
        _selectedDocument = _selectedDocument!
            .copyWith(noteContent: content, filePath: newFilePath);
      }
      if (index != -1) {
        _documents[index] = _documents[index]
            .copyWith(noteContent: content, filePath: newFilePath);
      }
      notifyListeners();

      if (oldPath != null && oldPath != newFilePath) {
        try {
          await File(oldPath).delete();
        } catch (_) {/* best-effort */}
      }
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
        _syncNotification(documentId, date);
      }
      return success;
    } catch (e) {
      _errorMessage = e is ArgumentError ? e.message : 'Error al guardar vencimiento';
      notifyListeners();
      return false;
    }
  }

  void _syncNotification(int documentId, DateTime? date) {
    if (date == null) {
      NotificationService.cancelExpiryNotifications(documentId);
      return;
    }
    final title = _documents
            .where((d) => d.id == documentId)
            .firstOrNull
            ?.title ??
        _selectedDocument?.title;
    if (title != null) {
      NotificationService.scheduleExpiryNotifications(documentId, title, date);
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

  /// Cancela todas las notificaciones y deshabilita el servicio.
  Future<void> disableNotifications() async {
    await NotificationPromptService.setEnabled(false);
    await NotificationService.cancelAllNotifications();
  }

  /// Habilita notificaciones y reprograma todos los documentos con vencimiento.
  Future<void> enableNotifications() async {
    await NotificationPromptService.setEnabled(true);
    for (final doc in _documents) {
      if (doc.id != null && doc.expiryDate != null) {
        NotificationService.scheduleExpiryNotifications(
            doc.id!, doc.title, doc.expiryDate!);
      }
    }
  }

  /// Limpia el mensaje de error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
