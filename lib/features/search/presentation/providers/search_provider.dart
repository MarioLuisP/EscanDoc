import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:escandoc/features/search/data/models/search_result.dart';
import 'package:escandoc/features/search/domain/usecases/search_documents.dart';
import 'package:escandoc/features/search/domain/usecases/voice_search.dart';

/// Provider para la búsqueda de documentos
///
/// Maneja el estado de búsqueda, incluyendo búsqueda por texto
/// con debounce y búsqueda por voz.
class SearchProvider with ChangeNotifier {
  final SearchDocuments searchDocuments;
  final VoiceSearch voiceSearch;

  SearchProvider({
    required this.searchDocuments,
    required this.voiceSearch,
  });

  // Estado
  String _query = '';
  List<SearchResult> _results = [];
  bool _isLoading = false;
  bool _isListening = false;
  String? _errorMessage;

  // Debounce timer
  Timer? _debounce;

  // Getters
  String get query => _query;
  List<SearchResult> get results => _results;
  bool get isLoading => _isLoading;
  bool get isListening => _isListening;
  String? get errorMessage => _errorMessage;
  bool get hasResults => _results.isNotEmpty;
  bool get hasQuery => _query.isNotEmpty;

  /// Ejecuta búsqueda con debounce de 300ms — mínimo 3 caracteres
  void search(String query) {
    _query = query;
    _errorMessage = null;
    _debounce?.cancel();

    if (query.trim().length < 3) {
      _results = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _executeSearch(query);
    });
  }

  /// Ejecuta la búsqueda en el repository
  Future<void> _executeSearch(String query) async {
    try {
      _isLoading = true;
      notifyListeners();

      final results = await searchDocuments.execute(query);

      _results = results;
      _errorMessage = null;
    } catch (e) {
      _results = [];
      _errorMessage = 'Error al buscar documentos';
      debugPrint('Error en búsqueda: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Ejecuta búsqueda por voz
  Future<void> searchByVoice() async {
    try {
      _isListening = true;
      _errorMessage = null;
      notifyListeners();

      final recognizedText = await voiceSearch.execute();

      _isListening = false;

      if (recognizedText != null && recognizedText.isNotEmpty) {
        // Ejecutar búsqueda con el texto reconocido
        _query = recognizedText;
        notifyListeners();

        await _executeSearch(recognizedText);
      } else {
        // No se reconoció texto
        _errorMessage = 'No entendí, intentá de nuevo';
        notifyListeners();
      }
    } catch (e) {
      _isListening = false;
      _errorMessage = 'Error al usar el micrófono';
      debugPrint('Error en búsqueda por voz: $e');
      notifyListeners();
    }
  }

  /// Limpia los resultados de búsqueda
  void clearResults() {
    _query = '';
    _results = [];
    _errorMessage = null;
    _isLoading = false;
    _debounce?.cancel();
    notifyListeners();
  }

  /// Limpia el mensaje de error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
