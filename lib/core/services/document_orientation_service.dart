import 'dart:io';

/// Servicio para detectar y corregir la orientación de imágenes de documentos.
///
/// Dos capas independientes:
/// 1. EXIF: corrige imágenes de cámara que tienen los píxeles físicamente rotados
///    pero el tag EXIF indica cómo mostrarlos correctamente.
/// 2. Contenido (Crop OCR): detecta el ángulo real del texto en el documento,
///    cubre casos donde EXIF=0 pero el documento fue fotografiado de costado.
abstract class DocumentOrientationService {
  /// Lee el tag EXIF Orientation de un JPEG.
  ///
  /// Retorna los grados necesarios para corregir la orientación (0, 90, 180 o 270).
  /// Retorna 0 si no hay EXIF, si el tag no existe, o si no se necesita rotación.
  Future<int> readExifRotation(File imageFile);

  /// Recorta una franja central de la imagen, corre ML Kit OCR sobre ese crop,
  /// y retorna los grados necesarios para que el texto quede horizontal (0, 90, 180 o 270).
  ///
  /// Se ejecuta siempre, independientemente del resultado de [readExifRotation].
  Future<int> detectContentRotation(File imageFile);

  /// Rota físicamente los píxeles de la imagen por [degrees] (debe ser 90, 180 o 270).
  ///
  /// Sobreescribe el archivo original. Retorna el mismo [File].
  Future<File> rotateImage(File imageFile, int degrees);
}
