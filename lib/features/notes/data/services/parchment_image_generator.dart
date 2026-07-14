import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:escandoc/features/notes/domain/parchment_text.dart';

/// Genera un JPG estilo pergamino a partir de texto libre.
///
/// Técnica: inserta el widget en un Overlay off-screen (-10000, -10000),
/// espera el layout y la carga de fuente, captura con RepaintBoundary,
/// comprime a JPG 85 y retorna el File.
class ParchmentImageGenerator {
  static const double _width = 600.0;
  static const double _minHeight = 848.0;
  static const double _padding = 40.0;

  /// Multiplicador de alto de línea del texto. Las rayas del renglón se dibujan
  /// con este MISMO paso (`fontSize * _lineHeightFactor`), si no el texto se
  /// despega de las rayas y va cayendo renglón a renglón.
  static const double _lineHeightFactor = 1.8;

  /// Cuánto se sube la raya respecto del pie del renglón, como fracción del
  /// paso. Sin esto la raya cae al borde de la caja de texto y las letras
  /// quedan flotando en el medio; subiéndola ~0.38 las letras se apoyan sobre
  /// la raya (como hoja rayada real). Subir → raya más arriba (más pegada al
  /// texto); bajar → más gap debajo de las letras.
  static const double _lineRaiseFactor = 0.34;

  /// [context] debe ser un context con un Overlay disponible (cualquier page).
  static Future<File> generate(String text, BuildContext context) async {
    // Pre-cargar la fuente antes de renderizar para evitar fallback
    await GoogleFonts.pendingFonts([GoogleFonts.grandHotel()]);

    final repaintKey = GlobalKey();
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -10000,
        top: -10000,
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: _width,
            child: RepaintBoundary(
              key: repaintKey,
              child: _buildParchment(text),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(entry);

    // Dos frames para layout + un extra por Google Fonts
    await Future.delayed(const Duration(milliseconds: 600));

    try {
      final boundary =
          repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final tmpPath = '${dir.path}/nota_tmp_$ts.png';
      final outPath = '${dir.path}/nota_$ts.jpg';

      await File(tmpPath).writeAsBytes(pngBytes);

      final result = await FlutterImageCompress.compressAndGetFile(
        tmpPath,
        outPath,
        quality: 85,
        format: CompressFormat.jpeg,
      );

      await File(tmpPath).delete();

      if (result == null) {
        throw Exception('ParchmentImageGenerator: compress falló');
      }
      return File(result.path);
    } finally {
      entry.remove();
    }
  }

  static Widget _buildParchment(String text) {
    final fontSize = text.length > 1500
        ? 18.0
        : text.length > 800
            ? 22.0
            : 28.0;
    final truncated =
        text.length > 1500 ? '${text.substring(0, 1497)}…' : text;
    // Suaviza palabras TODO-MAYÚSCULA (feas en cursiva ligada). Solo la imagen.
    final displayText = ParchmentText.softenAllCaps(truncated);
    // El renglón avanza exactamente lo mismo que una línea de texto.
    final lineSpacing = fontSize * _lineHeightFactor;

    return Container(
      width: _width,
      constraints: const BoxConstraints(minHeight: _minHeight),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFDF8ED), Color(0xFFEEDFBE)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFA882), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B6914).withValues(alpha: 0.3),
            offset: const Offset(0, 6),
            blurRadius: 12,
          ),
        ],
      ),
      child: CustomPaint(
        painter: _RuledLinesPainter(
          padding: _padding,
          lineSpacing: lineSpacing,
          raiseFactor: _lineRaiseFactor,
          lineColor: const Color(0xFFD4B896).withValues(alpha: 0.4),
        ),
        child: Padding(
          padding: const EdgeInsets.all(_padding),
          child: Text(
            displayText,
            style: GoogleFonts.grandHotel(
              fontSize: fontSize,
              color: const Color(0xFF3D2B1F),
              height: _lineHeightFactor,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painter de líneas de renglón
// ---------------------------------------------------------------------------

class _RuledLinesPainter extends CustomPainter {
  final double padding;
  final double lineSpacing;
  final double raiseFactor;
  final Color lineColor;

  const _RuledLinesPainter({
    required this.padding,
    required this.lineSpacing,
    required this.raiseFactor,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    // Primera raya bajo la primera línea de texto, subida `raiseFactor` para que
    // las letras se apoyen sobre la raya; de ahí en más, un paso por línea →
    // texto y rayas avanzan en lockstep (sin deriva).
    double y = padding + lineSpacing * (1 - raiseFactor);
    while (y < size.height - padding) {
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        paint,
      );
      y += lineSpacing;
    }
  }

  @override
  bool shouldRepaint(_RuledLinesPainter old) => false;
}
