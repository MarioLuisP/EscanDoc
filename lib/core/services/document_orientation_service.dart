import 'dart:io';

/// Determina los grados de rotación del texto en una imagen a partir de los
/// ángulos de líneas reportados por ML Kit (pueden ser negativos).
///
/// Retorna 0, 90, 180 o 270 — cuánto está rotada la imagen respecto a lo normal.
/// Usado por [OCRServiceImpl] y [DocumentOrientationServiceImpl].
int detectOrientationDegrees(List<double> angles) {
  if (angles.isEmpty) return 0;
  final normalized = angles.map((a) => a < 0 ? a + 360 : a).toList()..sort();
  final median = normalized[normalized.length ~/ 2];
  if (median >= 315 || median < 45)  return 0;
  if (median >= 45  && median < 135) return 90;
  if (median >= 135 && median < 225) return 180;
  return 270;
}

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
