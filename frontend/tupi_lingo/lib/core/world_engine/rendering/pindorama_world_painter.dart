import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../camera/camera_state.dart';
import '../camera/world_camera_controller.dart';
import '../coordinates/world_bounds.dart';
import '../fog/fog_engine.dart';
import '../fog/fog_state.dart';
import '../landmarks/historical_landmark.dart';
import '../particles/world_particle_pool.dart';
import '../terrain/terrain_mesh_engine.dart';
import '../theme/pindorama_theme_palette.dart';
import '../trails/historical_trail.dart';
import '../trails/historical_overlay.dart';
import '../trails/river_path.dart';
import '../villages/authentic_village_composer.dart';
import '../villages/village_node.dart';
import 'isometric_depth_sorter.dart';
import '../../../features/historical_map/domain/entities/quest_node.dart';
import '../../../features/historical_map/presentation/widgets/historical_timeline_slider.dart';

/// Master multi-layer CustomPainter for the Pindorama 3D World Engine.
/// Replaces isolated floating 2D elements with a unified, continuous 3D-feeling game world.
///
/// Rendering Layers:
/// 1. Continuous Geological Terrain Mesh & Atlantic Coastline (TerrainMeshEngine)
/// 2. Natural River Basins with Sculpted Sand & Clay Margins (RiverPath)
/// 3. Organic Earthen Trails & Peabiru Network
/// 4. Village Ground Clearing Footprints & Footpaths
/// 5. Unified 2.5D Isometric Render Queue with Strict Y-Sorting (Trees, Ocas, Bonfires, Bridges, Forts)
/// 6. Village Environmental Labels
/// 7. Historical Epoch Alliances & Overlays
/// 8. Fog of War (Atmospheric Mist & Exploration Clearances)
/// 9. Contextual Atmospheric Particles (WorldParticlePool)
/// 10. Selection Reticle & Active Quest Beacons
class PindoramaWorldPainter extends CustomPainter {
  final CameraState? _camera;
  final WorldCameraController? cameraController;
  final List<VillageNode> villages;
  final List<RiverPath> rivers;
  final List<HistoricalTrail> trails;
  final List<HistoricalOverlay> overlays;
  final List<HistoricalLandmark> landmarks;
  final FogState fogState;
  final WorldParticlePool particlePool;
  final PindoramaThemePalette palette;
  final VillageNode? selectedVillage;
  final HistoricalLandmark? selectedLandmark;
  final QuestNode? activeQuest;
  final ui.FragmentShader? fogShader;
  final double? _animationTime;
  final double Function()? getAnimationTime;
  final HistoricalEpoch currentEpoch;
  final HistoricalEpoch previousEpoch;
  final double epochTransitionProgress;

  CameraState get camera => cameraController?.state ?? _camera ?? const CameraState();
  double get animationTime => getAnimationTime?.call() ?? _animationTime ?? 0.0;

  // Pre-allocated static reusable Paint instances (zero heap allocations per paint frame)
  static final Paint _trailGroundBedPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final Paint _trailPackedDirtPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final Paint _trailCenterStepPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static final Paint _solidTrailGlowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final Paint _solidTrailCorePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final Paint _dashedTrailPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static final Paint _badgeFillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _badgeBorderPaint = Paint()..style = PaintingStyle.stroke;
  static final Paint _haloRingPaint = Paint()..style = PaintingStyle.stroke;
  static final Paint _haloGlowPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _reticlePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final Paint _beaconWavePaint = Paint()..style = PaintingStyle.stroke;

  PindoramaWorldPainter({
    super.repaint,
    CameraState? camera,
    this.cameraController,
    required this.villages,
    required this.rivers,
    required this.trails,
    this.overlays = const [],
    List<HistoricalLandmark>? landmarks,
    required this.fogState,
    required this.particlePool,
    PindoramaThemePalette? palette,
    this.selectedVillage,
    this.selectedLandmark,
    this.activeQuest,
    this.fogShader,
    double? animationTime,
    this.getAnimationTime,
    this.currentEpoch = HistoricalEpoch.pre1500,
    this.previousEpoch = HistoricalEpoch.pre1500,
    this.epochTransitionProgress = 1.0,
  })  : _camera = camera,
        _animationTime = animationTime,
        landmarks = landmarks ?? HistoricalLandmark.canonicalLandmarks,
        palette = palette ?? PindoramaThemePalette.current();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final visibleBounds = camera.getVisibleBounds(size);

    // Camada 1: Terreno Contínuo & Relevo Topográfico
    TerrainMeshEngine.instance.renderTerrain(
      canvas: canvas,
      size: size,
      camera: camera,
      palette: palette,
      animationTime: animationTime,
    );

    // Camada 2: Rios e Bacias Hidrográficas Esculpidos com Margens de Areia e Argila
    _paintRivers(canvas, size, visibleBounds);

    // Camada 3: Trilhas Naturais e Sistema de Trilha de Fases (Estilo Peabiru)
    _paintOrganicTrails(canvas, size, visibleBounds);
    _paintCurriculumPhaseTrail(canvas, size, visibleBounds);

    // Camada 4: Decalques de Solo das Aldeias (Terreiro / Okara e Roças)
    _paintVillageGroundDecals(canvas, size, visibleBounds);

    // Camada 5: Fila Unificada Isométrica com Strict Y-Sorting (Árvores, Ocas, Fogueiras, Pontes, Feitorias, Fortes)
    IsometricDepthSorter.instance.renderDepthSortedScene(
      canvas: canvas,
      camera: camera,
      screenSize: size,
      villages: villages,
      landmarks: landmarks,
      rivers: rivers,
      trails: trails,
      currentEpoch: currentEpoch,
      previousEpoch: previousEpoch,
      epochTransitionProgress: epochTransitionProgress,
      animationTime: animationTime,
    );

    // Camada 6: Névoa de Guerra (Fog of War: Bruma montanhosa atmosférica sobre o mundo físico)
    FogEngine.renderFog(
      canvas: canvas,
      size: size,
      camera: camera,
      fogState: fogState,
      shader: fogShader,
      time: animationTime,
    );

    // Camada 7: Overlays Históricos e Territórios
    _paintOverlays(canvas, size);

    // Camada 8: Rótulos Ambientais e Estados Visuais das Aldeias (HUD de Aprendizado e Navegação)
    _paintVillageLabels(canvas, size, visibleBounds);
    _paintVillageStatusBadges(canvas, size, visibleBounds);

    // Camada 9: Quest Beacon Ativo (Se Houver)
    if (activeQuest != null) {
      _paintQuestBeacon(canvas, size, activeQuest!);
    }

    // Camada 10: Partículas Atmosféricas (Bruma, Vaga-lumes, Cinzas)
    particlePool.render(
      canvas: canvas,
      camera: camera,
      size: size,
    );

    // Camada 11: Retículo de Seleção
    if (selectedVillage != null) {
      _paintSelectedReticle(canvas, size, selectedVillage!);
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
        animationTime: animationTime,
      );
    }
  }

  void _paintOrganicTrails(Canvas canvas, Size size, WorldBounds visibleBounds) {
    final zoom = camera.zoom;

    for (final trail in trails) {
      if (!trail.bounds.intersects(visibleBounds)) continue;

      final path = trail.toScreenPath(
        cameraX: camera.x,
        cameraY: camera.y,
        zoom: zoom,
        screenSize: size,
      );

      final baseWidth = (trail.strokeWidth * zoom).clamp(3.5, 20.0);

      // 1. Faixa Externa de Desgaste de Solo
      _trailGroundBedPaint
        ..color = const Color(0xFF5E3F24).withValues(alpha: 0.38)
        ..strokeWidth = baseWidth * 2.8;
      canvas.drawPath(path, _trailGroundBedPaint);

      // 2. Trilho Principal de Terra Compactada Vermelha/Marrom
      _trailPackedDirtPaint
        ..color = const Color(0xFF9E6533).withValues(alpha: 0.85)
        ..strokeWidth = baseWidth * 1.6;
      canvas.drawPath(path, _trailPackedDirtPaint);

      // 3. Faixa de Pisoteio Ancestral / Cascalho Dourado
      _trailCenterStepPaint
        ..color = const Color(0xFFD4A359).withValues(alpha: 0.75)
        ..strokeWidth = baseWidth * 0.75;
      canvas.drawPath(path, _trailCenterStepPaint);
    }
  }

  /// Desenha a trilha visível conectando em sequência as aldeias (Aldeia 1 -> Aldeia 2 -> Aldeia 3...)
  /// - Aldeias concluídas: Linha contínua sólida iluminada (#FFD54F / #FFB800)
  /// - Aldeias futuras/bloqueadas: Linha tracejada [10, 8] de terra batida (#C4A482 / #D2B48C) com 4px de largura
  void _paintCurriculumPhaseTrail(Canvas canvas, Size size, WorldBounds visibleBounds) {
    if (villages.length < 2) return;

    const canonicalOrder = ['piratininga', 'sao_vicente', 'ubatuba', 'guanabara', 'cabo_frio'];
    final orderedVillages = <VillageNode>[];

    for (final id in canonicalOrder) {
      final matches = villages.where((v) => v.id == id);
      if (matches.isNotEmpty) {
        orderedVillages.add(matches.first);
      }
    }
    for (final v in villages) {
      if (!orderedVillages.contains(v)) {
        orderedVillages.add(v);
      }
    }

    final zoom = camera.zoom;
    final strokeW = (4.0 * zoom).clamp(2.5, 6.0);

    for (int i = 0; i < orderedVillages.length - 1; i++) {
      final v1 = orderedVillages[i];
      final v2 = orderedVillages[i + 1];

      final p1 = v1.coordinate.toScreen(
        cameraX: camera.x,
        cameraY: camera.y,
        zoom: zoom,
        screenSize: size,
      );
      final p2 = v2.coordinate.toScreen(
        cameraX: camera.x,
        cameraY: camera.y,
        zoom: zoom,
        screenSize: size,
      );

      // Conexão curva Bézier orgânica contornando a topografia natural
      final mid = Offset(
        (p1.dx + p2.dx) * 0.5 + (p2.dy - p1.dy) * 0.12,
        (p1.dy + p2.dy) * 0.5 - (p2.dx - p1.dx) * 0.12,
      );

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, p2.dx, p2.dy);

      final isCompletedConnection = v1.status.isCompleted &&
          (v2.status.isCompleted || v2.status.isCurrent);

      if (isCompletedConnection) {
        // Trilha conectada concluída: linha contínua sólida iluminada
        _solidTrailGlowPaint
          ..color = const Color(0xFFFFB800).withValues(alpha: 0.38)
          ..strokeWidth = strokeW * 2.2;
        canvas.drawPath(path, _solidTrailGlowPaint);

        _solidTrailCorePaint
          ..color = const Color(0xFFFFD54F)
          ..strokeWidth = strokeW;
        canvas.drawPath(path, _solidTrailCorePaint);
      } else {
        // Trilha futura: linha tracejada de terra batida [10, 8] de 4px
        _dashedTrailPaint
          ..color = const Color(0xFFC4A482)
          ..strokeWidth = strokeW;

        for (final metric in path.computeMetrics()) {
          double distance = 0.0;
          while (distance < metric.length) {
            final double len = math.min(10.0 * zoom.clamp(0.8, 1.4), metric.length - distance);
            final extract = metric.extractPath(distance, distance + len);
            canvas.drawPath(extract, _dashedTrailPaint);
            distance += 18.0 * zoom.clamp(0.8, 1.4); // 10px dash + 8px gap
          }
        }
      }
    }
  }

  void _paintVillageGroundDecals(Canvas canvas, Size size, WorldBounds visibleBounds) {
    for (final village in villages) {
      if (village.coordinate.x < visibleBounds.minX - 400 ||
          village.coordinate.x > visibleBounds.maxX + 400 ||
          village.coordinate.y < visibleBounds.minY - 400 ||
          village.coordinate.y > visibleBounds.maxY + 400) {
        continue;
      }

      if (!village.isUnlocked) {
        if (village.isFrontier || village.stage != VillageEvolutionStage.oculta) {
          _paintFrontierVillageSilhouette(canvas, size, village);
        }
        continue;
      }

      AuthenticVillageComposer.instance.renderVillageGroundDecals(
        canvas: canvas,
        size: size,
        camera: camera,
        village: village,
      );
    }
  }

  void _paintVillageLabels(Canvas canvas, Size size, WorldBounds visibleBounds) {
    for (final village in villages) {
      if (!visibleBounds.contains(village.coordinate)) continue;
      // Frontier villages already receive an exclusive padlock HUD badge from _paintFrontierVillageSilhouette
      if (!village.isUnlocked) continue;

      final isSelected = selectedVillage?.id == village.id;
      AuthenticVillageComposer.instance.renderVillageLabel(
        canvas: canvas,
        size: size,
        camera: camera,
        village: village,
        isSelected: isSelected,
      );
    }
  }

  /// Camada 6: Estados Visuais de Cada Aldeia (VillageStatus)
  /// - COMPLETED: Ícone de check dourado/verde sobre a aldeia
  /// - CURRENT: Anel concêntrico pulsante / halo #FFB800 e badge flutuante "COMEÇAR"
  /// - LOCKED: Pequeno ícone de cadeado sobre o nó
  void _paintVillageStatusBadges(Canvas canvas, Size size, WorldBounds visibleBounds) {
    final zoom = camera.zoom;
    final scaleFactor = zoom.clamp(0.75, 1.4);

    for (final village in villages) {
      if (village.coordinate.x < visibleBounds.minX - 300 ||
          village.coordinate.x > visibleBounds.maxX + 300 ||
          village.coordinate.y < visibleBounds.minY - 300 ||
          village.coordinate.y > visibleBounds.maxY + 300) {
        continue;
      }

      final screenPt = village.coordinate.toScreen(
        cameraX: camera.x,
        cameraY: camera.y,
        zoom: zoom,
        screenSize: size,
      );

      // Viewport screen culling
      if (screenPt.dx < -100 ||
          screenPt.dx > size.width + 100 ||
          screenPt.dy < -100 ||
          screenPt.dy > size.height + 100) {
        continue;
      }

      switch (village.status) {
        case VillageStatus.completed:
          _paintCompletedBadge(canvas, screenPt, scaleFactor);
          break;
        case VillageStatus.current:
          _paintCurrentPulseAndBadge(canvas, screenPt, scaleFactor);
          break;
        case VillageStatus.locked:
          _paintLockedPadlock(canvas, screenPt, scaleFactor);
          break;
      }
    }
  }

  void _paintCompletedBadge(Canvas canvas, Offset screenPt, double s) {
    final badgeCenter = screenPt + Offset(0, -26.0 * s);

    // 1. Sombra do selo
    _badgeFillPaint.color = Colors.black.withValues(alpha: 0.35);
    canvas.drawCircle(badgeCenter + const Offset(0, 2.0), 13.0 * s, _badgeFillPaint);

    // 2. Fundo verde esmeralda ancestral
    _badgeFillPaint.color = const Color(0xFF0F3E22).withValues(alpha: 0.95);
    canvas.drawCircle(badgeCenter, 13.0 * s, _badgeFillPaint);

    // 3. Borda dourada brilhante
    _badgeBorderPaint
      ..color = const Color(0xFFFFD54F)
      ..strokeWidth = 2.0 * s
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(badgeCenter, 13.0 * s, _badgeBorderPaint);

    // 4. Ícone de "check" desenhado com precisão vetorial
    final checkPath = Path()
      ..moveTo(badgeCenter.dx - 5.5 * s, badgeCenter.dy + 0.2 * s)
      ..lineTo(badgeCenter.dx - 1.5 * s, badgeCenter.dy + 4.2 * s)
      ..lineTo(badgeCenter.dx + 5.5 * s, badgeCenter.dy - 4.0 * s);
    _badgeBorderPaint
      ..color = const Color(0xFF4ADE80)
      ..strokeWidth = 2.5 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(checkPath, _badgeBorderPaint);
  }

  void _paintCurrentPulseAndBadge(Canvas canvas, Offset screenPt, double s) {
    // 1. Anéis concêntricos pulsantes (#FFB800) contínuos
    final p1 = (animationTime * 1.5) % 1.0;
    final p2 = (animationTime * 1.5 + 0.5) % 1.0;
    final baseRadius = 34.0 * s;

    // Onda 1
    final r1 = baseRadius + p1 * 38.0 * s;
    _haloRingPaint
      ..color = const Color(0xFFFFB800).withValues(alpha: (1.0 - p1) * 0.85)
      ..strokeWidth = (2.8 * (1.0 - p1 * 0.4) * s).clamp(1.4, 4.2);
    canvas.drawCircle(screenPt, r1, _haloRingPaint);

    // Onda 2
    final r2 = baseRadius + p2 * 38.0 * s;
    _haloRingPaint
      ..color = const Color(0xFFFFB800).withValues(alpha: (1.0 - p2) * 0.85)
      ..strokeWidth = (2.2 * (1.0 - p2 * 0.4) * s).clamp(1.2, 3.6);
    canvas.drawCircle(screenPt, r2, _haloRingPaint);

    // Halo brilhante interno central
    final corePulse = 0.85 + 0.15 * math.sin(animationTime * 3.5);
    _haloGlowPaint
      ..color = const Color(0xFFFFB800).withValues(alpha: 0.24 * corePulse);
    canvas.drawCircle(screenPt, baseRadius * 0.95, _haloGlowPaint);

    // 2. Tag com badge flutuante "COMEÇAR" com sutil flutuação (bobbing)
    final bob = math.sin(animationTime * 3.5) * 3.5;
    final badgeCenter = Offset(screenPt.dx, screenPt.dy - 46.0 * s + bob);

    final textSpan = TextSpan(
      text: '⚔ COMEÇAR',
      style: TextStyle(
        color: Colors.white,
        fontSize: (11.0 * s).clamp(9.5, 14.0),
        fontWeight: FontWeight.w900,
        letterSpacing: 1.0,
        shadows: const [
          Shadow(
            offset: Offset(0, 1.2),
            blurRadius: 3.0,
            color: Colors.black87,
          ),
        ],
      ),
    );

    final tp = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final pillW = tp.width + 16.0 * s;
    final pillH = tp.height + 8.0 * s;
    final pillRect = Rect.fromCenter(
      center: badgeCenter,
      width: pillW,
      height: pillH,
    );

    // Sombra do pill
    _badgeFillPaint.color = Colors.black.withValues(alpha: 0.38);
    canvas.drawRRect(
      RRect.fromRectAndRadius(pillRect.translate(0, 2.0), Radius.circular(pillH * 0.5)),
      _badgeFillPaint,
    );

    // Corpo do pill (#D97706 / âmbar vivo)
    _badgeFillPaint.color = const Color(0xFFD97706);
    canvas.drawRRect(
      RRect.fromRectAndRadius(pillRect, Radius.circular(pillH * 0.5)),
      _badgeFillPaint,
    );

    // Borda iluminada dourada (#FFD54F)
    _badgeBorderPaint
      ..color = const Color(0xFFFFD54F)
      ..strokeWidth = 1.8 * s
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(pillRect, Radius.circular(pillH * 0.5)),
      _badgeBorderPaint,
    );

    tp.paint(canvas, Offset(pillRect.left + 8.0 * s, pillRect.top + 4.0 * s));
  }

  void _paintLockedPadlock(Canvas canvas, Offset screenPt, double s) {
    final lockCenter = screenPt + Offset(0, -22.0 * s);

    // Fundo circular escuro fosco
    _badgeFillPaint.color = const Color(0xDD1E293B);
    canvas.drawCircle(lockCenter, 11.5 * s, _badgeFillPaint);

    // Borda em tom de aço ardósia
    _badgeBorderPaint
      ..color = const Color(0xFF64748B)
      ..strokeWidth = 1.4 * s
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(lockCenter, 11.5 * s, _badgeBorderPaint);

    // Corpo do cadeado (retângulo arredondado)
    final bodyRect = Rect.fromCenter(
      center: lockCenter + Offset(0, 2.0 * s),
      width: 9.5 * s,
      height: 7.5 * s,
    );
    _badgeFillPaint.color = const Color(0xFF94A3B8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(1.8 * s)),
      _badgeFillPaint,
    );

    // Arco metálico do cadeado
    final shacklePath = Path()
      ..moveTo(lockCenter.dx - 3.0 * s, lockCenter.dy + 0.8 * s)
      ..lineTo(lockCenter.dx - 3.0 * s, lockCenter.dy - 2.8 * s)
      ..arcToPoint(
        Offset(lockCenter.dx + 3.0 * s, lockCenter.dy - 2.8 * s),
        radius: Radius.circular(3.0 * s),
      )
      ..lineTo(lockCenter.dx + 3.0 * s, lockCenter.dy + 0.8 * s);
    _badgeBorderPaint
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.6 * s
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(shacklePath, _badgeBorderPaint);
  }

  void _paintFrontierVillageSilhouette(
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

    final zoom = camera.zoom;
    final r = (42.0 * zoom).clamp(22.0, 85.0);
    final pulse = 0.85 + 0.15 * math.sin(animationTime * 2.8);

    // Earthen shadow in mist (organic oval)
    final mistPaint = Paint()
      ..color = const Color(0xFF233038).withValues(alpha: 0.40 * pulse)
      ..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromCenter(center: screenPt, width: r * 2.2, height: r * 1.5), mistPaint);

    // Shrouded maloca silhouette in fog
    final malocaRect = Rect.fromCenter(center: screenPt - Offset(0, r * 0.15), width: r * 1.25, height: r * 0.65);
    final malocaPaint = Paint()
      ..color = const Color(0xFF33464D).withValues(alpha: 0.60)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(malocaRect, Radius.circular(r * 0.3)), malocaPaint);

    // Rustic Wood Padlock Badge
    final lockCenter = screenPt + Offset(0, r * 0.15);
    final badgePaint = Paint()
      ..color = const Color(0xEE0F172A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(lockCenter, 14.0 * zoom, badgePaint);

    final badgeBorder = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.85 * pulse)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(lockCenter, 14.0 * zoom, badgeBorder);

    final lockPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.lock_rounded.codePoint),
        style: TextStyle(
          fontSize: 16.0 * zoom,
          fontFamily: Icons.lock_rounded.fontFamily,
          color: const Color(0xFFF59E0B),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    lockPainter.paint(
      canvas,
      Offset(lockCenter.dx - lockPainter.width / 2, lockCenter.dy - lockPainter.height / 2),
    );

    // Placa sutil da fronteira
    _paintFrontierLabel(canvas, screenPt, village, r);
  }

  void _paintFrontierLabel(
    Canvas canvas,
    Offset screenPt,
    VillageNode village,
    double nodeRadius,
  ) {
    if (camera.zoom < 0.70) return;

    final textSpan = TextSpan(
      text: '🔒 ${village.tupiName}',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.4,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final pillWidth = textPainter.width + 16.0;
    final pillHeight = textPainter.height + 6.0;
    final pillRect = Rect.fromCenter(
      center: Offset(screenPt.dx, screenPt.dy - nodeRadius - 12.0),
      width: pillWidth,
      height: pillHeight,
    );

    final pillPaint = Paint()
      ..color = const Color(0xEE1E293B)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(pillRect, const Radius.circular(6.0)), pillPaint);

    final pillBorder = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.65)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(pillRect, const Radius.circular(6.0)), pillBorder);

    textPainter.paint(
      canvas,
      Offset(pillRect.left + 8.0, pillRect.top + 3.0),
    );
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

  void _paintQuestBeacon(Canvas canvas, Size size, QuestNode quest) {
    final targetScreen = quest.targetCoordinate.toScreen(
      cameraX: camera.x,
      cameraY: camera.y,
      zoom: camera.zoom,
      screenSize: size,
    );

    final wave = (animationTime * 45.0) % 55.0;
    final wavePaint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: (1.0 - wave / 55.0) * 0.75)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(targetScreen, 22.0 + wave, wavePaint);
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

    final hw = (85.0 * camera.zoom).clamp(45.0, 180.0);
    final hh = (60.0 * camera.zoom).clamp(32.0, 130.0);
    final cornerLen = (18.0 * camera.zoom).clamp(10.0, 36.0);

    // Subtle tactical corner brackets [ ] indicating the focused settlement
    final reticlePaint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.85)
      ..strokeWidth = (2.2 * camera.zoom).clamp(1.4, 4.0)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final left = screenPt.dx - hw;
    final right = screenPt.dx + hw;
    final top = screenPt.dy - hh;
    final bottom = screenPt.dy + hh;

    // Top-Left
    canvas.drawLine(Offset(left, top + cornerLen), Offset(left, top), reticlePaint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLen, top), reticlePaint);

    // Top-Right
    canvas.drawLine(Offset(right - cornerLen, top), Offset(right, top), reticlePaint);
    canvas.drawLine(Offset(right, top), Offset(right, top + cornerLen), reticlePaint);

    // Bottom-Left
    canvas.drawLine(Offset(left, bottom - cornerLen), Offset(left, bottom), reticlePaint);
    canvas.drawLine(Offset(left, bottom), Offset(left + cornerLen, bottom), reticlePaint);

    // Bottom-Right
    canvas.drawLine(Offset(right - cornerLen, bottom), Offset(right, bottom), reticlePaint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - cornerLen), reticlePaint);
  }

  @override
  bool shouldRepaint(covariant PindoramaWorldPainter oldDelegate) {
    if (cameraController != oldDelegate.cameraController) return true;
    if (getAnimationTime != oldDelegate.getAnimationTime) return true;
    if (cameraController == null && oldDelegate.camera != camera) return true;
    if (getAnimationTime == null && oldDelegate.animationTime != animationTime) return true;

    return oldDelegate.villages != villages ||
        oldDelegate.rivers != rivers ||
        oldDelegate.trails != trails ||
        oldDelegate.overlays != overlays ||
        oldDelegate.landmarks != landmarks ||
        oldDelegate.fogState != fogState ||
        oldDelegate.palette != palette ||
        oldDelegate.selectedVillage != selectedVillage ||
        oldDelegate.selectedLandmark != selectedLandmark ||
        oldDelegate.activeQuest != activeQuest ||
        oldDelegate.fogShader != fogShader ||
        oldDelegate.currentEpoch != currentEpoch ||
        oldDelegate.previousEpoch != previousEpoch ||
        oldDelegate.epochTransitionProgress != epochTransitionProgress;
  }
}
