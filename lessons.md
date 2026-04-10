## Lecciones

- Nunca usar `.withOpacity()` — está deprecado. Usar `.withValues(alpha: x)` en su lugar.

- **Todo texto visible al usuario va en claves de localización:** agregar la clave en `assets/l10n/es.json` Y `assets/l10n/en.json`, y referenciar con `.tr()` en el widget. Providers y UseCases emiten claves (strings sin traducir), nunca el texto final.

- **Paleta de colores por tipo de documento:** usar `DocumentTypeColors.of(document.documentType)` → retorna `DocumentTypeScheme` con `.bg`, `.fg`, `.border`. Definido en `lib/core/theme/document_type_colors.dart`. Úsarlo para fondos, chips y sombras; la sombra queda bien con `scheme.border.withValues(alpha: 0.55)`.

AGP 9 — NO actualizar: El documento advierte explícitamente que no hay que actualizar a Android Gradle Plugin 9 todavía. Si al hacer flutter pub get sugiere actualizar AGP, rechazarlo.

iOS UIScene lifecycle: Ahora activo por default. Si el build de iOS en Codemagic empieza a fallar, revisar la guía de migración de AppDelegate.
