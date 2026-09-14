import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// 8-Axis Mastery Dimension
class MasteryDimension {
  final String label;
  final double score; // 0.0 to 1.0

  const MasteryDimension({
    required this.label,
    required this.score,
  });
}

/// 8-Axis Radar Chart representing the holistic mastery of Tupi language & culture.
class MasteryRadarChart extends StatelessWidget {
  final List<MasteryDimension> dimensions;

  const MasteryRadarChart({
    super.key,
    required this.dimensions,
  });

  /// Canonical 8 dimensions
  static List<MasteryDimension> get defaultDimensions => const [
        MasteryDimension(label: 'Fonética', score: 0.82),
        MasteryDimension(label: 'Morfologia', score: 0.68),
        MasteryDimension(label: 'Natureza', score: 0.90),
        MasteryDimension(label: 'Sintaxe', score: 0.58),
        MasteryDimension(label: 'Parentesco', score: 0.74),
        MasteryDimension(label: 'Toponímia', score: 0.88),
        MasteryDimension(label: 'Rituais', score: 0.65),
        MasteryDimension(label: 'Retenção', score: 0.78),
      ];

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: AppTheme.border(context),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 16.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5A93C).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.radar,
                      color: Color(0xFFE5A93C),
                      size: 20.0,
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  Text(
                    'Domínio Multidimensional',
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 4.0,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E5D4E).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: const Text(
                  '8 Eixos BKT',
                  style: TextStyle(
                    fontSize: 11.0,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0E5D4E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Text(
            'Balanço de habilidades linguísticas e assimilação cultural ancestral.',
            style: TextStyle(
              fontSize: 12.0,
              color: AppTheme.textSecondary(context),
            ),
          ),
          const SizedBox(height: 20.0),

          // Radar Canvas
          Center(
            child: SizedBox(
              width: 280.0,
              height: 260.0,
              child: CustomPaint(
                painter: _RadarChartPainter(
                  dimensions: dimensions.length == 8
                      ? dimensions
                      : defaultDimensions,
                  isDark: isDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  final List<MasteryDimension> dimensions;
  final bool isDark;

  _RadarChartPainter({
    required this.dimensions,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2.0, size.height / 2.0);
    final maxRadius = math.min(size.width, size.height) / 2.0 - 32.0;
    final int count = dimensions.length;
    final angleStep = (2 * math.pi) / count;

    final gridPaint = Paint()
      ..color = isDark ? const Color(0x33FFFFFF) : const Color(0x22000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 1. Concentric Web Rings (4 levels: 25%, 50%, 75%, 100%)
    for (int ring = 1; ring <= 4; ring++) {
      final r = maxRadius * (ring / 4.0);
      final ringPath = Path();
      for (int i = 0; i < count; i++) {
        final angle = i * angleStep - (math.pi / 2.0);
        final x = center.dx + r * math.cos(angle);
        final y = center.dy + r * math.sin(angle);
        if (i == 0) {
          ringPath.moveTo(x, y);
        } else {
          ringPath.lineTo(x, y);
        }
      }
      ringPath.close();
      canvas.drawPath(ringPath, gridPaint);
    }

    // 2. Radial Axis Spokes
    final axisPaint = Paint()
      ..color = isDark ? const Color(0x22FFFFFF) : const Color(0x18000000)
      ..strokeWidth = 1.0;

    for (int i = 0; i < count; i++) {
      final angle = i * angleStep - (math.pi / 2.0);
      final x = center.dx + maxRadius * math.cos(angle);
      final y = center.dy + maxRadius * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), axisPaint);

      // Draw Axis Label
      final labelOffset = Offset(
        center.dx + (maxRadius + 18.0) * math.cos(angle),
        center.dy + (maxRadius + 14.0) * math.sin(angle),
      );

      final textSpan = TextSpan(
        text: dimensions[i].label,
        style: TextStyle(
          color: isDark ? const Color(0xFFB0BEC5) : const Color(0xFF455A64),
          fontSize: 10.0,
          fontWeight: FontWeight.w600,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(
          labelOffset.dx - (textPainter.width / 2.0),
          labelOffset.dy - (textPainter.height / 2.0),
        ),
      );
    }

    // 3. User Data Polygon Fill & Stroke
    final dataPath = Path();
    final points = <Offset>[];

    for (int i = 0; i < count; i++) {
      final angle = i * angleStep - (math.pi / 2.0);
      final r = maxRadius * dimensions[i].score.clamp(0.05, 1.0);
      final pt = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      points.add(pt);
      if (i == 0) {
        dataPath.moveTo(pt.dx, pt.dy);
      } else {
        dataPath.lineTo(pt.dx, pt.dy);
      }
    }
    dataPath.close();

    // Fill
    final fillPaint = Paint()
      ..color = const Color(0xFFE5A93C).withValues(alpha: 0.32)
      ..style = PaintingStyle.fill;
    canvas.drawPath(dataPath, fillPaint);

    // Stroke
    final strokePaint = Paint()
      ..color = const Color(0xFFFFB300)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(dataPath, strokePaint);

    // Vertex points
    final dotPaint = Paint()
      ..color = const Color(0xFF0E5D4E)
      ..style = PaintingStyle.fill;
    final dotBorder = Paint()
      ..color = const Color(0xFFFFD54F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final pt in points) {
      canvas.drawCircle(pt, 4.0, dotPaint);
      canvas.drawCircle(pt, 4.0, dotBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) {
    return oldDelegate.dimensions != dimensions || oldDelegate.isDark != isDark;
  }
}
