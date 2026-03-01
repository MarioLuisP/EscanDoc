import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:escandoc/core/services/document_orientation_service.dart';

/// UseCase para detectar y corregir la orientación de un documento antes del pipeline.
///
/// Se ejecuta después de convertir a JPG y ANTES de clasificar con TFLite.
///
/// FLUJO:
/// 1. EXIF check: lee el tag Orientation del JPEG (~2ms).
///    Si indica rotación → aplicar físicamente.
/// 2. Crop OCR (siempre): recorta franja central, corre ML Kit para detectar
///    ángulo del texto (~100-150ms). Si indica rotación → aplicar físicamente.
///
/// Ambas capas son complementarias: EXIF normaliza imágenes de cámara,
/// Crop OCR detecta documentos fotografiados de costado (EXIF=0 pero torcidos).
class DetectAndFixOrientation {
  final DocumentOrientationService _service;

  DetectAndFixOrientation(this._service);

  Future<File> call(File jpgFile) async {
    final startTotal = DateTime.now();
    debugPrint(
        '[DetectOrientation] 🟢 START: ${startTotal.millisecondsSinceEpoch}');

    File current = jpgFile;

    // ── 1. EXIF ───────────────────────────────────────────────────────────────
    final t0 = DateTime.now();
    debugPrint('[DetectOrientation] 🟢 START: EXIF check');
    final exifDeg = await _service.readExifRotation(current);
    debugPrint(
        '[DetectOrientation] 🔴 END: EXIF check'
        ' - ${DateTime.now().difference(t0).inMilliseconds}ms'
        ' - ${exifDeg}°');

    if (exifDeg != 0) {
      final t1 = DateTime.now();
      debugPrint('[DetectOrientation] 🟢 START: Rotar por EXIF ${exifDeg}°');
      current = await _service.rotateImage(current, exifDeg);
      debugPrint(
          '[DetectOrientation] 🔴 END: Rotar por EXIF'
          ' - ${DateTime.now().difference(t1).inMilliseconds}ms');
    }

    // ── 2. Crop OCR (siempre) ─────────────────────────────────────────────────
    final t2 = DateTime.now();
    debugPrint('[DetectOrientation] 🟢 START: Crop OCR');
    final contentDeg = await _service.detectContentRotation(current);
    debugPrint(
        '[DetectOrientation] 🔴 END: Crop OCR'
        ' - ${DateTime.now().difference(t2).inMilliseconds}ms'
        ' - ${contentDeg}°');

    if (contentDeg != 0) {
      final t3 = DateTime.now();
      debugPrint(
          '[DetectOrientation] 🟢 START: Rotar por contenido ${contentDeg}°');
      current = await _service.rotateImage(current, contentDeg);
      debugPrint(
          '[DetectOrientation] 🔴 END: Rotar por contenido'
          ' - ${DateTime.now().difference(t3).inMilliseconds}ms');
    }

    final totalMs = DateTime.now().difference(startTotal).inMilliseconds;
    debugPrint(
        '[DetectOrientation] 🔴 TOTAL: ${totalMs}ms'
        ' — EXIF: ${exifDeg}°, contenido: ${contentDeg}°');

    return current;
  }
}
