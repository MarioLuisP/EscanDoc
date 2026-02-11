import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Barra de búsqueda accesible con fuente grande
class SearchBarWidget extends StatelessWidget {
  final String query;
  final Function(String) onChanged;
  final VoidCallback? onClear;
  final TextEditingController? controller;

  const SearchBarWidget({
    super.key,
    required this.query,
    required this.onChanged,
    this.onClear,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 18), // 18sp según spec
        decoration: InputDecoration(
          hintText: 'search_placeholder'.tr(),
          hintStyle: TextStyle(
            fontSize: 18,
            color: Colors.grey[600],
          ),
          prefixIcon: const Icon(Icons.search, size: 28),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 28),
                  onPressed: onClear,
                  tooltip: 'clear_search_tooltip'.tr(),
                )
              : null,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).primaryColor,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
