import 'package:flutter/material.dart';
import 'package:escandoc/features/notes/data/models/note_model.dart';

/// Widget que muestra una nota vinculada a un documento
/// Diseño simple y accesible para personas mayores
class NoteDisplay extends StatelessWidget {
  final NoteModel note;

  const NoteDisplay({
    super.key,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        border: Border.all(
          color: Colors.amber[700]!,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícono + Título de la nota
          Row(
            children: [
              Icon(
                Icons.note,
                size: 24,
                color: Colors.amber[900],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  note.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[900],
                  ),
                ),
              ),
            ],
          ),

          // Contenido de la nota (si existe)
          if (note.content != null && note.content!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              note.content!,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
