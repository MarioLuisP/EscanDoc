import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Opciones de acción cuando se detecta una foto en el scanner.
enum PhotoAction {
  saveToGallery, // Guardar en galería del teléfono
  saveToApp,     // Guardar en la app como documento
  cancel,        // Cancelar
}

/// Diálogo que se muestra cuando se detecta una foto (scanner o import).
///
/// Diseño:
/// - Modal central (tarjeta flotante)
/// - Fondo crema/beige claro (#F5F5DC)
/// - Preview de la imagen
/// - Botones en columna (2 o 3 según origen):
///   - Scanner: Galería (principal) → App (secundario) → Cancelar
///   - Import: App (principal) → Cancelar
///
/// Target: Usuarios mayores (60-85 años) → UX espaciosa y clara
class PhotoDetectedDialog extends StatelessWidget {
  final File imageFile;
  final bool showGalleryOption;

  const PhotoDetectedDialog({
    super.key,
    required this.imageFile,
    this.showGalleryOption = true, // true por defecto (scanner)
  });

  /// Muestra el diálogo y retorna la acción elegida por el usuario.
  ///
  /// Parámetros:
  /// - [context]: BuildContext
  /// - [imageFile]: Imagen detectada como foto
  /// - [showGalleryOption]: Si true, muestra botón "Guardar en Galería" (scanner).
  ///                        Si false, solo muestra "Guardar en App" (import).
  static Future<PhotoAction?> show(
    BuildContext context,
    File imageFile, {
    bool showGalleryOption = true,
  }) async {
    return showDialog<PhotoAction>(
      context: context,
      barrierDismissible: false, // Requiere acción explícita
      builder: (context) => PhotoDetectedDialog(
        imageFile: imageFile,
        showGalleryOption: showGalleryOption,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return Dialog(
      backgroundColor: const Color(0xFFF5F5DC), // Crema/beige claro
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isLandscape ? size.width * 0.85 : size.width * 0.8,
          maxHeight: isLandscape ? size.height * 0.85 : size.height * 0.9,
        ),
        padding: const EdgeInsets.all(24),
        child: isLandscape
            ? _buildLandscapeLayout(context)
            : _buildPortraitLayout(context),
      ),
    );
  }

  /// Layout Portrait (vertical): Imagen encima, contenido abajo
  Widget _buildPortraitLayout(BuildContext context) {
    final dialogWidth = MediaQuery.of(context).size.width * 0.8;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. IMAGEN - Preview
        _buildImagePreview(context, dialogWidth),
        const SizedBox(height: 20),

        // 2. TEXTO - Título y subtítulo
        _buildText(),
        const SizedBox(height: 24),

        // 3. BOTONES
        _buildButtons(context),
      ],
    );
  }

  /// Layout Landscape (horizontal): Imagen a la izquierda, contenido a la derecha
  Widget _buildLandscapeLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. IMAGEN (50% del ancho)
        Expanded(
          flex: 1,
          child: _buildImagePreview(context, null), // null = usar todo el espacio disponible
        ),
        const SizedBox(width: 24),

        // 2. CONTENIDO: Texto + Botones (50% del ancho)
        Expanded(
          flex: 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildText(),
              const SizedBox(height: 24),
              _buildButtons(context),
            ],
          ),
        ),
      ],
    );
  }

  /// Preview de la imagen
  ///
  /// [maxWidth]: Ancho máximo (portrait). Si null, usa todo el espacio (landscape).
  Widget _buildImagePreview(BuildContext context, double? maxWidth) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth != null
              ? maxWidth - 48  // Portrait: restar padding
              : double.infinity, // Landscape: usar todo el espacio disponible
          maxHeight: isLandscape
              ? screenSize.height * 0.7  // Landscape: 70% de altura
              : 250, // Portrait: altura fija
        ),
        child: Image.file(
          imageFile,
          fit: BoxFit.contain, // Mantener proporción
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 150,
              color: Colors.grey[300],
              child: const Icon(
                Icons.broken_image,
                size: 48,
                color: Colors.grey,
              ),
            );
          },
        ),
      ),
    );
  }

  /// Texto: Título y subtítulo
  Widget _buildText() {
    return Column(
      children: [
        // Título
        Text(
          'photo_detected_title'.tr(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        // Subtítulo
        Text(
          'photo_detected_subtitle'.tr(),
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Botones en columna (2 o 3 según showGalleryOption)
  Widget _buildButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. BOTÓN PRINCIPAL - Guardar en Galería (solo si showGalleryOption = true)
        if (showGalleryOption) ...[
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(PhotoAction.saveToGallery),
            icon: const Text('📱', style: TextStyle(fontSize: 20)),
            label: Text(
              'photo_save_to_gallery'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D5016), // Verde bosque oscuro
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25), // Pill
              ),
              elevation: 2,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 2. BOTÓN - Guardar en App (principal si import, secundario si scanner)
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(PhotoAction.saveToApp),
          icon: const Text('📄', style: TextStyle(fontSize: 20)),
          label: Text(
            'photo_save_to_app'.tr(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold, // Siempre bold ahora
            ),
          ),
          style: ElevatedButton.styleFrom(
            // Si NO muestra galería (import), usar color principal
            // Si SÍ muestra galería (scanner), usar color secundario
            backgroundColor: showGalleryOption
                ? const Color(0xFFE8E8D0) // Crema (secundario para scanner)
                : const Color(0xFF2D5016), // Verde (principal para import)
            foregroundColor: showGalleryOption
                ? Colors.grey[800]
                : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25), // Pill
            ),
            elevation: showGalleryOption ? 1 : 2,
          ),
        ),

        const SizedBox(height: 12),

        // 3. BOTÓN TERCIARIO - Cancelar
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(PhotoAction.cancel),
          icon: const Text('🖼️', style: TextStyle(fontSize: 20)),
          label: Text(
            'photo_cancel'.tr(),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}
