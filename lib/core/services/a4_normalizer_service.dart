import 'dart:math';
import 'dart:typed_data';

/// Dimensiones A4 a 300 DPI.
const int kA4Width = 2480;
const int kA4Height = 3508;

/// Resultado del cálculo de fit "contain" de una imagen dentro del canvas A4.
class A4FitResult {
  final double scale;
  final int scaledW;
  final int scaledH;

  /// Offset horizontal (bandas izquierda/derecha) para centrar la imagen.
  final double dx;

  /// Offset vertical (bandas arriba/abajo) para centrar la imagen.
  final double dy;

  const A4FitResult({
    required this.scale,
    required this.scaledW,
    required this.scaledH,
    required this.dx,
    required this.dy,
  });
}

/// Servicio que normaliza imágenes a canvas A4 (2480×3508 @ 300 DPI)
/// con fondo blanco y la imagen centrada (contain fit).
abstract class A4NormalizerService {
  /// Calcula el fit "contain" de una imagen [imgW]x[imgH] dentro del A4.
  ///
  /// La escala se elige para que el lado mayor de la imagen toque
  /// el borde correspondiente del A4. El otro eje queda con bandas blancas.
  static A4FitResult calculateA4Fit(int imgW, int imgH) {
    final scale = min(kA4Width / imgW, kA4Height / imgH);
    final scaledW = (imgW * scale).round();
    final scaledH = (imgH * scale).round();
    final dx = (kA4Width - scaledW) / 2;
    final dy = (kA4Height - scaledH) / 2;
    return A4FitResult(
      scale: scale,
      scaledW: scaledW,
      scaledH: scaledH,
      dx: dx,
      dy: dy,
    );
  }

  /// Normaliza los bytes de una imagen JPG/PNG a un canvas A4 blanco.
  ///
  /// Retorna bytes PNG de 2480×3508 listos para insertar en un PDF.
  Future<Uint8List> normalizeToA4(Uint8List imageBytes);
}
