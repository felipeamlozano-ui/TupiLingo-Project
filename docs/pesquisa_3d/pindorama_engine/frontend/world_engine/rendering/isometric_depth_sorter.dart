import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../camera/camera_state.dart';
import '../coordinates/world_bounds.dart';
import '../coordinates/world_coordinate.dart';
import '../landmarks/historical_landmark.dart';
import '../vegetation/vegetation_engine.dart';
import '../villages/village_node.dart';
import '../villages/authentic_village_composer.dart';
import '../trails/historical_trail.dart';
import '../trails/river_path.dart';
import '../../../../features/historical_map/presentation/widgets/historical_timeline_slider.dart';

/// Base class for all 2.5D physical entities participating in Isometric Y-Sorting.
abstract class IsometricRenderItem {
  /// Base ground contact Y coordinate in world space.
  /// Elements with lower Y (North) render behind elements with higher Y (South).
  double get baseWy;

  /// World X coordinate.
  double get baseWx;

  /// Renders the entity with depth-sorted priority.
  void render({
    required Canvas canvas,
    required CameraState camera,
    required Size screenSize,
    required double animationTime,
    required double epochAlpha,
    required double epochScale,
  });
}

/// Tree or vegetation item participating in Y-Sorting.
class TreeIsometricItem extends IsometricRenderItem {
  final TreeInstance tree;

  // Pre-allocated reusable Paint objects to avoid per-tree GC allocations
  static final Paint _sharedShadowPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _sharedTrunkPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _sharedFoliagePaint = Paint()..style = PaintingStyle.fill;
  static final Paint _sharedLayerPaint = Paint();

  TreeIsometricItem(this.tree);

  @override
  double get baseWy => tree.wy;

  @override
  double get baseWx => tree.wx;

  @override
  void render({
    required Canvas canvas,
    required CameraState camera,
    required Size screenSize,
    required double animationTime,
    required double epochAlpha,
    required double epochScale,
  }) {
    final zoom = camera.zoom;
    final baseR = (26.0 * tree.scale * zoom).clamp(4.0, 95.0);

    final screenPt = tree.coordinate.toScreen(
      cameraX: camera.x,
      cameraY: camera.y,
      zoom: zoom,
      screenSize: screenSize,
    );

    // Viewport Culling simples:
    // Se o retângulo da árvore estiver fora da viewport, ignore o desenho imediatamente
    final cullMargin = baseR * 1.8;
    if (screenPt.dx + cullMargin < 0 ||
        screenPt.dx - cullMargin > screenSize.width ||
        screenPt.dy + cullMargin < 0 ||
        screenPt.dy - cullMargin > screenSize.height) {
      return;
    }

    final int lod = zoom >= 1.2 ? 0 : (zoom >= 0.70 ? 1 : 2);

    VegetationEngine.instance.renderSingleTree(
      canvas: canvas,
      screenPt: screenPt,
      tree: tree,
      zoom: zoom * epochScale,
      lod: lod,
      shadowPaint: _sharedShadowPaint,
      trunkPaint: _sharedTrunkPaint,
      foliagePaint: _sharedFoliagePaint,
      screenSize: screenSize,
    );
  }
}

/// Straw Oca or longhouse participating in Y-Sorting.
class OcaBuildingIsometricItem extends IsometricRenderItem {
  final WorldCoordinate villageCoord;
  final Offset localOffset;
  final double width;
  final double height;
  final double rotation;
  final bool isMain;
  final bool isMastered;
  final VillageStatus villageStatus;

  // Pre-allocated static reusable Paint instances
  static final Paint _sharedAoPaint = Paint()
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
  static final Paint _sharedShadowPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _sharedFoundationPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _sharedRoofShadedPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _sharedRoofMidPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _sharedRoofSunlitPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _sharedRidgePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final Paint _sharedDoorPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _sharedLayerPaint = Paint();
  static final Paint _sharedLockedFilterPaint = Paint()
    ..colorFilter = const ColorFilter.mode(Colors.grey, BlendMode.saturation);

  OcaBuildingIsometricItem({
    required this.villageCoord,
    required this.localOffset,
    required this.width,
    required this.height,
    this.rotation = 0.0,
    this.isMain = false,
    this.isMastered = false,
    this.villageStatus = VillageStatus.completed,
  });

  @override
  double get baseWy => villageCoord.wy + localOffset.dy + height * 0.35;

  @override
  double get baseWx => villageCoord.wx + localOffset.dx;

  @override
  void render({
    required Canvas canvas,
    required CameraState camera,
    required Size screenSize,
    required double animationTime,
    required double epochAlpha,
    required double epochScale,
  }) {
    final centerWorld = WorldCoordinate(
      villageCoord.wx + localOffset.dx,
      villageCoord.wy + localOffset.dy,
    );
    final screenPt = centerWorld.toScreen(
      cameraX: camera.x,
      cameraY: camera.y,
      zoom: camera.zoom,
      screenSize: screenSize,
    );

    final zoom = camera.zoom * epochScale;
    final w = width * zoom;
    final h = height * zoom;

    // Viewport Culling simples para a estrutura
    if (screenPt.dx + w < 0 ||
        screenPt.dx - w > screenSize.width ||
        screenPt.dy + h < 0 ||
        screenPt.dy - h > screenSize.height) {
      return;
    }

    canvas.save();
    canvas.translate(screenPt.dx, screenPt.dy);
    canvas.rotate(rotation);

    final isLocked = villageStatus == VillageStatus.locked;
    final ocaAlpha = (isLocked ? 0.65 : 1.0) * epochAlpha;

    // 1. Ambient Occlusion Base Shadow
    _sharedAoPaint.color = const Color(0xFF0C0603).withValues(alpha: 0.60 * ocaAlpha);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, h * 0.20), width: w * 1.05, height: h * 0.45),
        Radius.circular(h * 0.22),
      ),
      _sharedAoPaint,
    );

    // 2. Projected Ground Shadow (Southeast)
    _sharedShadowPaint.color = const Color(0xFF140B06).withValues(alpha: 0.40 * ocaAlpha);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w * 0.16, h * 0.30), width: w * 1.15, height: h * 0.65),
        Radius.circular(h * 0.30),
      ),
      _sharedShadowPaint,
    );

    // 3. Compacted Earth Base
    _sharedFoundationPaint.color = const Color(0xFF634125).withValues(alpha: ocaAlpha);
    final fRect = Rect.fromCenter(center: Offset(0, h * 0.18), width: w * 0.96, height: h * 0.40);
    canvas.drawRRect(RRect.fromRectAndRadius(fRect, Radius.circular(h * 0.20)), _sharedFoundationPaint);

    // 4. Conical Thatch Roof (Sapê / Pindoba com iluminação 3D)
    _sharedRoofShadedPaint.color = (isLocked ? const Color(0xFF5A4D3B) : const Color(0xFF6E502B)).withValues(alpha: ocaAlpha);
    _sharedRoofMidPaint.color = (isLocked
        ? const Color(0xFF7A6B52)
        : (isMain ? const Color(0xFFA67C3B) : const Color(0xFF9E7438))).withValues(alpha: ocaAlpha);
    _sharedRoofSunlitPaint.color = (isLocked
        ? const Color(0xFF95856B)
        : (isMain ? const Color(0xFFC9A056) : const Color(0xFFBD954E))).withValues(alpha: ocaAlpha);

    final roofRect = Rect.fromCenter(center: Offset(0, -h * 0.08), width: w * 0.98, height: h * 0.85);

    // Base do teto
    canvas.drawRRect(RRect.fromRectAndRadius(roofRect, Radius.circular(h * 0.36)), _sharedRoofShadedPaint);

    // Cúpula central
    final innerRoofRect = Rect.fromCenter(center: Offset(-w * 0.05, -h * 0.14), width: w * 0.82, height: h * 0.68);
    canvas.drawRRect(RRect.fromRectAndRadius(innerRoofRect, Radius.circular(h * 0.30)), _sharedRoofMidPaint);

    // Crista iluminada a Noroeste
    final sunlitRect = Rect.fromCenter(center: Offset(-w * 0.14, -h * 0.20), width: w * 0.52, height: h * 0.45);
    canvas.drawRRect(RRect.fromRectAndRadius(sunlitRect, Radius.circular(h * 0.22)), _sharedRoofSunlitPaint);

    // Cumeeira de palha trançada
    _sharedRidgePaint
      ..color = (isLocked ? const Color(0xFFA8997A) : const Color(0xFFD4B36D)).withValues(alpha: ocaAlpha)
      ..strokeWidth = (2.4 * zoom).clamp(1.2, 4.8);
    canvas.drawLine(Offset(-w * 0.35, -h * 0.18), Offset(w * 0.35, -h * 0.18), _sharedRidgePaint);

    // Entrada da oca (abertura frontal escura)
    _sharedDoorPaint.color = const Color(0xFF1F1209).withValues(alpha: ocaAlpha);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, h * 0.24), width: w * 0.18, height: h * 0.26),
        Radius.circular(w * 0.08),
      ),
      _sharedDoorPaint,
    );

    canvas.restore();
  }
}

/// Central sacred bonfire (fogueira / tataendy) with flame and ember particles.
class VillageHearthIsometricItem extends IsometricRenderItem {
  final WorldCoordinate villageCoord;
  final Offset localOffset;
  final int seed;

  VillageHearthIsometricItem({
    required this.villageCoord,
    required this.localOffset,
    required this.seed,
  });

  @override
  double get baseWy => villageCoord.wy + localOffset.dy;

  @override
  double get baseWx => villageCoord.wx + localOffset.dx;

  @override
  void render({
    required Canvas canvas,
    required CameraState camera,
    required Size screenSize,
    required double animationTime,
    required double epochAlpha,
    required double epochScale,
  }) {
    final centerWorld = WorldCoordinate(
      villageCoord.wx + localOffset.dx,
      villageCoord.wy + localOffset.dy,
    );
    final screenPt = centerWorld.toScreen(
      cameraX: camera.x,
      cameraY: camera.y,
      zoom: camera.zoom,
      screenSize: screenSize,
    );

    final zoom = camera.zoom * epochScale;
    final r = (14.0 * zoom).clamp(7.0, 32.0);

    // 1. Charcoal Ash Base (cinzas e pedras do fogão)
    final ashPaint = Paint()..color = const Color(0xFF1E140D);
    canvas.drawCircle(screenPt, r * 1.1, ashPaint);

    // Pedras circundantes
    final stonePaint = Paint()..color = const Color(0xFF5D5348);
    for (int i = 0; i < 7; i++) {
      final ang = (i / 7.0) * 2 * math.pi;
      final sx = screenPt.dx + math.cos(ang) * (r * 0.95);
      final sy = screenPt.dy + math.sin(ang) * (r * 0.85);
      canvas.drawCircle(Offset(sx, sy), 2.2 * zoom, stonePaint);
    }

    // 2. Glowing Warm Fire Ember Aura
    final flicker = 0.85 + 0.15 * math.sin(animationTime * 9.0 + seed);
    final auraPaint = Paint()
      ..shader = ui.Gradient.radial(
        screenPt,
        r * 2.2 * flicker,
        [
          const Color(0xFFFF9800).withValues(alpha: 0.55 * epochAlpha),
          const Color(0xFFE65100).withValues(alpha: 0.25 * epochAlpha),
          Colors.transparent,
        ],
        [0.0, 0.55, 1.0],
      );
    canvas.drawCircle(screenPt, r * 2.2 * flicker, auraPaint);

    // 3. Flame Tongue Core
    final flameHeight = (r * 1.35 * flicker).clamp(8.0, 38.0);
    final flamePath = Path()
      ..moveTo(screenPt.dx - r * 0.45, screenPt.dy + r * 0.15)
      ..quadraticBezierTo(screenPt.dx - r * 0.30, screenPt.dy - flameHeight * 0.5, screenPt.dx, screenPt.dy - flameHeight)
      ..quadraticBezierTo(screenPt.dx + r * 0.30, screenPt.dy - flameHeight * 0.5, screenPt.dx + r * 0.45, screenPt.dy + r * 0.15)
      ..close();

    final flamePaint = Paint()
      ..shader = ui.Gradient.linear(
        screenPt + Offset(0, r * 0.2),
        screenPt - Offset(0, flameHeight),
        [const Color(0xFFFF5722), const Color(0xFFFFC107), const Color(0xFFFFF9C4)],
        [0.0, 0.65, 1.0],
      );
    canvas.drawPath(flamePath, flamePaint);
  }
}

/// 1532 Portuguese Feitoria / Trading Post timber warehouse.
class FeitoriaTradingPostIsometricItem extends IsometricRenderItem {
  final WorldCoordinate coord;
  final double width;
  final double height;

  FeitoriaTradingPostIsometricItem({
    required this.coord,
    this.width = 72.0,
    this.height = 44.0,
  });

  @override
  double get baseWy => coord.wy + height * 0.35;

  @override
  double get baseWx => coord.wx;

  @override
  void render({
    required Canvas canvas,
    required CameraState camera,
    required Size screenSize,
    required double animationTime,
    required double epochAlpha,
    required double epochScale,
  }) {
    if (epochAlpha <= 0.01) return;

    if (epochAlpha <= 0.01) return;

    final screenPt = coord.toScreen(
      cameraX: camera.x,
      cameraY: camera.y,
      zoom: camera.zoom,
      screenSize: screenSize,
    );

    final zoom = camera.zoom * epochScale;
    final w = width * zoom;
    final h = height * zoom;

    canvas.save();
    canvas.translate(screenPt.dx, screenPt.dy);

    // Sombra projetada
    final shadowPaint = Paint()..color = const Color(0xFF120B06).withValues(alpha: 0.45 * epochAlpha);
    canvas.drawRect(Rect.fromLTWH(-w * 0.45 + w * 0.15, -h * 0.40 + h * 0.25, w, h * 0.9), shadowPaint);

    // Paredes de toras de madeira e taipa
    final wallPaint = Paint()..color = const Color(0xFF6B4B32).withValues(alpha: epochAlpha);
    canvas.drawRect(Rect.fromCenter(center: Offset(0, h * 0.12), width: w * 0.88, height: h * 0.55), wallPaint);

    // Telhado de telhas cerâmicas / madeira colonial com 2 águas
    final roofShade = Paint()..color = const Color(0xFF8D4A27).withValues(alpha: epochAlpha);
    final roofSun = Paint()..color = const Color(0xFFBD6638).withValues(alpha: epochAlpha);

    // Água leste (sombra)
    final eastRoof = Path()
      ..moveTo(0, -h * 0.45)
      ..lineTo(w * 0.52, -h * 0.15)
      ..lineTo(w * 0.52, h * 0.05)
      ..lineTo(0, -h * 0.25)
      ..close();
    canvas.drawPath(eastRoof, roofShade);

    // Água oeste (iluminada a Noroeste)
    final westRoof = Path()
      ..moveTo(0, -h * 0.45)
      ..lineTo(-w * 0.52, -h * 0.15)
      ..lineTo(-w * 0.52, h * 0.05)
      ..lineTo(0, -h * 0.25)
      ..close();
    canvas.drawPath(westRoof, roofSun);

    // Cumeeira
    final ridgePaint = Paint()
      ..color = const Color(0xFFE28B55).withValues(alpha: epochAlpha)
      ..strokeWidth = (2.2 * zoom).clamp(1.0, 4.0)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, -h * 0.45), Offset(0, -h * 0.25), ridgePaint);

    // Caixotes e barris de pau-brasil em frente
    final cratePaint = Paint()..color = const Color(0xFF533822).withValues(alpha: epochAlpha);
    canvas.drawRect(Rect.fromLTWH(-w * 0.35, h * 0.28, 8.0 * zoom, 8.0 * zoom), cratePaint);
    canvas.drawRect(Rect.fromLTWH(-w * 0.22, h * 0.25, 9.0 * zoom, 9.0 * zoom), cratePaint);

    canvas.restore();
  }
}

/// 1554 Colonial Jesuit Mission Fort & Stone Chapel.
class ColonialMissionFortIsometricItem extends IsometricRenderItem {
  final WorldCoordinate coord;
  final double width;
  final double height;

  ColonialMissionFortIsometricItem({
    required this.coord,
    this.width = 86.0,
    this.height = 56.0,
  });

  @override
  double get baseWy => coord.wy + height * 0.40;

  @override
  double get baseWx => coord.wx;

  @override
  void render({
    required Canvas canvas,
    required CameraState camera,
    required Size screenSize,
    required double animationTime,
    required double epochAlpha,
    required double epochScale,
  }) {
    if (epochAlpha <= 0.01) return;

    final screenPt = coord.toScreen(
      cameraX: camera.x,
      cameraY: camera.y,
      zoom: camera.zoom,
      screenSize: screenSize,
    );

    final zoom = camera.zoom * epochScale;
    final w = width * zoom;
    final h = height * zoom;

    canvas.save();
    canvas.translate(screenPt.dx, screenPt.dy);

    // Sombra geral
    final shadowPaint = Paint()..color = const Color(0xFF100D09).withValues(alpha: 0.45 * epochAlpha);
    canvas.drawRect(Rect.fromLTWH(-w * 0.45 + w * 0.18, -h * 0.40 + h * 0.28, w * 1.1, h * 0.95), shadowPaint);

    // Paredes de taipa de pilão caiada (branco-amarelado colonial)
    final wallPaint = Paint()..color = const Color(0xFFE4DFD3).withValues(alpha: epochAlpha);
    canvas.drawRect(Rect.fromCenter(center: Offset(0, h * 0.12), width: w * 0.85, height: h * 0.60), wallPaint);

    // Torre sineira colonial à esquerda
    final towerPaint = Paint()..color = const Color(0xFFD3CCC0).withValues(alpha: epochAlpha);
    final towerRect = Rect.fromLTWH(-w * 0.42, -h * 0.55, w * 0.26, h * 0.85);
    canvas.drawRect(towerRect, towerPaint);

    // Telhado piramidal da torre
    final towerRoofPath = Path()
      ..moveTo(-w * 0.42, -h * 0.55)
      ..lineTo(-w * 0.29, -h * 0.85)
      ..lineTo(-w * 0.16, -h * 0.55)
      ..close();
    final roofPaint = Paint()..color = const Color(0xFFA8512D).withValues(alpha: epochAlpha);
    canvas.drawPath(towerRoofPath, roofPaint);

    // Pequena cruz no topo
    final crossPaint = Paint()
      ..color = const Color(0xFF3E2723).withValues(alpha: epochAlpha)
      ..strokeWidth = (2.0 * zoom).clamp(1.0, 3.5);
    canvas.drawLine(Offset(-w * 0.29, -h * 0.85), Offset(-w * 0.29, -h * 0.96), crossPaint);
    canvas.drawLine(Offset(-w * 0.33, -h * 0.92), Offset(-w * 0.25, -h * 0.92), crossPaint);

    // Telhado colonial principal de duas águas
    final mainRoofShade = Paint()..color = const Color(0xFF944525).withValues(alpha: epochAlpha);
    final mainRoofSun = Paint()..color = const Color(0xFFBD5B32).withValues(alpha: epochAlpha);

    final eastRoof = Path()
      ..moveTo(w * 0.05, -h * 0.35)
      ..lineTo(w * 0.46, -h * 0.10)
      ..lineTo(w * 0.46, h * 0.06)
      ..lineTo(w * 0.05, -h * 0.18)
      ..close();
    canvas.drawPath(eastRoof, mainRoofShade);

    final westRoof = Path()
      ..moveTo(w * 0.05, -h * 0.35)
      ..lineTo(-w * 0.18, -h * 0.10)
      ..lineTo(-w * 0.18, h * 0.06)
      ..lineTo(w * 0.05, -h * 0.18)
      ..close();
    canvas.drawPath(westRoof, mainRoofSun);

    // Portal de arco colonial de entrada
    final doorPaint = Paint()..color = const Color(0xFF3E2723).withValues(alpha: epochAlpha);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w * 0.12, h * 0.26), width: w * 0.14, height: h * 0.28),
        Radius.circular(w * 0.07),
      ),
      doorPaint,
    );

    canvas.restore();
  }
}

/// 1554 Wooden Bridge crossing river channels.
class ColonialWoodenBridgeIsometricItem extends IsometricRenderItem {
  final WorldCoordinate startCoord;
  final WorldCoordinate endCoord;
  final double bridgeWidth;

  ColonialWoodenBridgeIsometricItem({
    required this.startCoord,
    required this.endCoord,
    this.bridgeWidth = 24.0,
  });

  @override
  double get baseWy => (startCoord.wy + endCoord.wy) * 0.5;

  @override
  double get baseWx => (startCoord.wx + endCoord.wx) * 0.5;

  @override
  void render({
    required Canvas canvas,
    required CameraState camera,
    required Size screenSize,
    required double animationTime,
    required double epochAlpha,
    required double epochScale,
  }) {
    if (epochAlpha <= 0.01) return;

    final p1 = startCoord.toScreen(
      cameraX: camera.x,
      cameraY: camera.y,
      zoom: camera.zoom,
      screenSize: screenSize,
    );
    final p2 = endCoord.toScreen(
      cameraX: camera.x,
      cameraY: camera.y,
      zoom: camera.zoom,
      screenSize: screenSize,
    );

    final zoom = camera.zoom * epochScale;
    final w = bridgeWidth * zoom;

    final dir = (p2 - p1);
    final len = dir.distance;
    if (len < 1.0) return;
    final norm = Offset(-dir.dy / len, dir.dx / len);

    canvas.save();

    // 1. Sombra da ponte sobre a água
    final shadowPaint = Paint()
      ..color = const Color(0xFF0A181A).withValues(alpha: 0.55 * epochAlpha)
      ..strokeWidth = w * 1.15
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(p1 + const Offset(3.0, 4.0), p2 + const Offset(3.0, 4.0), shadowPaint);

    // 2. Pilares de madeira cravados no leito do rio
    final postPaint = Paint()
      ..color = const Color(0xFF3E2723).withValues(alpha: epochAlpha)
      ..strokeWidth = (3.5 * zoom).clamp(1.8, 6.0)
      ..strokeCap = StrokeCap.round;
    const postCount = 4;
    for (int i = 0; i <= postCount; i++) {
      final t = i / postCount;
      final centerPt = p1 + dir * t;
      canvas.drawLine(centerPt - norm * (w * 0.45), centerPt - norm * (w * 0.45) + Offset(0, 8.0 * zoom), postPaint);
      canvas.drawLine(centerPt + norm * (w * 0.45), centerPt + norm * (w * 0.45) + Offset(0, 8.0 * zoom), postPaint);
    }

    // 3. Tabuado de madeira principal
    final deckPaint = Paint()
      ..color = const Color(0xFF8D6E63).withValues(alpha: epochAlpha)
      ..strokeWidth = w
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(p1, p2, deckPaint);

    // 4. Pranchas transversais de madeira
    final plankPaint = Paint()
      ..color = const Color(0xFF5D4037).withValues(alpha: epochAlpha)
      ..strokeWidth = (1.5 * zoom).clamp(1.0, 3.0);
    final plankSteps = (len / (4.0 * zoom)).ceil().clamp(4, 50);
    for (int i = 0; i <= plankSteps; i++) {
      final t = i / plankSteps;
      final pt = p1 + dir * t;
      canvas.drawLine(pt - norm * (w * 0.5), pt + norm * (w * 0.5), plankPaint);
    }

    // 5. Guarda-corpo de madeira
    final railPaint = Paint()
      ..color = const Color(0xFF4E342E).withValues(alpha: epochAlpha)
      ..strokeWidth = (1.8 * zoom).clamp(1.0, 3.5);
    canvas.drawLine(p1 - norm * (w * 0.48), p2 - norm * (w * 0.48), railPaint);
    canvas.drawLine(p1 + norm * (w * 0.48), p2 + norm * (w * 0.48), railPaint);

    canvas.restore();
  }
}

/// Historical landmark participating in Y-Sorting.
class HistoricalLandmarkIsometricItem extends IsometricRenderItem {
  final HistoricalLandmark landmark;

  HistoricalLandmarkIsometricItem(this.landmark);

  @override
  double get baseWy => landmark.coordinate.wy;

  @override
  double get baseWx => landmark.coordinate.wx;

  @override
  void render({
    required Canvas canvas,
    required CameraState camera,
    required Size screenSize,
    required double animationTime,
    required double epochAlpha,
    required double epochScale,
  }) {
    final screenPt = landmark.coordinate.toScreen(
      cameraX: camera.x,
      cameraY: camera.y,
      zoom: camera.zoom,
      screenSize: screenSize,
    );

    final zoom = camera.zoom * epochScale;
    final r = (20.0 * zoom).clamp(12.0, 48.0);

    // Contact shadow
    final shadowPaint = Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.45 * epochAlpha);
    canvas.drawOval(
      Rect.fromCenter(center: screenPt + Offset(r * 0.20, r * 0.30), width: r * 1.8, height: r * 0.9),
      shadowPaint,
    );

    // Monólito de pedra gravado com petroglifos solares ancestrais
    final stonePaint = Paint()..color = const Color(0xFF64748B);
    final sunlitStone = Paint()..color = const Color(0xFF94A3B8);

    final rect = Rect.fromCenter(center: screenPt - Offset(0, r * 0.35), width: r * 0.9, height: r * 1.6);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(r * 0.25)), stonePaint);

    // Faceta iluminada
    final sunlitRect = Rect.fromLTWH(rect.left, rect.top, rect.width * 0.55, rect.height);
    canvas.drawRRect(RRect.fromRectAndRadius(sunlitRect, Radius.circular(r * 0.22)), sunlitStone);

    // Símbolo dourado gravado
    final glyphPaint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.85 * epochAlpha)
      ..strokeWidth = (2.0 * zoom).clamp(1.2, 3.5)
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(screenPt - Offset(0, r * 0.35), r * 0.25, glyphPaint);
  }
}

/// Master Unified Isometric Depth Sorter (Y-Sorting Engine).
class IsometricDepthSorter {
  IsometricDepthSorter._();
  static final IsometricDepthSorter instance = IsometricDepthSorter._();

  // Canonical historical epoch structures (Feitorias, Missions, Bridges)
  static final List<IsometricRenderItem> _canonicalEpochStructures = [
    // 1532: Feitoria de São Vicente / Enguaguassu
    FeitoriaTradingPostIsometricItem(
      coord: const WorldCoordinate(5320, 5520),
    ),
    // 1532: Entreposto de Pau-Brasil em Cabo Frio
    FeitoriaTradingPostIsometricItem(
      coord: const WorldCoordinate(7120, 4640),
    ),
    // 1554: Colégio e Forte de São Paulo de Piratininga
    ColonialMissionFortIsometricItem(
      coord: const WorldCoordinate(4920, 5060),
    ),
    // 1554: Ponte de Madeira Colonial sobre o Rio Tamanduateí
    ColonialWoodenBridgeIsometricItem(
      startCoord: const WorldCoordinate(5080, 4940),
      endCoord: const WorldCoordinate(5160, 4900),
      bridgeWidth: 26.0,
    ),
    // 1554: Ponte de Madeira Colonial sobre o Alto Tietê
    ColonialWoodenBridgeIsometricItem(
      startCoord: const WorldCoordinate(4720, 4970),
      endCoord: const WorldCoordinate(4780, 4930),
      bridgeWidth: 24.0,
    ),
  ];

  /// Computes squared distance from point (px, py) to line segment (x1, y1)-(x2, y2)
  static double _distanceSqToSegment(double px, double py, double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final lenSq = dx * dx + dy * dy;
    if (lenSq < 1e-6) {
      final dpx = px - x1;
      final dpy = py - y1;
      return dpx * dpx + dpy * dpy;
    }
    final t = (((px - x1) * dx + (py - y1) * dy) / lenSq).clamp(0.0, 1.0);
    final projX = x1 + t * dx;
    final projY = y1 + t * dy;
    final dpx = px - projX;
    final dpy = py - projY;
    return dpx * dpx + dpy * dpy;
  }

  /// Master render pass: collects, filters, sorts, and renders all isometric objects.
  void renderDepthSortedScene({
    required Canvas canvas,
    required CameraState camera,
    required Size screenSize,
    required List<VillageNode> villages,
    required List<HistoricalLandmark> landmarks,
    required HistoricalEpoch currentEpoch,
    required double epochTransitionProgress, // 0.0 (prev) to 1.0 (current)
    required HistoricalEpoch previousEpoch,
    List<RiverPath> rivers = const [],
    List<HistoricalTrail> trails = const [],
    double animationTime = 0.0,
  }) {
    final visibleBounds = camera.getVisibleBounds(screenSize);
    final renderQueue = <IsometricRenderItem>[];

    // ─── 1. Collect Visible Trees & Vegetation from VegetationEngine ────────
    // Clear Zones: Discard any tree within exclusion zones of:
    // - Indigenous villages (clearanceRadius = 180.0px or near any blueprint building < 75.0px)
    // - Historical trails & roads (corridor margin = 55.0px)
    // - Curriculum phase trail line between consecutive villages (corridor margin = 55.0px)
    // - River channels & alluvial banks (river half-width + 48.0px)
    const villageClearanceRadius = 180.0;
    const villageClearanceRadiusSq = villageClearanceRadius * villageClearanceRadius;
    const buildingClearanceSq = 75.0 * 75.0;
    const trailClearanceSq = 55.0 * 55.0;

    final queryBounds = WorldBounds(
      minX: visibleBounds.minX - 100,
      minY: visibleBounds.minY - 100,
      maxX: visibleBounds.maxX + 100,
      maxY: visibleBounds.maxY + 100,
    );
    final visibleTrees = VegetationEngine.instance.getTreesInBounds(queryBounds);

    for (final tree in visibleTrees) {
      bool insideExclusionZone = false;

      // Check A: Village clearance (center + maloca buildings)
      for (final village in villages) {
        final dx = tree.wx - village.coordinate.wx;
        final dy = tree.wy - village.coordinate.wy;
        if (dx.abs() > 220 || dy.abs() > 220) continue;

        if (dx * dx + dy * dy < villageClearanceRadiusSq) {
          insideExclusionZone = true;
          break;
        }

        final blueprint = AuthenticVillageComposer.instance.getBlueprint(village.id);
        for (final b in blueprint.buildings) {
          final bx = village.coordinate.wx + b.offset.dx;
          final by = village.coordinate.wy + b.offset.dy;
          final bdx = tree.wx - bx;
          final bdy = tree.wy - by;
          if (bdx * bdx + bdy * bdy < buildingClearanceSq) {
            insideExclusionZone = true;
            break;
          }
        }
        if (insideExclusionZone) break;
      }
      if (insideExclusionZone) continue;

      // Check B: Historical trails (corridor 55px)
      for (final trail in trails) {
        if (tree.wx < trail.bounds.minX - 55.0 ||
            tree.wx > trail.bounds.maxX + 55.0 ||
            tree.wy < trail.bounds.minY - 55.0 ||
            tree.wy > trail.bounds.maxY + 55.0) {
          continue;
        }
        for (int i = 0; i < trail.points.length - 1; i++) {
          final p1 = trail.points[i];
          final p2 = trail.points[i + 1];
          if (_distanceSqToSegment(tree.wx, tree.wy, p1.wx, p1.wy, p2.wx, p2.wy) < trailClearanceSq) {
            insideExclusionZone = true;
            break;
          }
        }
        if (insideExclusionZone) break;
      }
      if (insideExclusionZone) continue;

      // Check C: Curriculum phase road connecting sequential villages (corridor 55px)
      if (villages.length >= 2) {
        for (int i = 0; i < villages.length - 1; i++) {
          final v1 = villages[i];
          final v2 = villages[i + 1];
          final minX = math.min(v1.coordinate.wx, v2.coordinate.wx) - 60.0;
          final maxX = math.max(v1.coordinate.wx, v2.coordinate.wx) + 60.0;
          final minY = math.min(v1.coordinate.wy, v2.coordinate.wy) - 60.0;
          final maxY = math.max(v1.coordinate.wy, v2.coordinate.wy) + 60.0;
          if (tree.wx < minX || tree.wx > maxX || tree.wy < minY || tree.wy > maxY) continue;

          // Quadratic bezier mid control point
          final midWx = (v1.coordinate.wx + v2.coordinate.wx) * 0.5 + (v2.coordinate.wy - v1.coordinate.wy) * 0.12;
          final midWy = (v1.coordinate.wy + v2.coordinate.wy) * 0.5 - (v2.coordinate.wx - v1.coordinate.wx) * 0.12;

          final p0 = v1.coordinate;
          final q1x = 0.25 * p0.wx + 0.5 * midWx + 0.25 * v2.coordinate.wx;
          final q1y = 0.25 * p0.wy + 0.5 * midWy + 0.25 * v2.coordinate.wy;
          final p2 = v2.coordinate;

          if (_distanceSqToSegment(tree.wx, tree.wy, p0.wx, p0.wy, q1x, q1y) < trailClearanceSq ||
              _distanceSqToSegment(tree.wx, tree.wy, q1x, q1y, p2.wx, p2.wy) < trailClearanceSq) {
            insideExclusionZone = true;
            break;
          }
        }
      }
      if (insideExclusionZone) continue;

      // Check D: River channels and alluvial banks (river half-width + 48px)
      for (final river in rivers) {
        if (tree.wx < river.bounds.minX - 80.0 ||
            tree.wx > river.bounds.maxX + 80.0 ||
            tree.wy < river.bounds.minY - 80.0 ||
            tree.wy > river.bounds.maxY + 80.0) {
          continue;
        }
        for (final seg in river.segments) {
          final avgW = (seg.startWidth + seg.endWidth) * 0.5;
          final clearDist = avgW * 0.5 + 48.0;
          final clearDistSq = clearDist * clearDist;

          final p0 = seg.start;
          final p1 = seg.evaluate(0.33);
          final p2 = seg.evaluate(0.67);
          final p3 = seg.end;

          if (_distanceSqToSegment(tree.wx, tree.wy, p0.wx, p0.wy, p1.wx, p1.wy) < clearDistSq ||
              _distanceSqToSegment(tree.wx, tree.wy, p1.wx, p1.wy, p2.wx, p2.wy) < clearDistSq ||
              _distanceSqToSegment(tree.wx, tree.wy, p2.wx, p2.wy, p3.wx, p3.wy) < clearDistSq) {
            insideExclusionZone = true;
            break;
          }
        }
        if (insideExclusionZone) break;
      }
      if (insideExclusionZone) continue;

      renderQueue.add(TreeIsometricItem(tree));
    }

    // ─── 2. Collect Indigenous Villages & Tabas (Always exist across epochs) ──
    for (final village in villages) {
      if (village.coordinate.x < visibleBounds.minX - 350 ||
          village.coordinate.x > visibleBounds.maxX + 350 ||
          village.coordinate.y < visibleBounds.minY - 350 ||
          village.coordinate.y > visibleBounds.maxY + 350) {
        continue;
      }

      if (!village.isUnlocked && !village.isFrontier) continue;

      // Longhouses (Ocas)
      final blueprint = AuthenticVillageComposer.instance.getBlueprint(village.id);
      for (final b in blueprint.buildings) {
        renderQueue.add(
          OcaBuildingIsometricItem(
            villageCoord: village.coordinate,
            localOffset: b.offset,
            width: b.width,
            height: b.height,
            rotation: b.rotation,
            isMain: b.isMain,
            isMastered: village.isMastered,
            villageStatus: village.status,
          ),
        );
      }

      // Central Campfire (Tataendy)
      renderQueue.add(
        VillageHearthIsometricItem(
          villageCoord: village.coordinate,
          localOffset: blueprint.campfireOffset,
          seed: village.coordinate.x.toInt(),
        ),
      );
    }

    // ─── 3. Collect Historical Landmarks ────────────────────────────────────
    for (final lm in landmarks) {
      if (visibleBounds.contains(lm.coordinate)) {
        renderQueue.add(HistoricalLandmarkIsometricItem(lm));
      }
    }

    // ─── 4. Collect Epoch-Specific Structures (Bridges, Feitorias, Forts) ────
    for (final struct in _canonicalEpochStructures) {
      if (struct.baseWx >= visibleBounds.minX - 120 &&
          struct.baseWx <= visibleBounds.maxX + 120 &&
          struct.baseWy >= visibleBounds.minY - 120 &&
          struct.baseWy <= visibleBounds.maxY + 120) {
        renderQueue.add(struct);
      }
    }

    // ─── 5. STAGE 2: STRICT Y-SORTING (Depth Sorting) ──────────────────────
    // The core of classic Age of Empires / Project Zomboid rendering:
    // Objects with smaller Y (North) are rendered BEFORE objects with larger Y (South)!
    renderQueue.sort((a, b) => a.baseWy.compareTo(b.baseWy));

    // ─── 6. STAGE 3: DRAW IN SORTED ORDER WITH EPOCH TRANSITIONS ────────────
    for (final item in renderQueue) {
      final (alpha, scale) = _computeItemEpochFactor(
        item: item,
        currentEpoch: currentEpoch,
        previousEpoch: previousEpoch,
        progress: epochTransitionProgress,
      );

      if (alpha <= 0.005) continue;

      item.render(
        canvas: canvas,
        camera: camera,
        screenSize: screenSize,
        animationTime: animationTime,
        epochAlpha: alpha,
        epochScale: scale,
      );
    }
  }

  /// Calculates opacity fade and scale animation for epoch transitions.
  (double, double) _computeItemEpochFactor({
    required IsometricRenderItem item,
    required HistoricalEpoch currentEpoch,
    required HistoricalEpoch previousEpoch,
    required double progress,
  }) {
    // Trees, ocas, bonfires, and landmarks are present across active epochs
    if (item is TreeIsometricItem ||
        item is OcaBuildingIsometricItem ||
        item is VillageHearthIsometricItem ||
        item is HistoricalLandmarkIsometricItem) {
      return (1.0, 1.0);
    }

    // 1532 Feitoria: Appears in 1532, persists in 1554+
    if (item is FeitoriaTradingPostIsometricItem) {
      final activeInCurrent = currentEpoch != HistoricalEpoch.pre1500;
      final activeInPrev = previousEpoch != HistoricalEpoch.pre1500;

      if (activeInCurrent && activeInPrev) return (1.0, 1.0);
      if (activeInCurrent && !activeInPrev) {
        final a = Curves.easeOutCubic.transform(progress);
        return (a, 0.85 + 0.15 * a);
      }
      if (!activeInCurrent && activeInPrev) {
        final a = 1.0 - Curves.easeInCubic.transform(progress);
        return (a, 0.85 + 0.15 * a);
      }
      return (0.0, 0.85);
    }

    // 1554 Colonial Mission & Wooden Bridges: Appear in 1554+
    if (item is ColonialMissionFortIsometricItem || item is ColonialWoodenBridgeIsometricItem) {
      final activeInCurrent = (currentEpoch == HistoricalEpoch.epoch1554 ||
          currentEpoch == HistoricalEpoch.epoch1555 ||
          currentEpoch == HistoricalEpoch.epoch1567 ||
          currentEpoch == HistoricalEpoch.atual);
      final activeInPrev = (previousEpoch == HistoricalEpoch.epoch1554 ||
          previousEpoch == HistoricalEpoch.epoch1555 ||
          previousEpoch == HistoricalEpoch.epoch1567 ||
          previousEpoch == HistoricalEpoch.atual);

      if (activeInCurrent && activeInPrev) return (1.0, 1.0);
      if (activeInCurrent && !activeInPrev) {
        final a = Curves.easeOutCubic.transform(progress);
        return (a, 0.85 + 0.15 * a);
      }
      if (!activeInCurrent && activeInPrev) {
        final a = 1.0 - Curves.easeInCubic.transform(progress);
        return (a, 0.85 + 0.15 * a);
      }
      return (0.0, 0.85);
    }

    return (1.0, 1.0);
  }
}
