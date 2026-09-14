import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../camera/camera_state.dart';
import '../coordinates/world_bounds.dart';
import '../coordinates/world_coordinate.dart';
import '../fog/fog_engine.dart';
import '../fog/fog_state.dart';
import '../particles/world_particle_pool.dart';
import '../trails/historical_trail.dart';
import '../trails/historical_overlay.dart';
import '../trails/river_path.dart';
import '../villages/village_node.dart';
import '../../../features/historical_map/domain/entities/quest_node.dart';

/// Master multi-layer CustomPainter for the Pindorama World Engine (RFC-012C Patch 1).
class PindoramaWorldPainter extends CustomPainter {
  final CameraState camera;
  final List<VillageNode> villages;
  final List<RiverPath> rivers;
  final List<HistoricalTrail> trails;
  final List<HistoricalOverlay> overlays;
  final FogState fogState;
  final WorldParticlePool particlePool;
  final VillageNode? selectedVillage;
  final QuestNode? activeQuest;
  final ui.FragmentShader? fogShader;
  final double animationTime;

  PindoramaWorldPainter({
    required this.camera,
    required this.villages,
    required this.rivers,
    required this.trails,
    this.overlays = const [],
    required this.fogState,
    required this.particlePool,
    this.selectedVillage,
    this.activeQuest,
    this.fogShader,
    this.animationTime = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final visibleBounds = camera.getVisibleBounds(size);

    // 1. Terrain & Biomes
    _paintTerrainAndBiomes(canvas, size, visibleBounds);

    // 2. Historical Alliances & Regional Overlays (Chapter 8)
    _paintOverlays(canvas, size);

    // 3. Bezier Rivers
    _paintRivers(canvas, size, visibleBounds);

    // 4. Historical Trails
    _paintTrails(canvas, size, visibleBounds);

    // 5. Village Nodes & Evolution Stages V2 (Chapter 7)
    _paintVillages(canvas, size, visibleBounds);

    // 6. Active Quest Beacon (Chapter 9)
    if (activeQuest != null) {
      _paintQuestBeacon(canvas, size, activeQuest!);
    }

    // 7. Fog of War
    FogEngine.renderFog(
      canvas: canvas,
      size: size,
      camera: camera,
      fogState: fogState,
      shader: fogShader,
      time: animationTime,
    );

    // 8. Atmospheric Contextual Particles
    particlePool.render(
      canvas: canvas,
      camera: camera,
      size: size,
    );

    // 9. Selected Village Reticle & Halo (Chapter 6)
    if (selectedVillage != null) {
      _paintSelectedReticle(canvas, size, selectedVillage!);
    }
  }

  void _paintTerrainAndBiomes(
    Canvas canvas,
    Size size,
    WorldBounds visibleBounds,
  ) {
    // Background deep ancient forest base
    final bgPaint = Paint()..color = const Color(0xFF0D1B14);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw Ocean / Coast along South-East
    final oceanStart = const WorldCoordinate(5800, 5800).toScreen(
      cameraX: camera.x,
      cameraY: camera.y,
      zoom: camera.zoom,
      screenSize: size,
    );
    final oceanEnd = const WorldCoordinate(10000, 10000).toScreen(
      cameraX: camera.x,
      cameraY: camera.y,
      zoom: camera.zoom,
      screenSize: size,
    );

    final oceanPaint = Paint()
      ..shader = ui.Gradient.linear(
        oceanStart,
        oceanEnd,
        [const Color(0xFF0F2B38), const Color(0xFF0A1B24)],
      );
    final oceanRect = Rect.fromPoints(oceanStart, oceanEnd);
    canvas.drawRect(oceanRect, oceanPaint);

    // Biome Patches
    _drawBiomePatch(
      canvas: canvas,
      size: size,
      center: const WorldCoordinate(5000, 5000),
      radius: 1800.0,
      color: const Color(0xFF1B3B2B), // Mata Atlântica deep emerald
    );

    _drawBiomePatch(
      canvas: canvas,
      size: size,
      center: const WorldCoordinate(5600, 5500),
      radius: 1500.0,
      color: const Color(0xFF163229), // Litoral e restingas
    );

    _drawBiomePatch(
      canvas: canvas,
      size: size,
      center: const WorldCoordinate(4200, 4200),
      radius: 1900.0,
      color: const Color(0xFF2C3923), // Cerrado transition
    );
  }

  void _drawBiomePatch({
    required Canvas canvas,
    required Size size,
    required WorldCoordinate center,
    required double radius,
    required Color color,
  }) {
    final screenCenter = center.toScreen(
      cameraX: camera.x,
      cameraY: camera.y,
      zoom: camera.zoom,
      screenSize: size,
    );
    final screenRadius = radius * camera.zoom;

    final paint = Paint()
      ..shader = ui.Gradient.radial(
        screenCenter,
        screenRadius,
        [color.withValues(alpha: 0.55), Colors.transparent],
      );

    canvas.drawCircle(screenCenter, screenRadius, paint);
  }

  void _paintOverlays(Canvas canvas, Size size) {
    for (final overlay in overlays) {
      overlay.render(
        canvas: canvas,
        camera: camera,
        size: size,
        animationTime: animationTime,
      );
    }
  }

  void _paintRivers(Canvas canvas, Size size, WorldBounds visibleBounds) {
    for (final river in rivers) {
      if (!river.bounds.intersects(visibleBounds)) continue;
      river.render(
        canvas: canvas,
        cameraX: camera.x,
        cameraY: camera.y,
        zoom: camera.zoom,
        screenSize: size,
      );
    }
  }

  void _paintTrails(Canvas canvas, Size size, WorldBounds visibleBounds) {
    for (final trail in trails) {
      if (!trail.bounds.intersects(visibleBounds)) continue;

      final path = trail.toScreenPath(
        cameraX: camera.x,
        cameraY: camera.y,
        zoom: camera.zoom,
        screenSize: size,
      );

      // Trail Glow
      final glowPaint = Paint()
        ..color = trail.color.withValues(alpha: 0.22)
        ..strokeWidth = trail.strokeWidth * camera.zoom * 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, glowPaint);

      // Main dashed trail
      final trailPaint = Paint()
        ..color = trail.color
        ..strokeWidth = (trail.strokeWidth * camera.zoom).clamp(1.5, 8.0)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, trailPaint);
    }
  }

  void _paintVillages(Canvas canvas, Size size, WorldBounds visibleBounds) {
    for (final village in villages) {
      if (village.coordinate.x < visibleBounds.minX - 200 ||
          village.coordinate.x > visibleBounds.maxX + 200 ||
          village.coordinate.y < visibleBounds.minY - 200 ||
          village.coordinate.y > visibleBounds.maxY + 200) {
        continue;
      }

      final screenPt = village.coordinate.toScreen(
        cameraX: camera.x,
        cameraY: camera.y,
        zoom: camera.zoom,
        screenSize: size,
      );

      final baseRadius = switch (village.stage) {
        VillageEvolutionStage.oculta => 10.0,
        VillageEvolutionStage.descoberta => 15.0,
        VillageEvolutionStage.explorada => 19.0,
        VillageEvolutionStage.dominada => 24.0,
        VillageEvolutionStage.historica => 30.0,
      } * camera.zoom.clamp(0.7, 2.0);

      // Evolution Stage V2 rendering (Chapter 7)
      if (village.stage == VillageEvolutionStage.oculta) {
        // Stage 0: Mysterious faint silhouette
        final occultPaint = Paint()
          ..color = const Color(0x55455A64)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(screenPt, baseRadius, occultPaint);
        continue;
      }

      // 1. Territory Pulse Aura
      final pulse = 0.85 + 0.15 * math.sin(animationTime * 2.5 + village.coordinate.x);
      final auraPaint = Paint()
        ..color = (village.stage == VillageEvolutionStage.historica
                ? const Color(0xFFFFD54F)
                : const Color(0xFFE5A93C))
            .withValues(alpha: 0.20 * pulse)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(screenPt, baseRadius * 1.8, auraPaint);

      // 2. Village Base Token Circle
      final nodePaint = Paint()
        ..color = switch (village.stage) {
          VillageEvolutionStage.descoberta => const Color(0xFF8D6E63),
          VillageEvolutionStage.explorada => const Color(0xFF2E7D32),
          VillageEvolutionStage.dominada => const Color(0xFFEF6C00),
          VillageEvolutionStage.historica => const Color(0xFFFFB300),
          VillageEvolutionStage.oculta => Colors.grey,
        }
        ..style = PaintingStyle.fill;
      canvas.drawCircle(screenPt, baseRadius, nodePaint);

      // 3. Ring border
      final ringPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.90)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(screenPt, baseRadius, ringPaint);

      // 4. Central Icon / Emblem
      final icon = switch (village.stage) {
        VillageEvolutionStage.descoberta => Icons.nature,
        VillageEvolutionStage.explorada => Icons.home,
        VillageEvolutionStage.dominada => Icons.fort,
        VillageEvolutionStage.historica => Icons.auto_awesome,
        VillageEvolutionStage.oculta => Icons.help_outline,
      };

      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: baseRadius * 0.95,
            fontFamily: icon.fontFamily,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      iconPainter.paint(
        canvas,
        Offset(screenPt.dx - iconPainter.width / 2, screenPt.dy - iconPainter.height / 2),
      );

      // 5. Node Pill Label (when zoom permits)
      if (camera.zoom > 0.60) {
        _paintVillageLabel(canvas, screenPt, village, baseRadius);
      }
    }
  }

  void _paintVillageLabel(
    Canvas canvas,
    Offset screenPt,
    VillageNode village,
    double nodeRadius,
  ) {
    final textSpan = TextSpan(
      text: village.tupiName,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.3,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final pillWidth = textPainter.width + 16.0;
    final pillHeight = textPainter.height + 6.0;
    final pillRect = Rect.fromCenter(
      center: Offset(screenPt.dx, screenPt.dy + nodeRadius + 12.0),
      width: pillWidth,
      height: pillHeight,
    );

    final pillPaint = Paint()
      ..color = const Color(0xEE0B1519)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(pillRect, const Radius.circular(10.0)),
      pillPaint,
    );

    final pillBorder = Paint()
      ..color = const Color(0x66E5A93C)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(pillRect, const Radius.circular(10.0)),
      pillBorder,
    );

    textPainter.paint(
      canvas,
      Offset(pillRect.left + 8.0, pillRect.top + 3.0),
    );
  }

  void _paintQuestBeacon(Canvas canvas, Size size, QuestNode quest) {
    final targetScreen = quest.targetCoordinate.toScreen(
      cameraX: camera.x,
      cameraY: camera.y,
      zoom: camera.zoom,
      screenSize: size,
    );

    final wave = (animationTime * 45.0) % 55.0;
    final wavePaint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: (1.0 - wave / 55.0) * 0.7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(targetScreen, 24.0 + wave, wavePaint);
  }

  void _paintSelectedReticle(
    Canvas canvas,
    Size size,
    VillageNode village,
  ) {
    final screenPt = village.coordinate.toScreen(
      cameraX: camera.x,
      cameraY: camera.y,
      zoom: camera.zoom,
      screenSize: size,
    );

    final ringRadius = 38.0 * camera.zoom.clamp(0.8, 2.0);
    final pulse = 1.0 + 0.08 * math.sin(animationTime * 6.0);

    // Concentric glowing halo
    final haloPaint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.35)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(screenPt, ringRadius * pulse, haloPaint);

    final outerPaint = Paint()
      ..color = const Color(0xFFE5A93C)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(screenPt, ringRadius * pulse + 8.0, outerPaint);
  }

  @override
  bool shouldRepaint(covariant PindoramaWorldPainter oldDelegate) {
    return true; // Continuously animated for 120 FPS pulse, particles, and springs
  }
}
