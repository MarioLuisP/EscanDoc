import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:escandoc/core/services/document_orientation_service.dart';

class DocumentOrientationServiceImpl implements DocumentOrientationService {
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  // ── EXIF ──────────────────────────────────────────────────────────────────

  @override
  Future<int> readExifRotation(File imageFile) async {
    try {
      // Leer solo los primeros 64KB (EXIF siempre está en el header JPEG)
      final raf = await imageFile.open(mode: FileMode.read);
      final headerBytes = Uint8List(65536);
      final read = await raf.readInto(headerBytes);
      await raf.close();
      final bytes = headerBytes.sublist(0, read);

      final orientation = _parseJpegExifOrientation(bytes);
      return _exifOrientationToDegrees(orientation);
    } catch (e) {
      debugPrint('[OrientationService] EXIF read error: $e');
      return 0;
    }
  }

  /// Parsea el tag EXIF Orientation (0x0112) de los bytes del header JPEG.
  /// Retorna el valor del tag (1–8) o 1 si no se encuentra.
  int _parseJpegExifOrientation(List<int> bytes) {
    // Verificar SOI (FF D8)
    if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return 1;

    int offset = 2;
    while (offset < bytes.length - 3) {
      if (bytes[offset] != 0xFF) break;
      final marker = bytes[offset + 1];
      offset += 2;

      if (offset + 2 > bytes.length) break;
      final segLen = (bytes[offset] << 8) | bytes[offset + 1];

      if (marker == 0xE1) {
        // APP1 — puede contener EXIF
        if (offset + 8 <= bytes.length &&
            bytes[offset + 2] == 0x45 && // 'E'
            bytes[offset + 3] == 0x78 && // 'x'
            bytes[offset + 4] == 0x69 && // 'i'
            bytes[offset + 5] == 0x66 && // 'f'
            bytes[offset + 6] == 0x00 &&
            bytes[offset + 7] == 0x00) {
          final tiffStart = offset + 8;
          if (tiffStart + 8 > bytes.length) break;

          // Byte order: "II" = little-endian, "MM" = big-endian
          final littleEndian = bytes[tiffStart] == 0x49; // 'I'

          // Offset IFD0 relativo al inicio del bloque TIFF
          final ifdOffset =
              _readUint32(bytes, tiffStart + 4, littleEndian);
          final ifd0Start = tiffStart + ifdOffset;
          if (ifd0Start + 2 > bytes.length) break;

          final entryCount = _readUint16(bytes, ifd0Start, littleEndian);
          for (int i = 0; i < entryCount; i++) {
            final entryOffset = ifd0Start + 2 + i * 12;
            if (entryOffset + 12 > bytes.length) break;
            final tag = _readUint16(bytes, entryOffset, littleEndian);
            if (tag == 0x0112) {
              // Tag Orientation
              return _readUint16(bytes, entryOffset + 8, littleEndian);
            }
          }
        }
        offset += segLen;
      } else if (marker == 0xDA) {
        // SOS = inicio de datos de imagen → no hay más metadatos
        break;
      } else {
        offset += segLen;
      }
    }
    return 1; // No encontrado → orientación normal
  }

  int _readUint16(List<int> b, int off, bool le) =>
      le ? b[off] | (b[off + 1] << 8) : (b[off] << 8) | b[off + 1];

  int _readUint32(List<int> b, int off, bool le) => le
      ? b[off] | (b[off + 1] << 8) | (b[off + 2] << 16) | (b[off + 3] << 24)
      : (b[off] << 24) | (b[off + 1] << 16) | (b[off + 2] << 8) | b[off + 3];

  /// Convierte el valor del tag EXIF Orientation a grados de rotación a aplicar.
  int _exifOrientationToDegrees(int orientation) {
    switch (orientation) {
      case 3:
        return 180;
      case 6:
        return 90;
      case 8:
        return 270;
      default:
        return 0; // 1 = normal; 2,4,5,7 = flip (ignorados)
    }
  }

  // ── CROP OCR ──────────────────────────────────────────────────────────────

  @override
  Future<int> detectContentRotation(File imageFile) async {
    File? cropFile;
    try {
      // 1. Decodificar imagen escalada a 600px de ancho (más rápido)
      final t0 = DateTime.now();
      final bytes = await imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 600);
      final frame = await codec.getNextFrame();
      final srcImage = frame.image;
      debugPrint(
          '[OrientationService] ⏱️ Decode escalado: ${DateTime.now().difference(t0).inMilliseconds}ms'
          ' → ${srcImage.width}×${srcImage.height}px');

      // 2. Recortar franja central (ancho completo, ~20% altura, mín 60px)
      final t1 = DateTime.now();
      final cropH = (srcImage.height * 0.20).round().clamp(60, 200);
      final cropTop = ((srcImage.height - cropH) / 2).round();

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(
        recorder,
        ui.Rect.fromLTWH(0, 0, srcImage.width.toDouble(), cropH.toDouble()),
      );
      canvas.drawImageRect(
        srcImage,
        ui.Rect.fromLTWH(
            0, cropTop.toDouble(), srcImage.width.toDouble(), cropH.toDouble()),
        ui.Rect.fromLTWH(0, 0, srcImage.width.toDouble(), cropH.toDouble()),
        ui.Paint(),
      );
      final picture = recorder.endRecording();
      final cropImage = await picture.toImage(srcImage.width, cropH);

      srcImage.dispose();

      // 3. Encodear crop a JPG y guardar en temp
      final pngBytes =
          await cropImage.toByteData(format: ui.ImageByteFormat.png);
      cropImage.dispose();

      if (pngBytes == null) return 0;

      final jpgBytes = await FlutterImageCompress.compressWithList(
        pngBytes.buffer.asUint8List(),
        quality: 85,
        format: CompressFormat.jpeg,
      );

      final tempDir = await getTemporaryDirectory();
      cropFile = File(
          '${tempDir.path}/orientation_crop_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await cropFile.writeAsBytes(jpgBytes);

      debugPrint(
          '[OrientationService] ⏱️ Crop generado: ${DateTime.now().difference(t1).inMilliseconds}ms'
          ' — ${srcImage.width}×${cropH}px → ${(jpgBytes.length / 1024).toStringAsFixed(1)}KB');

      // 4. ML Kit OCR sobre el crop
      final t2 = DateTime.now();
      final inputImage = InputImage.fromFile(cropFile);
      final recognized = await _textRecognizer.processImage(inputImage);
      debugPrint(
          '[OrientationService] ⏱️ Crop OCR: ${DateTime.now().difference(t2).inMilliseconds}ms'
          ' — ${recognized.blocks.length} bloques');

      // 5. Recolectar ángulos de líneas
      final angles = <double>[];
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          final angle = line.angle;
          if (angle != null) angles.add(angle);
        }
      }

      if (angles.isEmpty) {
        debugPrint('[OrientationService] Crop OCR: sin texto detectado → 0°');
        return 0;
      }

      final detected = detectOrientationDegrees(angles);
      // detectOrientationDegrees retorna cuánto está rotado el texto.
      // Para corregir la imagen hay que aplicar la rotación inversa.
      final correction = (360 - detected) % 360;
      debugPrint(
          '[OrientationService] Ángulos: ${angles.length} líneas'
          ' → detectado: ${detected}°, corrección: ${correction}°');
      return correction;
    } catch (e) {
      debugPrint('[OrientationService] Crop OCR error: $e');
      return 0;
    } finally {
      // Limpiar archivo temporal
      try {
        await cropFile?.delete();
      } catch (_) {}
    }
  }

  // ── ROTAR IMAGEN ──────────────────────────────────────────────────────────

  @override
  Future<File> rotateImage(File imageFile, int degrees) async {
    if (degrees == 0) return imageFile;

    final t0 = DateTime.now();

    // flutter_image_compress hace decode JPEG → rotar nativo → encode JPEG.
    // Mucho más rápido que dart:ui canvas + toByteData(PNG) (~200ms vs ~5000ms).
    // minWidth/minHeight > dimensión máxima esperada → no redimensiona, solo rota.
    // Nota: estos parámetros son dimensión MÁXIMA de salida (el nombre engaña).
    final jpgBytes = await FlutterImageCompress.compressWithFile(
      imageFile.path,
      quality: 92,
      rotate: degrees,
      minWidth: 9999,
      minHeight: 9999,
      keepExif: false,
    );

    if (jpgBytes == null) {
      throw Exception(
          '[OrientationService] rotateImage: compressWithFile retornó null');
    }

    await imageFile.writeAsBytes(jpgBytes);

    debugPrint(
        '[OrientationService] ⏱️ rotateImage ${degrees}°:'
        ' ${DateTime.now().difference(t0).inMilliseconds}ms'
        ' ${(jpgBytes.length / 1024).toStringAsFixed(0)}KB');

    return imageFile;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
