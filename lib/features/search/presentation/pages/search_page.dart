import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:escandoc/features/search/presentation/providers/search_provider.dart';
import 'package:escandoc/features/search/presentation/widgets/search_bar_widget.dart';
import 'package:escandoc/features/search/presentation/widgets/voice_button.dart';
import 'package:escandoc/features/search/presentation/widgets/listening_indicator.dart';
import 'package:escandoc/features/search/presentation/widgets/search_result_card.dart';
import 'package:escandoc/features/search/presentation/widgets/no_results_message.dart';

/// Página de búsqueda de documentos y notas
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SearchProvider>(
      builder: (context, searchProvider, child) {
        // Actualizar controller si el query cambió desde voz
        if (searchProvider.query != _searchController.text) {
          _searchController.text = searchProvider.query;
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('search_title'.tr()),
            elevation: 0,
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  // Barra de búsqueda
                  SearchBarWidget(
                    query: searchProvider.query,
                    controller: _searchController,
                    onChanged: (query) {
                      searchProvider.search(query);
                    },
                    onClear: () {
                      _searchController.clear();
                      searchProvider.clearResults();
                    },
                  ),

                  // Resultados o estados vacíos
                  Expanded(
                    child: _buildBody(searchProvider),
                  ),
                ],
              ),

              // Indicador de escucha (overlay)
              if (searchProvider.isListening)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: ListeningIndicator(),
                  ),
                ),
            ],
          ),

          // Botón de búsqueda por voz
          floatingActionButton: VoiceButton(
            isListening: searchProvider.isListening,
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await searchProvider.searchByVoice();

              // Mostrar error si existe
              if (searchProvider.errorMessage != null && mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(searchProvider.errorMessage!),
                    duration: const Duration(seconds: 3),
                  ),
                );
                searchProvider.clearError();
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildBody(SearchProvider searchProvider) {
    // Mostrar loading
    if (searchProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Mostrar mensaje si no hay query
    if (!searchProvider.hasQuery) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              Text(
                'search_empty_title'.tr(),
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'search_empty_subtitle'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Mostrar resultados o mensaje de no resultados
    if (searchProvider.hasResults) {
      return ListView.builder(
        itemCount: searchProvider.results.length,
        padding: const EdgeInsets.only(bottom: 80), // Espacio para FAB
        itemBuilder: (context, index) {
          final result = searchProvider.results[index];
          return SearchResultCard(
            result: result,
            onTap: () {
              // Navegar al detalle solo si es documento
              if (result.type == 'document') {
                Navigator.pushNamed(
                  context,
                  '/document/detail',
                  arguments: result.id,
                );
              }
              // Si es nota, podríamos navegar al documento que la contiene
              // o mostrar un diálogo con el contenido de la nota
            },
          );
        },
      );
    } else {
      return NoResultsMessage(query: searchProvider.query);
    }
  }
}
