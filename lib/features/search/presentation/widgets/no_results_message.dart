import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Mensaje cuando no hay resultados de búsqueda
class NoResultsMessage extends StatelessWidget {
  final String query;

  const NoResultsMessage({
    super.key,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'search_no_results'.tr(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (query.isNotEmpty)
              Text(
                'No se encontró "$query"',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
