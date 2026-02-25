## Lecciones

- Nunca usar `.withOpacity()` — está deprecado. Usar `.withValues(alpha: x)` en su lugar.

- **Paleta de colores por tipo de documento:** usar `DocumentTypeColors.of(document.documentType)` → retorna `DocumentTypeScheme` con `.bg`, `.fg`, `.border`. Definido en `lib/core/theme/document_type_colors.dart`. Úsarlo para fondos, chips y sombras; la sombra queda bien con `scheme.border.withValues(alpha: 0.55)`.