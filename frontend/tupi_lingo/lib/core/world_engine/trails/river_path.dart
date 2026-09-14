import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/world_engine/coordinates/world_bounds.dart';
import 'package:tupi_lingo/core/world_engine/coordinates/world_coordinate.dart';

/// Cubic Bezier segment modeling real river geometries with dynamic width (RFC-012C Chapter 7).
class RiverSegment {
  final WorldCoordinate start;
  final WorldCoordinate control1;
  final WorldCoordinate control2;
  final WorldCoordinate end;
  final double startWidth; // Narrower upstream
  final double endWidth;   // Wider downstream towards estuary

  const RiverSegment({
    required this.start,
    required this.control1,
    required this.control2,
    required this.end,
    this.startWidth = 12.0,
    this.endWidth = 24.0,
  });

  /// Evaluates cubic Bezier position at parametric fraction [t] in [0.0..1.0].
  WorldCoordinate evaluate(double t) {
    final u = 1.0 - t;
    final tt = t * t;
    final uu = u * u;
    final uuu = uu * u;
    final ttt = tt * t;

    final wx = uuu * start.wx + 3 * uu * t * control1.wx + 3 * u * tt * control2.wx + ttt * end.wx;
    final wy = uuu * start.wy + 3 * uu * t * control1.wy + 3 * u * tt * control2.wy + ttt * end.wy;

    return WorldCoordinate(wx, wy);
  }
}

/// Continuous historical river basin with procedural flow vectors.
class RiverPath {
  final String id;
  final String nameTupi;
  final String namePt;
  final List<RiverSegment> segments;
  final Color waterColor;

  const RiverPath({
    required this.id,
    required this.nameTupi,
    required this.namePt,
    required this.segments,
    this.waterColor = const Color(0xFF2E9383),
  });

  /// Computes AABB bounding box for all control points in this river.
  WorldBounds get bounds {
    if (segments.isEmpty) {
      return const WorldBounds(minX: 0, minY: 0, maxX: 0, maxY: 0);
    }

    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final seg in segments) {
      final pts = [seg.start, seg.control1, seg.control2, seg.end];
      for (final p in pts) {
        minX = math.min(minX, p.wx);
        maxX = math.max(maxX, p.wx);
        minY = math.min(minY, p.wy);
        maxY = math.max(maxY, p.wy);
      }
    }

    return WorldBounds(
      minX: minX - 50,
      minY: minY - 50,
      maxX: maxX + 50,
      maxY: maxY + 50,
    );
  }

  /// Builds a continuous Flutter [Path] in world coordinates.
  Path buildWorldPath() {
    final path = Path();
    if (segments.isEmpty) return path;

    path.moveTo(segments.first.start.wx, segments.first.start.wy);
    for (final seg in segments) {
      path.cubicTo(
        seg.control1.wx, seg.control1.wy,
        seg.control2.wx, seg.control2.wy,
        seg.end.wx, seg.end.wy,
      );
    }
    return path;
  }

  /// Renders this river directly to the [Canvas] in screen coordinates.
  void render({
    required Canvas canvas,
    required double cameraX,
    required double cameraY,
    required double zoom,
    required Size screenSize,
  }) {
    if (segments.isEmpty) return;

    for (final seg in segments) {
      final s = seg.start.toScreen(
        cameraX: cameraX,
        cameraY: cameraY,
        zoom: zoom,
        screenSize: screenSize,
      );
      final c1 = seg.control1.toScreen(
        cameraX: cameraX,
        cameraY: cameraY,
        zoom: zoom,
        screenSize: screenSize,
      );
      final c2 = seg.control2.toScreen(
        cameraX: cameraX,
        cameraY: cameraY,
        zoom: zoom,
        screenSize: screenSize,
      );
      final e = seg.end.toScreen(
        cameraX: cameraX,
        cameraY: cameraY,
        zoom: zoom,
        screenSize: screenSize,
      );

      final path = Path()
        ..moveTo(s.dx, s.dy)
        ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, e.dx, e.dy);

      final avgWidth = ((seg.startWidth + seg.endWidth) / 2.0) * zoom;

      // Soft water glow
      final glowPaint = Paint()
        ..color = waterColor.withValues(alpha: 0.20)
        ..strokeWidth = (avgWidth * 1.8).clamp(3.0, 60.0)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, glowPaint);

      // Main water body
      final riverPaint = Paint()
        ..color = waterColor
        ..strokeWidth = avgWidth.clamp(2.0, 45.0)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, riverPaint);

      // Foam / highlight line
      final foamPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = (avgWidth * 0.25).clamp(1.0, 6.0)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, foamPaint);
    }
  }

  static RiverPath get canonicalTiete => canonicalRivers().first;
  static RiverPath get canonicalParaiba => canonicalRivers().last;

  /// Canonical rivers of Pindorama
  static List<RiverPath> canonicalRivers() {
    return const [
      // Rio Paranã-Panema / Tietê Ancestral
      RiverPath(
        id: 'river_tiete',
        nameTupi: 'Anhembi / Tietê',
        namePt: 'Rio Tietê',
        segments: [
          RiverSegment(
            start: WorldCoordinate(6400, 7200),
            control1: WorldCoordinate(5800, 7100),
            control2: WorldCoordinate(5200, 6800),
            end: WorldCoordinate(4600, 6900),
            startWidth: 10.0,
            endWidth: 28.0,
          ),
          RiverSegment(
            start: WorldCoordinate(4600, 6900),
            control1: WorldCoordinate(4000, 7000),
            control2: WorldCoordinate(3400, 7300),
            end: WorldCoordinate(3000, 7800),
            startWidth: 28.0,
            endWidth: 45.0,
          ),
        ],
      ),
      // Bacia da Guanabara / Rio Paraíba do Sul
      RiverPath(
        id: 'river_paraiba',
        nameTupi: 'Parahyba',
        namePt: 'Rio Paraíba do Sul',
        segments: [
          RiverSegment(
            start: WorldCoordinate(6800, 6900),
            control1: WorldCoordinate(7300, 6700),
            control2: WorldCoordinate(7800, 6600),
            end: WorldCoordinate(8200, 6500),
            startWidth: 14.0,
            endWidth: 36.0,
          ),
        ],
      ),
    ];
  }
}
