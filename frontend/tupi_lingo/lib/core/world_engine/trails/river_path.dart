import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/world_engine/coordinates/world_bounds.dart';
import 'package:tupi_lingo/core/world_engine/coordinates/world_coordinate.dart';

/// Cubic Bezier segment modeling real river geometries with dynamic width.
class RiverSegment {
  final WorldCoordinate start;
  final WorldCoordinate control1;
  final WorldCoordinate control2;
  final WorldCoordinate end;
  final double startWidth; // Upstream width
  final double endWidth;   // Downstream width

  const RiverSegment({
    required this.start,
    required this.control1,
    required this.control2,
    required this.end,
    this.startWidth = 20.0,
    this.endWidth = 32.0,
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

  /// Evaluates normalized tangent vector (dx, dy) at parametric fraction [t] in [0.0..1.0].
  Offset evaluateTangent(double t) {
    final u = 1.0 - t;
    final c0 = 3 * u * u;
    final c1 = 6 * u * t;
    final c2 = 3 * t * t;

    final dx = c0 * (control1.wx - start.wx) +
        c1 * (control2.wx - control1.wx) +
        c2 * (end.wx - control2.wx);
    final dy = c0 * (control1.wy - start.wy) +
        c1 * (control2.wy - control1.wy) +
        c2 * (end.wy - control2.wy);

    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1e-4) return const Offset(1.0, 0.0);
    return Offset(dx / len, dy / len);
  }
}

/// Continuous historical river basin with multi-pass sculpted banks:
/// - Escarpment trench depression (sunken channel below terrain)
/// - Transition margin (terra batida and fluvial sand banks)
/// - Wet clay contact rim
/// - Deep emerald/jade river water with specular current
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
    this.waterColor = const Color(0xFF1E5245), // Deep Mata Atlantica river green
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
      minX: minX - 120,
      minY: minY - 120,
      maxX: maxX + 120,
      maxY: maxY + 120,
    );
  }

  /// Builds a continuous Flutter [Path] in screen coordinates without disjointed segment caps.
  Path buildScreenPath({
    required double cameraX,
    required double cameraY,
    required double zoom,
    required Size screenSize,
  }) {
    final path = Path();
    if (segments.isEmpty) return path;

    final first = segments.first.start.toScreen(
      cameraX: cameraX,
      cameraY: cameraY,
      zoom: zoom,
      screenSize: screenSize,
    );
    path.moveTo(first.dx, first.dy);

    for (final seg in segments) {
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
      final end = seg.end.toScreen(
        cameraX: cameraX,
        cameraY: cameraY,
        zoom: zoom,
        screenSize: screenSize,
      );
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
    }

    return path;
  }

  /// Computes average river channel width in screen pixels.
  double averageScreenWidth(double zoom) {
    if (segments.isEmpty) return 24.0 * zoom;
    double total = 0.0;
    for (final seg in segments) {
      total += (seg.startWidth + seg.endWidth) * 0.5;
    }
    return (total / segments.length) * zoom;
  }

  // Pre-allocated reusable Paint objects to avoid per-frame GC allocations
  static final Paint _outerMudMarginPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _sandBankPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _wetClayPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _riverCenterPaint = Paint()..style = PaintingStyle.fill;

  static final Paint _currentStreakPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static final Paint _springRipplePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static final Paint _bushPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _reedPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _stonePaint = Paint()..style = PaintingStyle.fill;
  static final Paint _irregularNodePaint = Paint()..style = PaintingStyle.fill;

  /// Renders this natural river seamlessly into the ground with multi-tier sculpted margins.
  void render({
    required Canvas canvas,
    required double cameraX,
    required double cameraY,
    required double zoom,
    required Size screenSize,
    double animationTime = 0.0,
  }) {
    if (segments.isEmpty) return;

    final avgWidth = averageScreenWidth(zoom).clamp(14.0, 115.0);

    // Number of parametric samples per segment for high-fidelity organic curves
    const stepsPerSeg = 12;

    final leftMud = <Offset>[];
    final rightMud = <Offset>[];
    final leftSand = <Offset>[];
    final rightSand = <Offset>[];
    final leftShallow = <Offset>[];
    final rightShallow = <Offset>[];
    final leftDeep = <Offset>[];
    final rightDeep = <Offset>[];
    final centerPts = <Offset>[];
    final normals = <Offset>[];

    for (int segIdx = 0; segIdx < segments.length; segIdx++) {
      final seg = segments[segIdx];
      final isFirstSeg = segIdx == 0;
      final isLastSeg = segIdx == segments.length - 1;
      final stepCount = isLastSeg ? (stepsPerSeg + 1) : stepsPerSeg;

      for (int s = 0; s < stepCount; s++) {
        final t = s / stepsPerSeg;
        final globalT = (segIdx + t) / segments.length;

        final posWorld = seg.evaluate(t);
        final posScreen = posWorld.toScreen(
          cameraX: cameraX,
          cameraY: cameraY,
          zoom: zoom,
          screenSize: screenSize,
        );

        final tangent = seg.evaluateTangent(t);
        final normal = Offset(-tangent.dy, tangent.dx);
        normals.add(normal);

        // Dynamic width with authentic Nascente tapering and Foz expansion
        double baseW = seg.startWidth + (seg.endWidth - seg.startWidth) * t;

        // 1. Nascente Tapering: the headwater stream starts at a narrow spring
        if (isFirstSeg && t < 0.28) {
          final taper = (t / 0.28).clamp(0.04, 1.0);
          baseW *= (taper * taper);
        }

        // 2. Foz Expansion: river mouth widens organically into the ocean/estuary
        if (isLastSeg && t > 0.70) {
          final fozFlare = 1.0 + ((t - 0.70) / 0.30) * 0.75;
          baseW *= fozFlare;
        }

        // 3. Asymmetric Sinusoidal Shoreline Meanders (eliminates rectangular / parallel borders)
        final leftWave = (math.sin(globalT * 26.0 + 1.2) * 0.18 + math.cos(globalT * 52.0) * 0.08) * baseW;
        final rightWave = (math.sin(globalT * 22.0 - 0.8) * 0.20 + math.cos(globalT * 44.0) * 0.09) * baseW;

        final leftHalf = (baseW * 0.5 + leftWave).clamp(1.5, 95.0) * zoom;
        final rightHalf = (baseW * 0.5 + rightWave).clamp(1.5, 95.0) * zoom;

        // Meandering center point with water current wave
        final waterCurrentWave = math.sin(globalT * 18.0 + animationTime * 2.8) * (1.6 * zoom);
        final cPt = posScreen + normal * ((leftHalf - rightHalf) * 0.15 + waterCurrentWave);
        centerPts.add(cPt);

        // Cross-section points
        leftMud.add(posScreen + normal * (leftHalf * 1.65));
        rightMud.add(posScreen - normal * (rightHalf * 1.65));

        leftSand.add(posScreen + normal * (leftHalf * 1.35));
        rightSand.add(posScreen - normal * (rightHalf * 1.35));

        leftShallow.add(posScreen + normal * (leftHalf * 1.08));
        rightShallow.add(posScreen - normal * (rightHalf * 1.08));

        leftDeep.add(posScreen + normal * (leftHalf * 0.78));
        rightDeep.add(posScreen - normal * (rightHalf * 0.78));
      }
    }

    if (centerPts.isEmpty) return;

    final tipStart = centerPts.first;
    final tipEnd = centerPts.last;

    Path buildBand(List<Offset> left, List<Offset> right) {
      final p = Path()..moveTo(tipStart.dx, tipStart.dy);
      for (int i = 0; i < left.length; i++) {
        p.lineTo(left[i].dx, left[i].dy);
      }
      p.lineTo(tipEnd.dx, tipEnd.dy);
      for (int i = right.length - 1; i >= 0; i--) {
        p.lineTo(right[i].dx, right[i].dy);
      }
      p.close();
      return p;
    }

    // ─── 1. Borda Externa de Lama / Leito Aluvial (#3D2919) ─────
    _outerMudMarginPaint.color = const Color(0xFF3D2919).withValues(alpha: 0.65);
    canvas.drawPath(buildBand(leftMud, rightMud), _outerMudMarginPaint);

    // ─── 2. Barranco Orgânico de Areia e Argila Fluvial (#6B4E34) ─────
    _sandBankPaint.color = const Color(0xFF6B4E34).withValues(alpha: 0.88);
    canvas.drawPath(buildBand(leftSand, rightSand), _sandBankPaint);

    // ─── 3. Água Rasa Translúcida das Margens Fluviais (#1B5968) ─────
    _wetClayPaint.color = const Color(0xFF1B5968).withValues(alpha: 0.85);
    canvas.drawPath(buildBand(leftShallow, rightShallow), _wetClayPaint);

    // ─── 4. Canal Central Profundo de Água Viva (waterColor) ─────
    _riverCenterPaint.color = waterColor;
    canvas.drawPath(buildBand(leftDeep, rightDeep), _riverCenterPaint);

    // ─── 5. Correnteza Dinâmica Viva: Filamentos Fluindo da Nascente à Foz ─────
    for (int s = 0; s < 3; s++) {
      final lateralOffset = (s - 1) * (avgWidth * 0.22);
      final streamletPath = Path();
      bool isDrawing = false;
      for (int i = 0; i < centerPts.length; i++) {
        final progress = i / (centerPts.length - 1);
        final flowPhase = (progress * 7.0 - animationTime * 1.5 + s * 0.33) % 1.0;
        if (flowPhase < 0.45) {
          final pt = centerPts[i] + (i < normals.length ? normals[i] * lateralOffset : Offset.zero);
          if (!isDrawing) {
            streamletPath.moveTo(pt.dx, pt.dy);
            isDrawing = true;
          } else {
            streamletPath.lineTo(pt.dx, pt.dy);
          }
        } else {
          isDrawing = false;
        }
      }
      _currentStreakPaint
        ..color = const Color(0xFF7DD3FC).withValues(alpha: s == 1 ? 0.60 : 0.35)
        ..strokeWidth = (2.2 * zoom).clamp(1.2, 4.2)
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(streamletPath, _currentStreakPaint);
    }

    // ─── 6. Reflexos Solares Cintilantes (Sunlight Shimmer) ─────
    for (int i = 2; i < centerPts.length - 2; i += 3) {
      final shimmer = math.sin(i * 1.7 + animationTime * 3.8);
      if (shimmer > 0.68) {
        final shimmerAlpha = ((shimmer - 0.68) / 0.32) * 0.75;
        _stonePaint.color = Colors.white.withValues(alpha: shimmerAlpha);
        final pt = centerPts[i];
        canvas.drawOval(
          Rect.fromCenter(
            center: pt,
            width: (6.5 * zoom).clamp(3.0, 13.0),
            height: (2.4 * zoom).clamp(1.2, 5.0),
          ),
          _stonePaint,
        );
      }
    }

    // ─── 7. A NASCENTE: Olho d'Água Sagrado com Bacia de Pedras e Ondulações Vivas ─────
    _renderSpringSource(
      canvas: canvas,
      springCenter: tipStart,
      zoom: zoom,
      avgWidth: avgWidth,
      animationTime: animationTime,
    );

    // ─── 8. A FOZ: Estuário Fluvial com Bancos de Areia e Deságue em Leque ─────
    _renderEstuaryMouth(
      canvas: canvas,
      mouthCenter: tipEnd,
      normal: normals.isNotEmpty ? normals.last : const Offset(1, 0),
      zoom: zoom,
      avgWidth: avgWidth,
      animationTime: animationTime,
    );

    // ─── 9. Vegetação Ciliar e Seixos Naturais nas Margens ─────
    if (zoom >= 0.50) {
      _renderRiparianDetails(
        canvas: canvas,
        cameraX: cameraX,
        cameraY: cameraY,
        zoom: zoom,
        screenSize: screenSize,
        avgWidth: avgWidth,
      );
    }
  }

  void _renderSpringSource({
    required Canvas canvas,
    required Offset springCenter,
    required double zoom,
    required double avgWidth,
    required double animationTime,
  }) {
    final springR = (avgWidth * 0.60).clamp(14.0, 42.0);

    // 1. Semicírculo de seixos e pedras da montanha ao redor da nascente
    for (int a = 0; a < 7; a++) {
      final ang = -math.pi * 0.8 + a * (math.pi * 0.27);
      final rockPt = springCenter + Offset(math.cos(ang) * springR * 1.15, math.sin(ang) * springR * 0.95);
      _stonePaint.color = (a % 2 == 0) ? const Color(0xFF5A5244) : const Color(0xFF433D33);
      canvas.drawOval(
        Rect.fromCenter(
          center: rockPt,
          width: (9.5 * zoom).clamp(4.5, 19.0),
          height: (6.5 * zoom).clamp(3.0, 13.0),
        ),
        _stonePaint,
      );
    }

    // 2. Bacia de água da nascente (Y-katu / Olho d'Água)
    _wetClayPaint.color = const Color(0xFF1E6F7D).withValues(alpha: 0.95);
    canvas.drawOval(Rect.fromCenter(center: springCenter, width: springR * 1.8, height: springR * 1.3), _wetClayPaint);

    // 3. Olho d'água central profundo
    _riverCenterPaint.color = const Color(0xFF0F4D59);
    canvas.drawCircle(springCenter, springR * 0.55, _riverCenterPaint);

    // 4. Ondas concêntricas vivas borbulhando da nascente
    final rip1 = (animationTime * 1.2) % 1.0;
    final rip2 = (animationTime * 1.2 + 0.5) % 1.0;
    final r1 = springR * 0.3 + rip1 * (springR * 1.4);
    final r2 = springR * 0.3 + rip2 * (springR * 1.4);

    _springRipplePaint
      ..color = const Color(0xFF67E8F9).withValues(alpha: (1.0 - rip1) * 0.80)
      ..strokeWidth = (2.2 * zoom).clamp(1.2, 3.5);
    canvas.drawOval(Rect.fromCenter(center: springCenter, width: r1 * 1.6, height: r1 * 1.1), _springRipplePaint);

    _springRipplePaint
      ..color = const Color(0xFF67E8F9).withValues(alpha: (1.0 - rip2) * 0.80)
      ..strokeWidth = (1.8 * zoom).clamp(1.0, 3.0);
    canvas.drawOval(Rect.fromCenter(center: springCenter, width: r2 * 1.6, height: r2 * 1.1), _springRipplePaint);

    // 5. Brilho do sol refletido na água límpida da nascente
    _stonePaint.color = Colors.white.withValues(alpha: 0.65 + 0.25 * math.sin(animationTime * 3.0));
    canvas.drawCircle(springCenter, (3.5 * zoom).clamp(2.0, 7.0), _stonePaint);
  }

  void _renderEstuaryMouth({
    required Canvas canvas,
    required Offset mouthCenter,
    required Offset normal,
    required double zoom,
    required double avgWidth,
    required double animationTime,
  }) {
    final mouthR = (avgWidth * 0.85).clamp(18.0, 65.0);

    // 1. Banco de areia fluvial submerso na foz
    _sandBankPaint.color = const Color(0xFF8A6B45).withValues(alpha: 0.75);
    canvas.drawOval(
      Rect.fromCenter(
        center: mouthCenter - normal * (mouthR * 0.25),
        width: (16.0 * zoom).clamp(8.0, 32.0),
        height: (8.0 * zoom).clamp(4.0, 16.0),
      ),
      _sandBankPaint,
    );

    // 2. Ondulações suaves de encontro das águas (confluência fluvial-marítima)
    final surfPhase = (animationTime * 1.1) % 1.0;
    final surfR = mouthR * 0.6 + surfPhase * (mouthR * 0.8);
    _springRipplePaint
      ..color = const Color(0xFFBAE6FD).withValues(alpha: (1.0 - surfPhase) * 0.65)
      ..strokeWidth = (2.0 * zoom).clamp(1.0, 3.2);
    canvas.drawOval(
      Rect.fromCenter(center: mouthCenter, width: surfR * 1.8, height: surfR * 1.2),
      _springRipplePaint,
    );
  }

  void _renderRiparianDetails({
    required Canvas canvas,
    required double cameraX,
    required double cameraY,
    required double zoom,
    required Size screenSize,
    required double avgWidth,
  }) {
    const sampleFractions = [0.15, 0.40, 0.65, 0.85];

    for (int segIdx = 0; segIdx < segments.length; segIdx += 2) {
      final seg = segments[segIdx];
      for (final t in sampleFractions) {
        final posWorld = seg.evaluate(t);
        final posScreen = posWorld.toScreen(
          cameraX: cameraX,
          cameraY: cameraY,
          zoom: zoom,
          screenSize: screenSize,
        );

        final tangent = seg.evaluateTangent(t);
        final normal = Offset(-tangent.dy, tangent.dx);
        final bankOffset = (avgWidth * 0.75);

        // Nó irregular de lama/areia na margem (#4A3525)
        _irregularNodePaint.color = const Color(0xFF4A3525).withValues(alpha: 0.75);
        final nodeOffset = Offset(math.sin(segIdx * 3.0 + t * 5.0) * 3.0 * zoom, 0);
        canvas.drawOval(
          Rect.fromCenter(
            center: posScreen + normal * (bankOffset * 1.1) + nodeOffset,
            width: (7.0 * zoom).clamp(3.5, 16.0),
            height: (4.5 * zoom).clamp(2.2, 11.0),
          ),
          _irregularNodePaint,
        );

        // Arbusto na margem esquerda
        final leftBankPt = posScreen + normal * bankOffset;
        _bushPaint.color = const Color(0xFF1B4E2B).withValues(alpha: 0.85);
        canvas.drawCircle(leftBankPt, (4.5 * zoom).clamp(2.5, 10.0), _bushPaint);

        // Juncos na margem esquerda
        _reedPaint.color = const Color(0xFF4D7C0F).withValues(alpha: 0.85);
        canvas.drawOval(
          Rect.fromCenter(
            center: leftBankPt + Offset(normal.dx * 3.0, normal.dy * 3.0),
            width: 2.5 * zoom,
            height: 6.0 * zoom,
          ),
          _reedPaint,
        );

        // Seixo na margem direita
        final rightBankPt = posScreen - normal * bankOffset;
        _stonePaint.color = const Color(0xFF7D7769).withValues(alpha: 0.85);
        canvas.drawOval(
          Rect.fromCenter(center: rightBankPt, width: 4.5 * zoom, height: 2.8 * zoom),
          _stonePaint,
        );
      }
    }
  }

  /// Canonical rivers of Pindorama with realistic proportions and sculpted curves.
  /// The river paths extend well beyond the canvas borders to prevent geometric capsule termination.
  static List<RiverPath> canonicalRivers() {
    return const [
      // 1. Rio Tietê / Anhembi (O grande rio navegável do planalto, fluindo da serra ao interior além das bordas)
      RiverPath(
        id: 'river_tiete',
        nameTupi: 'Anhemby',
        namePt: 'Rio Tietê',
        waterColor: Color(0xFF1A4B6E),
        segments: [
          // Extensão além da borda leste nas escarpas da Serra do Mar
          RiverSegment(
            start: WorldCoordinate(7800, 5600),
            control1: WorldCoordinate(7350, 5450),
            control2: WorldCoordinate(6800, 5380),
            end: WorldCoordinate(6200, 5300),
            startWidth: 20.0,
            endWidth: 24.0,
          ),
          // Nascentes nas encostas da serra
          RiverSegment(
            start: WorldCoordinate(6200, 5300),
            control1: WorldCoordinate(5950, 5200),
            control2: WorldCoordinate(5750, 5080),
            end: WorldCoordinate(5500, 5020),
            startWidth: 24.0,
            endWidth: 28.0,
          ),
          // Descida ao vale do Tamanduateí
          RiverSegment(
            start: WorldCoordinate(5500, 5020),
            control1: WorldCoordinate(5380, 4980),
            control2: WorldCoordinate(5250, 4880),
            end: WorldCoordinate(5120, 4920),
            startWidth: 28.0,
            endWidth: 34.0,
          ),
          // Meandro de Piratininga contornando a colina da taba com curvatura orgânica
          RiverSegment(
            start: WorldCoordinate(5120, 4920),
            control1: WorldCoordinate(4980, 4960),
            control2: WorldCoordinate(4880, 4840),
            end: WorldCoordinate(4750, 4950),
            startWidth: 34.0,
            endWidth: 40.0,
          ),
          // Confluência de várzea com o Tamanduateí
          RiverSegment(
            start: WorldCoordinate(4750, 4950),
            control1: WorldCoordinate(4620, 5060),
            control2: WorldCoordinate(4500, 4890),
            end: WorldCoordinate(4350, 4980),
            startWidth: 40.0,
            endWidth: 46.0,
          ),
          // Médio Tietê
          RiverSegment(
            start: WorldCoordinate(4350, 4980),
            control1: WorldCoordinate(4200, 5080),
            control2: WorldCoordinate(4060, 4860),
            end: WorldCoordinate(3900, 4960),
            startWidth: 46.0,
            endWidth: 52.0,
          ),
          // Meandro do vale ocidental
          RiverSegment(
            start: WorldCoordinate(3900, 4960),
            control1: WorldCoordinate(3740, 5050),
            control2: WorldCoordinate(3610, 4820),
            end: WorldCoordinate(3450, 4920),
            startWidth: 52.0,
            endWidth: 58.0,
          ),
          // Rumo ao interior
          RiverSegment(
            start: WorldCoordinate(3450, 4920),
            control1: WorldCoordinate(3280, 5030),
            control2: WorldCoordinate(3100, 4780),
            end: WorldCoordinate(2900, 4950),
            startWidth: 58.0,
            endWidth: 64.0,
          ),
          // Extensão contínua rumo ao oeste profundo além da borda do canvas
          RiverSegment(
            start: WorldCoordinate(2900, 4950),
            control1: WorldCoordinate(2500, 5060),
            control2: WorldCoordinate(1900, 4860),
            end: WorldCoordinate(1300, 4980),
            startWidth: 64.0,
            endWidth: 72.0,
          ),
          RiverSegment(
            start: WorldCoordinate(1300, 4980),
            control1: WorldCoordinate(700, 5080),
            control2: WorldCoordinate(100, 4880),
            end: WorldCoordinate(-600, 4950),
            startWidth: 72.0,
            endWidth: 80.0,
          ),
        ],
      ),

      // 2. Rio Paraíba do Sul (Vale tectônico da serra, fluindo até o mar atlântico)
      RiverPath(
        id: 'river_paraiba',
        nameTupi: 'Parahyba',
        namePt: 'Rio Paraíba do Sul',
        waterColor: Color(0xFF1A4B6E),
        segments: [
          // Nascente alta estendida além das bordas do planalto
          RiverSegment(
            start: WorldCoordinate(4800, 4950),
            control1: WorldCoordinate(5150, 4860),
            control2: WorldCoordinate(5500, 4800),
            end: WorldCoordinate(5800, 4750),
            startWidth: 18.0,
            endWidth: 22.0,
          ),
          RiverSegment(
            start: WorldCoordinate(5800, 4750),
            control1: WorldCoordinate(6100, 4620),
            control2: WorldCoordinate(6350, 4750),
            end: WorldCoordinate(6600, 4600),
            startWidth: 22.0,
            endWidth: 26.0,
          ),
          RiverSegment(
            start: WorldCoordinate(6600, 4600),
            control1: WorldCoordinate(6850, 4480),
            control2: WorldCoordinate(7100, 4620),
            end: WorldCoordinate(7350, 4520),
            startWidth: 26.0,
            endWidth: 34.0,
          ),
          RiverSegment(
            start: WorldCoordinate(7350, 4520),
            control1: WorldCoordinate(7600, 4420),
            control2: WorldCoordinate(7850, 4560),
            end: WorldCoordinate(8100, 4450),
            startWidth: 34.0,
            endWidth: 42.0,
          ),
          RiverSegment(
            start: WorldCoordinate(8100, 4450),
            control1: WorldCoordinate(8350, 4350),
            control2: WorldCoordinate(8650, 4480),
            end: WorldCoordinate(8950, 4320),
            startWidth: 42.0,
            endWidth: 50.0,
          ),
          // Foz estendida além da borda oceânica
          RiverSegment(
            start: WorldCoordinate(8950, 4320),
            control1: WorldCoordinate(9400, 4200),
            control2: WorldCoordinate(9950, 4100),
            end: WorldCoordinate(10600, 3950),
            startWidth: 50.0,
            endWidth: 62.0,
          ),
        ],
      ),

      // 3. Estuário de Santos / São Vicente (Canal de Enguaguassu)
      RiverPath(
        id: 'river_sao_vicente',
        nameTupi: 'Enguaguassu-y',
        namePt: 'Canal de Santos',
        waterColor: Color(0xFF1A4B6E),
        segments: [
          // Nascente no manguezal continental além da borda
          RiverSegment(
            start: WorldCoordinate(4500, 5150),
            control1: WorldCoordinate(4700, 5240),
            control2: WorldCoordinate(4900, 5320),
            end: WorldCoordinate(5100, 5380),
            startWidth: 20.0,
            endWidth: 26.0,
          ),
          RiverSegment(
            start: WorldCoordinate(5100, 5380),
            control1: WorldCoordinate(5220, 5460),
            control2: WorldCoordinate(5300, 5520),
            end: WorldCoordinate(5380, 5580),
            startWidth: 26.0,
            endWidth: 36.0,
          ),
          RiverSegment(
            start: WorldCoordinate(5380, 5580),
            control1: WorldCoordinate(5460, 5640),
            control2: WorldCoordinate(5520, 5720),
            end: WorldCoordinate(5600, 5800),
            startWidth: 36.0,
            endWidth: 52.0,
          ),
          // Estuário abrindo-se no oceano aberto além da borda
          RiverSegment(
            start: WorldCoordinate(5600, 5800),
            control1: WorldCoordinate(5800, 6000),
            control2: WorldCoordinate(6150, 6300),
            end: WorldCoordinate(6700, 6750),
            startWidth: 52.0,
            endWidth: 70.0,
          ),
        ],
      ),
    ];
  }

  /// Canonical Tietê river basin getter.
  static RiverPath get canonicalTiete =>
      canonicalRivers().firstWhere((r) => r.id == 'river_tiete');

  /// Canonical Paraíba do Sul river basin getter.
  static RiverPath get canonicalParaiba =>
      canonicalRivers().firstWhere((r) => r.id == 'river_paraiba');
}
