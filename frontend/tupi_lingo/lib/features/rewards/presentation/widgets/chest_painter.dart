import 'package:flutter/material.dart';

/// Desenha o corpo da Igaçaba / Baú Ancestral com arte vetorial Marajoara e Tupi.
class MarajoaraChestBasePainter extends CustomPainter {
  final Color primaryColor;
  final Color darkColor;
  final Color accentColor;
  final Color goldColor;

  MarajoaraChestBasePainter({
    this.primaryColor = const Color(0xFFD08A45),
    this.darkColor = const Color(0xFF8C4A19),
    this.accentColor = const Color(0xFF0E5D4E),
    this.goldColor = const Color(0xFFFFD166),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final basePaint = Paint()
      ..shader = LinearGradient(
        colors: [primaryColor, darkColor],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    // Corpo do Baú / Urna
    final bodyPath = Path()
      ..moveTo(w * 0.1, 0)
      ..lineTo(w * 0.9, 0)
      ..cubicTo(w * 0.98, h * 0.4, w * 0.95, h * 0.9, w * 0.82, h)
      ..lineTo(w * 0.18, h)
      ..cubicTo(w * 0.05, h * 0.9, w * 0.02, h * 0.4, w * 0.1, 0)
      ..close();

    // Sombra de profundidade inferior
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(bodyPath, shadowPaint);

    canvas.drawPath(bodyPath, basePaint);

    // Faixas decorativas com grafismos Marajoara
    final linePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    // Faixa central
    canvas.drawLine(Offset(w * 0.08, h * 0.45), Offset(w * 0.92, h * 0.45), linePaint);

    // Grafismos de labirinto/losangos sagrados (linhas quebradas)
    final patternPaint = Paint()
      ..color = goldColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final patternPath = Path();
    for (double x = w * 0.16; x < w * 0.82; x += 22) {
      patternPath.moveTo(x, h * 0.40);
      patternPath.lineTo(x + 10, h * 0.45);
      patternPath.lineTo(x, h * 0.50);
      patternPath.lineTo(x + 10, h * 0.55);
    }
    canvas.drawPath(patternPath, patternPaint);

    // Fechadura / Selo Ancestral Dourado
    final latchPaint = Paint()
      ..shader = RadialGradient(
        colors: [goldColor, const Color(0xFFB8860B)],
      ).createShader(Rect.fromCircle(center: Offset(w * 0.5, h * 0.18), radius: 16));

    canvas.drawCircle(Offset(w * 0.5, h * 0.18), 14, latchPaint);

    final latchInner = Paint()
      ..color = darkColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.5, h * 0.18), 4.5, latchInner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Desenha a tampa do Baú Ancestral que rotaciona em perspectiva 3D.
class MarajoaraChestLidPainter extends CustomPainter {
  final Color primaryColor;
  final Color highlightColor;
  final Color goldColor;

  MarajoaraChestLidPainter({
    this.primaryColor = const Color(0xFFE29B56),
    this.highlightColor = const Color(0xFFF9C88C),
    this.goldColor = const Color(0xFFFFD166),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final lidPaint = Paint()
      ..shader = LinearGradient(
        colors: [highlightColor, primaryColor],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    // Tampa arqueada em domo
    final lidPath = Path()
      ..moveTo(0, h)
      ..cubicTo(w * 0.15, 0, w * 0.85, 0, w, h)
      ..close();

    canvas.drawPath(lidPath, lidPaint);

    // Friso superior dourado
    final trimPaint = Paint()
      ..color = goldColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final trimPath = Path()
      ..moveTo(w * 0.08, h * 0.85)
      ..cubicTo(w * 0.25, h * 0.15, w * 0.75, h * 0.15, w * 0.92, h * 0.85);

    canvas.drawPath(trimPath, trimPaint);

    // Alça superior da tampa (Cabaça / Puxador de Madeira)
    final knobPaint = Paint()..color = const Color(0xFF5D2E0C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.15), width: 28, height: 10),
        const Radius.circular(5),
      ),
      knobPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
