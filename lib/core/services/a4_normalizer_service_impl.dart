import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:escandoc/core/services/a4_normalizer_service.dart';

/// Implementación de [A4NormalizerService] usando dart:ui.
///
/// Dibuja la imagen escalada y centrada sobre un canvas A4 blanco.
/// Retorna bytes PNG (dart:ui no exporta JPEG nativo).
/// pw.MemoryImage acepta PNG, por lo que es compatible con PdfConverterService.
class A4NormalizerServiceImpl implements A4NormalizerService {
  @override
  Future<Uint8List> normalizeToA4(Uint8List imageBytes) async {
    // 1. Decodificar imagen fuente
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final srcImage = frame.image;

    final fit = A4NormalizerService.calculateA4Fit(
      srcImage.width,
      srcImage.height,
    );

    // 2. Crear canvas A4 con fondo blanco
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, kA4Width.toDouble(), kA4Height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );

    // 3. Dibujar imagen escalada y centrada
    final srcRect = ui.Rect.fromLTWH(
      0,
      0,
      srcImage.width.toDouble(),
      srcImage.height.toDouble(),
    );
    final dstRect = ui.Rect.fromLTWH(
      fit.dx,
      fit.dy,
      fit.scaledW.toDouble(),
      fit.scaledH.toDouble(),
    );
    canvas.drawImageRect(srcImage, srcRect, dstRect, ui.Paint());

    // 4. Rasterizar a imagen A4
    final picture = recorder.endRecording();
    final resultImage = await picture.toImage(kA4Width, kA4Height);

    // 5. Exportar como PNG
    final byteData =
        await resultImage.toByteData(format: ui.ImageByteFormat.png);

    srcImage.dispose();
    resultImage.dispose();
    picture.dispose();

    if (byteData == null) {
      throw Exception('A4NormalizerServiceImpl: fallo al exportar PNG');
    }

    return byteData.buffer.asUint8List();
  }
}
