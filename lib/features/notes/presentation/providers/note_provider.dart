import 'package:flutter/foundation.dart';
import 'package:escandoc/features/notes/data/models/note_model.dart';
import 'package:escandoc/features/notes/data/repositories/note_repository.dart';
import 'package:escandoc/features/notes/domain/usecases/create_note.dart';
import 'package:escandoc/features/notes/domain/usecases/update_note.dart';
import 'package:escandoc/features/notes/domain/usecases/get_note_by_document.dart';
import 'package:escandoc/features/notes/domain/usecases/delete_note.dart';

/// Provider para gestionar estado de notas vinculadas a documentos
/// Conecta los UseCases (Domain) con la UI (Presentation)
class NoteProvider extends ChangeNotifier {
  // Dependencies (UseCases)
  late final CreateNote _createNote;
  late final UpdateNote _updateNote;
  late final GetNoteByDocument _getNoteByDocument;
  late final DeleteNote _deleteNote;

  // State
  NoteModel? _currentNote;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  NoteModel? get currentNote => _currentNote;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasNote => _currentNote != null;

  // Constructor con dependency injection
  NoteProvider({NoteRepository? repository}) {
    final repo = repository ?? NoteRepository();
    _createNote = CreateNote(repository: repo);
    _updateNote = UpdateNote(repository: repo);
    _getNoteByDocument = GetNoteByDocument(repository: repo);
    _deleteNote = DeleteNote(repository: repo);
  }

  /// Carga la nota vinculada a un documento
  Future<void> loadNoteByDocument(int documentId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentNote = await _getNoteByDocument(documentId);
    } catch (e) {
      _errorMessage = 'Error al cargar nota';
      _currentNote = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Crea una nueva nota y la vincula al documento
  Future<bool> createNote({
    String? content,
    required int documentId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final note = await _createNote(
        content: content,
        documentId: documentId,
      );

      if (note != null) {
        _currentNote = note;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'No se pudo crear la nota';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error al crear nota';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Actualiza la nota actual
  Future<bool> updateNote({
    String? content,
  }) async {
    if (_currentNote == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedNote = await _updateNote(
        noteId: _currentNote!.id!,
        content: content,
      );

      if (updatedNote != null) {
        _currentNote = updatedNote;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'No se pudo actualizar la nota';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error al actualizar nota';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Elimina la nota actual
  Future<bool> deleteNote() async {
    if (_currentNote == null) return false;

    try {
      final success = await _deleteNote(_currentNote!.id!);

      if (success) {
        _currentNote = null;
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      _errorMessage = 'Error al eliminar nota';
      notifyListeners();
      return false;
    }
  }

  /// Limpia la nota actual
  void clearNote() {
    _currentNote = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Limpia el mensaje de error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
