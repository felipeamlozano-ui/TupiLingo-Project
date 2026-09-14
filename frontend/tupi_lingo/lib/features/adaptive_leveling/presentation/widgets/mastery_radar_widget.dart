import 'dart:math';
import 'package:flutter/material.dart';
import 'package:tupi_lingo/features/adaptive_leveling/domain/entities/cognitive_profile.dart';

/// 8-Axis Radar Chart visualizing Cognitive Mastery (RFC-012A Chapter 15).
class MasteryRadarWidget extends StatelessWidget {
  final CognitiveProfile profile;
  final double size;
  final Color? accentColor;

  const MasteryRadarWidget({
    super.key,
    required this.profile,
    this.size = 280,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = accentColor ?? theme.colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RadarPainter(
          profile: profile,
          accentColor: primary,
          textColor: theme.colorScheme.onSurface,
          gridColor: theme.colorScheme.outlineVariant.withAlpha(80),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final CognitiveProfile profile;
  final Color accentColor;
  final Color textColor;
  final Color gridColor;

  _RadarPainter({
    required this.profile,
    required this.accentColor,
    required this.textColor,
    required this.gridColor,
  });

  static const List<String> _labels = [
    'Vocabulário',
    'Gramática',
    'Escuta',
    'Leitura',
    'Cultura',
    'Mitologia',
    'Morfologia',
    'Velocidade',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 36; // leave room for labels
    final numAxes = _labels.length;
    final angleStep = (2 * pi) / numAxes;

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 1. Draw concentric web rings (25%, 50%, 75%, 100%)
    for (int ring = 1; ring <= 4; ring++) {
      final ringRadius = (radius / 4) * ring;
      final ringPath = Path();
      for (int i = 0; i < numAxes; i++) {
        final angle = (i * angleStep) - (pi / 2);
        final x = center.dx + ringRadius * cos(angle);
        final y = center.dy + ringRadius * sin(angle);
        if (i == 0) {
          ringPath.moveTo(x, y);
        } else {
          ringPath.lineTo(x, y);
        }
      }
      ringPath.close();
      canvas.drawPath(ringPath, gridPaint);
    }

    // 2. Draw axis rays and labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < numAxes; i++) {
      final angle = (i * angleStep) - (pi / 2);
      final rayEnd = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      canvas.drawLine(center, rayEnd, gridPaint);

      // Label positioning
      final labelOffset = Offset(
        center.dx + (radius + 20) * cos(angle),
        center.dy + (radius + 20) * sin(angle),
      );

      textPainter.text = TextSpan(
        text: _labels[i],
        style: TextStyle(
          color: textColor.withAlpha(180),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      final textPos = Offset(
        labelOffset.dx - (textPainter.width / 2),
        labelOffset.dy - (textPainter.height / 2),
      );
      textPainter.paint(canvas, textPos);
    }

    // 3. Collect 8 dimension values
    final values = [
      profile.vocabulary,
      profile.grammar,
      profile.listening,
      profile.reading,
      profile.cultural,
      profile.mythology,
      profile.morphology,
      profile.speed,
    ];

    // 4. Build user mastery polygon
    final polyPath = Path();
    final points = <Offset>[];

    for (int i = 0; i < numAxes; i++) {
      final val = values[i].clamp(0.05, 1.0);
      final dist = radius * val;
      final angle = (i * angleStep) - (pi / 2);
      final pt = Offset(center.dx + dist * cos(angle), center.dy + dist * sin(angle));
      points.add(pt);
      if (i == 0) {
        polyPath.moveTo(pt.dx, pt.dy);
      } else {
        polyPath.lineTo(pt.dx, pt.dy);
      }
    }
    polyPath.close();

    // 5. Draw filled polygon with gradient
    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor.withAlpha(120),
          accentColor.withAlpha(40),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawPath(polyPath, fillPaint);

    // 6. Draw polygon border
    final borderPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(polyPath, borderPaint);

    // 7. Draw glowing vertices
    final vertexPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    for (final pt in points) {
      canvas.drawCircle(pt, 4.0, vertexPaint);
      canvas.drawCircle(pt, 2.0, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.profile != profile || oldDelegate.accentColor != accentColor;
  }
}
