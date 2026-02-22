import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:escandoc/features/search/presentation/providers/search_provider.dart';
import 'package:escandoc/features/search/data/models/search_result.dart';
import 'package:escandoc/features/search/presentation/widgets/listening_indicator.dart';

/// Página de búsqueda — diseño con header compacto, barra pill,
/// micrófono grande (vacío) o FAB pequeño (con resultados).
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clearSearch(SearchProvider provider) {
    _controller.clear();
    provider.clearResults();
    _focusNode.unfocus();
  }

  void _navigateToDocument(BuildContext context, int documentId) {
    Navigator.pushNamed(context, '/document/detail', arguments: documentId);
  }

  Future<void> _handleVoice(SearchProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    await provider.searchByVoice();

    if (provider.errorMessage != null && mounted) {
      messenger.showSnackBar(SnackBar(
        content: Text(provider.errorMessage!,
            style: const TextStyle(fontSize: 16)),
        duration: const Duration(seconds: 3),
      ));
      provider.clearError();
    }

    // Sincronizar controller si voz escribió algo
    if (mounted && provider.query != _controller.text) {
      _controller.text = provider.query;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SearchProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F0E8),
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCompactHeader(),
                    _buildSearchBar(provider),
                    Expanded(child: _buildBody(context, provider)),
                    _buildBottomBar(context, provider),
                  ],
                ),

                // Overlay de escucha
                if (provider.isListening)
                  Container(
                    color: Colors.black54,
                    child: const Center(child: ListeningIndicator()),
                  ),
              ],
            ),
          ),

          // FAB micrófono pequeño — solo cuando hay resultados
          floatingActionButton: provider.hasResults
              ? FloatingActionButton(
                  mini: true,
                  backgroundColor: const Color(0xFF388E3C),
                  onPressed: () => _handleVoice(provider),
                  child: const Icon(Icons.mic, color: Colors.white, size: 22),
                )
              : null,
        );
      },
    );
  }

  // --- Header compacto (igual que Ver Todos) ---

  Widget _buildCompactHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/logo.png', width: 38, height: 38),
          const SizedBox(width: 8),
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Escan',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF388E3C),
                  ),
                ),
                TextSpan(
                  text: 'Docs',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Barra de búsqueda pill ---

  Widget _buildSearchBar(SearchProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: const Color(0xFFDDD0B8), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              offset: const Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: (q) => provider.search(q),
          style: const TextStyle(fontSize: 16, color: Colors.black87),
          decoration: InputDecoration(
            hintText: 'search_hint'.tr(),
            hintStyle: TextStyle(fontSize: 16, color: Colors.grey[400]),
            prefixIcon:
                const Icon(Icons.search, color: Color(0xFF888888), size: 22),
            suffixIcon: provider.hasQuery
                ? IconButton(
                    icon: const Icon(Icons.close,
                        color: Color(0xFF888888), size: 20),
                    onPressed: () => _clearSearch(provider),
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          ),
        ),
      ),
    );
  }

  // --- Cuerpo: vacío / loading / resultados / sin resultados ---

  Widget _buildBody(BuildContext context, SearchProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!provider.hasQuery) {
      return _buildEmptyState();
    }

    if (provider.hasResults) {
      return _buildResultsList(context, provider);
    }

    return _buildNoResults(provider.query);
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 32),

          // Botón micrófono grande (gradiente verde, igual a ESCANEAR)
          GestureDetector(
            onTap: () => _handleVoice(context.read<SearchProvider>()),
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF6FBF6F), Color(0xFF2E7D32)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1A5C1A).withOpacity(0.5),
                    offset: const Offset(0, 5),
                    blurRadius: 10,
                    spreadRadius: -1,
                  ),
                ],
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 44),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'search_empty_subtitle'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey[600]),
          ),

          const SizedBox(height: 48),

          // Estado vacío (folder + lupa)
          Icon(Icons.folder_open, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text(
            'no_recent_results'.tr(),
            style: TextStyle(fontSize: 15, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(BuildContext context, SearchProvider provider) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
      itemCount: provider.results.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Color(0xFFDDD0B8)),
      itemBuilder: (context, index) {
        final result = provider.results[index];
        return _ResultItem(
          result: result,
          onTap: () {
            final docId = result.documentId;
            if (docId != null) {
              _navigateToDocument(context, docId);
            }
          },
        );
      },
    );
  }

  Widget _buildNoResults(String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'search_no_results'.tr(),
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // --- Bottom bar ---

  Widget _buildBottomBar(BuildContext context, SearchProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8),
        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _GradientOutlineButton(
              icon: Icons.home_outlined,
              label: 'go_home'.tr(),
              onTap: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _GradientOutlineButton(
              icon: Icons.cleaning_services_outlined,
              label: 'clear_button'.tr(),
              onTap: () => _clearSearch(provider),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets privados
// ---------------------------------------------------------------------------

class _ResultItem extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const _ResultItem({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDoc = result.type == 'document';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ícono de tipo
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDoc
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isDoc ? Icons.description_outlined : Icons.note_outlined,
                size: 24,
                color: isDoc
                    ? const Color(0xFF388E3C)
                    : const Color(0xFFF9A825),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    // Quitar tags HTML del snippet
                    result.snippet
                        .replaceAll('<b>', '')
                        .replaceAll('</b>', ''),
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Chip de tipo
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEEE4CC),
                borderRadius: BorderRadius.circular(50),
                border:
                    Border.all(color: const Color(0xFFBBAA88), width: 1),
              ),
              child: Text(
                isDoc
                    ? 'result_type_document'.tr()
                    : 'result_type_note'.tr(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF5A4A30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón con gradiente crema + borde + sombra 3D.
class _GradientOutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GradientOutlineButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFDFAF4), Color(0xFFE0D4BC)],
        ),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: const Color(0xFFBBAA88), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9A8060).withOpacity(0.45),
            offset: const Offset(0, 4),
            blurRadius: 7,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          splashColor: const Color(0xFFBBAA88).withOpacity(0.3),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: const Color(0xFF5A4A30)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 22,
                    color: Color(0xFF5A4A30),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
