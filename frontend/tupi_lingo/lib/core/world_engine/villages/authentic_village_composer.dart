import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../camera/camera_state.dart';
import '../villages/village_node.dart';

/// Individual structure instance within an authentic indigenous village.
class VillageBuilding {
  final Offset offset;
  final double width;
  final double height;
  final double rotation; // In radians
  final bool isMain;

  const VillageBuilding({
    required this.offset,
    required this.width,
    required this.height,
    this.rotation = 0.0,
    this.isMain = false,
  });
}

/// Organic layout blueprint for an authentic indigenous settlement (Taba / Aldeamento).
class VillageLayoutBlueprint {
  final List<VillageBuilding> buildings;
  final Offset campfireOffset;
  final List<Offset> footpaths;
  final List<Offset> gardenPlots;
  final List<Offset> dryingRacks;
  final bool hasWaterDocks;
  final Offset? canoeDockOffset;
  final List<Offset>? defensiveWallSegment;

  const VillageLayoutBlueprint({
    required this.buildings,
    required this.campfireOffset,
    required this.footpaths,
    required this.gardenPlots,
    this.dryingRacks = const [],
    this.hasWaterDocks = false,
    this.canoeDockOffset,
    this.defensiveWallSegment,
  });
}

/// Composer that physically renders an authentic indigenous settlement into the 3D world scene.
///
/// Strictly replaces circular markers and isolated icons with living, organic,
/// architecturally grounded 2.5D villages (longhouses, courtyards, cassava fields, hearths, canoes).
class AuthenticVillageComposer {
  AuthenticVillageComposer._();
  static final AuthenticVillageComposer instance = AuthenticVillageComposer._();

  VillageLayoutBlueprint getBlueprint(String villageId) {
    final normalized = villageId.toLowerCase().trim();
    if (_blueprints.containsKey(normalized)) {
      return _blueprints[normalized]!;
    }
    for (final entry in _blueprintAliases.entries) {
      if (normalized.contains(entry.key)) {
        final target = entry.value;
        if (_blueprints.containsKey(target)) {
          return _blueprints[target]!;
        }
      }
    }
    return _blueprints['paranapiacaba'] ?? _blueprints['piratininga']!;
  }

  static const Map<String, String> _blueprintAliases = {
    'paranapiacaba': 'paranapiacaba',
    'serra_do_mar': 'paranapiacaba',
    'reg_03': 'paranapiacaba',
    'vila_03': 'paranapiacaba',
    'guaibe': 'sao_vicente',
    'sao_vicente': 'sao_vicente',
    'enguaguassu': 'sao_vicente',
    'reg_04': 'sao_vicente',
    'vila_04': 'sao_vicente',
    'iperoig': 'ubatuba',
    'ubatuba': 'ubatuba',
    'reg_01': 'ubatuba',
    'vila_01': 'ubatuba',
    'urucumirim': 'guanabara',
    'guanabara': 'guanabara',
    'karioka': 'guanabara',
    'reg_02': 'guanabara',
    'vila_02': 'guanabara',
    'piratininga': 'piratininga',
    'tietepo': 'piratininga',
    'reg_05': 'piratininga',
    'vila_05': 'piratininga',
    'cabo_frio': 'cabo_frio',
    'mapeg': 'cabo_frio',
  };

  // Canonical layouts customized per historical settlement geography
  static const Map<String, VillageLayoutBlueprint> _blueprints = {
    // 1. Piratininga - Highland Plateau Chiefdom (Tibiriçá)
    // Clustered on a rolling hill between Tamanduateí and Tietê rivers.
    'piratininga': VillageLayoutBlueprint(
      buildings: [
        // Maloca Principal (Council longhouse of Tibiriçá) - angled naturally
        VillageBuilding(offset: Offset(-8, -42), width: 84, height: 48, rotation: -0.08, isMain: true),
        // Secondary longhouses forming an open horseshoe around the Okara
        VillageBuilding(offset: Offset(-65, -12), width: 56, height: 34, rotation: 0.22),
        VillageBuilding(offset: Offset(62, -18), width: 54, height: 32, rotation: -0.28),
        VillageBuilding(offset: Offset(-48, 36), width: 48, height: 30, rotation: -0.15),
        VillageBuilding(offset: Offset(52, 32), width: 50, height: 30, rotation: 0.18),
      ],
      campfireOffset: Offset(2, 6),
      footpaths: [
        Offset(0, 75),   // Main path southward connecting to Peabiru trail
        Offset(-40, 16), // Path branching west to family malocas
        Offset(42, 12),  // Path branching east
        Offset(-10, -22),// Path approaching council longhouse
      ],
      gardenPlots: [
        Offset(-95, 24), // Roça de mandioca na encosta oeste
        Offset(92, 18),  // Roça na encosta leste
        Offset(-78, -55),// Roça de milho e urucum ao norte
      ],
      dryingRacks: [
        Offset(-22, 28),
        Offset(26, -10),
      ],
      hasWaterDocks: true,
      canoeDockOffset: Offset(-115, -65), // Rio Tamanduateí
    ),

    // 2. São Vicente / Enguaguassu - Coastal Mangrove & Restinga Village (Piquerobi)
    'sao_vicente': VillageLayoutBlueprint(
      buildings: [
        VillageBuilding(offset: Offset(-14, -32), width: 68, height: 42, rotation: -0.12, isMain: true),
        VillageBuilding(offset: Offset(48, -14), width: 48, height: 30, rotation: 0.35),
        VillageBuilding(offset: Offset(-52, 22), width: 44, height: 28, rotation: -0.22),
      ],
      campfireOffset: Offset(4, 4),
      footpaths: [
        Offset(25, 62),
        Offset(-30, 8),
        Offset(22, -6),
      ],
      gardenPlots: [
        Offset(-72, -38),
      ],
      dryingRacks: [
        Offset(24, 28), // Fish smoking rack near beach
      ],
      hasWaterDocks: true,
      canoeDockOffset: Offset(85, 48), // Canal de Santos / Mar
    ),

    // 3. Ubatuba / Iperoig - Coastal Fortress of the Tamoios (Cunhambebe)
    'ubatuba': VillageLayoutBlueprint(
      buildings: [
        VillageBuilding(offset: Offset(0, -38), width: 88, height: 50, rotation: 0.05, isMain: true),
        VillageBuilding(offset: Offset(-68, -14), width: 52, height: 32, rotation: 0.28),
        VillageBuilding(offset: Offset(68, -14), width: 52, height: 32, rotation: -0.28),
        VillageBuilding(offset: Offset(-52, 34), width: 46, height: 28, rotation: -0.14),
        VillageBuilding(offset: Offset(52, 34), width: 46, height: 28, rotation: 0.14),
      ],
      campfireOffset: Offset(0, 10),
      footpaths: [
        Offset(0, 78),
        Offset(-42, 14),
        Offset(42, 14),
      ],
      gardenPlots: [
        Offset(-105, 8),
        Offset(105, 8),
      ],
      dryingRacks: [
        Offset(-20, -10),
        Offset(22, 24),
      ],
      hasWaterDocks: true,
      canoeDockOffset: Offset(95, -45), // Baía de Ubatuba
      defensiveWallSegment: [
        // Straight protective palisade barrier along trail entrance, NOT an encircling ring
        Offset(-95, 65),
        Offset(-45, 68),
        Offset(45, 68),
        Offset(95, 65),
      ],
    ),

    // 4. Guanabara / Karióka - Fortified Bay Stronghold (Aimberê)
    'guanabara': VillageLayoutBlueprint(
      buildings: [
        VillageBuilding(offset: Offset(-10, -42), width: 86, height: 48, rotation: -0.05, isMain: true),
        VillageBuilding(offset: Offset(-64, -8), width: 50, height: 32, rotation: 0.20),
        VillageBuilding(offset: Offset(62, -12), width: 50, height: 32, rotation: -0.25),
        VillageBuilding(offset: Offset(-50, 36), width: 46, height: 28, rotation: -0.10),
        VillageBuilding(offset: Offset(54, 32), width: 46, height: 28, rotation: 0.15),
      ],
      campfireOffset: Offset(0, 8),
      footpaths: [
        Offset(0, 72),
        Offset(-34, 16),
        Offset(34, 12),
      ],
      gardenPlots: [
        Offset(-90, -30),
        Offset(95, 25),
      ],
      dryingRacks: [
        Offset(-25, 20),
      ],
      hasWaterDocks: true,
      canoeDockOffset: Offset(-95, 58),
      defensiveWallSegment: [
        Offset(-80, 58),
        Offset(-30, 62),
        Offset(30, 62),
        Offset(80, 58),
      ],
    ),

    // 5. Cabo Frio / Mapeg - Sand Dune & Pau-Brasil Outpost
    'cabo_frio': VillageLayoutBlueprint(
      buildings: [
        VillageBuilding(offset: Offset(0, -28), width: 62, height: 38, rotation: 0.08, isMain: true),
        VillageBuilding(offset: Offset(-48, 12), width: 42, height: 26, rotation: -0.24),
        VillageBuilding(offset: Offset(46, 14), width: 42, height: 26, rotation: 0.22),
      ],
      campfireOffset: Offset(0, 10),
      footpaths: [
        Offset(0, 56),
        Offset(-24, 8),
        Offset(24, 8),
      ],
      gardenPlots: [
        Offset(-72, -18),
      ],
      dryingRacks: [
        Offset(20, -12),
      ],
      hasWaterDocks: true,
      canoeDockOffset: Offset(75, 42),
    ),

    // 6. Paranapiacaba - Serra do Mar Mist Sanctuary ('De onde se avista o mar')
    'paranapiacaba': VillageLayoutBlueprint(
      buildings: [
        VillageBuilding(offset: Offset(-6, -40), width: 80, height: 46, rotation: -0.06, isMain: true),
        VillageBuilding(offset: Offset(-62, -10), width: 54, height: 32, rotation: 0.20),
        VillageBuilding(offset: Offset(58, -14), width: 52, height: 32, rotation: -0.25),
        VillageBuilding(offset: Offset(-45, 34), width: 46, height: 28, rotation: -0.12),
        VillageBuilding(offset: Offset(48, 30), width: 48, height: 28, rotation: 0.16),
      ],
      campfireOffset: Offset(0, 4),
      footpaths: [
        Offset(0, 68),   // Escadaria da serra rumo ao Peabiru
        Offset(-36, 12), // Trilha para o mirante oeste
        Offset(38, 10),  // Trilha para as roças da encosta
        Offset(-8, -20), // Acesso à maloca principal
      ],
      gardenPlots: [
        Offset(-88, 20), // Roça de mandioca na vertente da serra
        Offset(86, 16),  // Roça de urucum e palmito
        Offset(-70, -48),// Clareira de ervas medicinais da mata
      ],
      dryingRacks: [
        Offset(-20, 24),
        Offset(24, -8),
      ],
      hasWaterDocks: false,
    ),
  };

  /// Renders flat ground decals for a settlement (dirt footprint, garden plots, footpaths).
  void renderVillageGroundDecals({
    required Canvas canvas,
    required Size size,
    required CameraState camera,
    required VillageNode village,
  }) {
    final screenPt = village.coordinate.toScreen(
      cameraX: camera.x,
      cameraY: camera.y,
      zoom: camera.zoom,
      screenSize: size,
    );
    final zoom = camera.zoom;
    final blueprint = getBlueprint(village.id);

    _paintOrganicEarthenFloor(canvas, screenPt, zoom, village.stage);
    _paintOrganicFootpaths(canvas, screenPt, blueprint, zoom);
    _paintGardenPlots(canvas, screenPt, blueprint, zoom);
    _paintVillageProps(canvas, screenPt, blueprint, zoom);

    if (blueprint.hasWaterDocks && blueprint.canoeDockOffset != null) {
      _paintCanoeDock(canvas, screenPt, blueprint.canoeDockOffset!, zoom);
    }
    if (blueprint.defensiveWallSegment != null) {
      _paintLinearPalisadeBarrier(canvas, screenPt, blueprint.defensiveWallSegment!, zoom);
    }
  }

  /// Renders the discreet zoom label for the settlement above the 3D scene.
  void renderVillageLabel({
    required Canvas canvas,
    required Size size,
    required CameraState camera,
    required VillageNode village,
    required bool isSelected,
  }) {
    final screenPt = village.coordinate.toScreen(
      cameraX: camera.x,
      cameraY: camera.y,
      zoom: camera.zoom,
      screenSize: size,
    );
    final isMastered = village.stage == VillageEvolutionStage.historica || village.isMastered;
    _paintDiscreetZoomLabel(
      canvas: canvas,
      screenPt: screenPt,
      village: village,
      zoom: camera.zoom,
      isMastered: isMastered,
      isSelected: isSelected,
    );
  }

  /// Main entry point to render an authentic village settlement into the world.
  void renderVillageSettlement({
    required Canvas canvas,
    required Size size,
    required CameraState camera,
    required VillageNode village,
    required double animationTime,
    required bool isSelected,
  }) {
    final screenPt = village.coordinate.toScreen(
      cameraX: camera.x,
      cameraY: camera.y,
      zoom: camera.zoom,
      screenSize: size,
    );

    final zoom = camera.zoom;
    final isMastered = village.stage == VillageEvolutionStage.historica || village.isMastered;
    final blueprint = _blueprints[village.id] ?? _blueprints['piratininga']!;

    // 1. Organic Earthen Ground Footprint (Terreiro / Okara) - irregular shape, not circular!
    _paintOrganicEarthenFloor(canvas, screenPt, zoom, village.stage);

    // 2. Packed Dirt Footpaths between structures
    _paintOrganicFootpaths(canvas, screenPt, blueprint, zoom);

    // 3. Garden Plots (Roças de Mandioca / Milho nos Arredores)
    _paintGardenPlots(canvas, screenPt, blueprint, zoom);

    // 4. Fish Drying Racks (Moquéns) and Pottery (Igaçabas)
    _paintVillageProps(canvas, screenPt, blueprint, zoom);

    // 5. Water Docks & Dugout Canoes (Ubás) if Near River/Coast
    if (blueprint.hasWaterDocks && blueprint.canoeDockOffset != null) {
      _paintCanoeDock(canvas, screenPt, blueprint.canoeDockOffset!, zoom);
    }

    // 6. Defensive Stockade Barrier (if settlement has defensive barriers, e.g. Ubatuba)
    if (blueprint.defensiveWallSegment != null) {
      _paintLinearPalisadeBarrier(canvas, screenPt, blueprint.defensiveWallSegment!, zoom);
    }

    // 7. Longhouses (Malocas) rendered with 2.5D Oblique Depth & Shadows
    for (final b in blueprint.buildings) {
      final bCenter = screenPt + (b.offset * zoom);
      _paint3DMaloca(
        canvas: canvas,
        center: bCenter,
        width: b.width * zoom,
        height: b.height * zoom,
        rotation: b.rotation,
        isMain: b.isMain,
        zoom: zoom,
        isMastered: isMastered,
      );
    }

    // 8. Sacred Central Campfire (Tataendy) & Hearth
    final fireCenter = screenPt + (blueprint.campfireOffset * zoom);
    _paintCeremonialHearth(
      canvas: canvas,
      center: fireCenter,
      zoom: zoom,
      animationTime: animationTime,
      seed: village.coordinate.x,
    );

    // 9. Zoom-dependent subtle label (Never dominating the 3D scene)
    _paintDiscreetZoomLabel(
      canvas: canvas,
      screenPt: screenPt,
      village: village,
      zoom: zoom,
      isMastered: isMastered,
      isSelected: isSelected,
    );
  }

  /// Paints an organic, irregular ground patch where vegetation has naturally receded.
  void _paintOrganicEarthenFloor(
    Canvas canvas,
    Offset center,
    double zoom,
    VillageEvolutionStage stage,
  ) {
    final scale = (zoom * 1.15).clamp(0.65, 2.5);

    // Multi-blob organic clearing (drawn from overlapping soft splats, never a circle!)
    final groundPaint = Paint()..style = PaintingStyle.fill;
    final stonePaint = Paint()..style = PaintingStyle.fill;

    final blobs = [
      {'dx': 0.0, 'dy': -8.0, 'rx': 95.0 * scale, 'ry': 70.0 * scale},
      {'dx': -28.0, 'dy': 18.0, 'rx': 75.0 * scale, 'ry': 60.0 * scale},
      {'dx': 32.0, 'dy': 12.0, 'rx': 80.0 * scale, 'ry': 65.0 * scale},
      {'dx': 0.0, 'dy': 42.0, 'rx': 55.0 * scale, 'ry': 48.0 * scale},
    ];

    // 1. Soft outer transition into the surrounding meadow
    groundPaint.color = const Color(0xFF4A341E).withValues(alpha: 0.40);
    for (final b in blobs) {
      final bCenter = center + Offset(b['dx']!, b['dy']!);
      canvas.drawOval(
        Rect.fromCenter(center: bCenter, width: b['rx']! * 1.35, height: b['ry']! * 1.35),
        groundPaint,
      );
    }

    // 2. Rich compacted red clay / terra batida core
    groundPaint.color = const Color(0xFF6E4324).withValues(alpha: 0.85);
    for (final b in blobs) {
      final bCenter = center + Offset(b['dx']!, b['dy']!);
      canvas.drawOval(
        Rect.fromCenter(center: bCenter, width: b['rx']!, height: b['ry']!),
        groundPaint,
      );
    }

    // 3. Central trampled courtyard (Okara)
    groundPaint.color = const Color(0xFF8B5731).withValues(alpha: 0.90);
    canvas.drawOval(
      Rect.fromCenter(center: center + Offset(0, 8 * scale), width: 75 * scale, height: 50 * scale),
      groundPaint,
    );

    // 4. Seixos e pedriscos espalhados na borda da clareira
    if (zoom >= 0.75) {
      stonePaint.color = const Color(0xFF78716C).withValues(alpha: 0.65);
      const stoneOffsets = [
        Offset(-55, 30),
        Offset(60, -25),
        Offset(-40, -45),
        Offset(45, 40),
        Offset(-15, 55),
      ];
      for (final off in stoneOffsets) {
        canvas.drawOval(
          Rect.fromCenter(center: center + off * scale, width: 3.5 * zoom, height: 2.2 * zoom),
          stonePaint,
        );
      }
    }
  }

  void _paintOrganicFootpaths(
    Canvas canvas,
    Offset center,
    VillageLayoutBlueprint blueprint,
    double zoom,
  ) {
    final pathPaint = Paint()
      ..color = const Color(0xFF9E6533).withValues(alpha: 0.75)
      ..strokeWidth = (7.0 * zoom).clamp(3.0, 16.0)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (final wp in blueprint.footpaths) {
      path.moveTo(center.dx, center.dy);
      // Soft curve out from village center to waypoint
      final target = center + wp * zoom;
      final mid = Offset((center.dx + target.dx) / 2 + (wp.dy * 0.15 * zoom), (center.dy + target.dy) / 2);
      path.quadraticBezierTo(mid.dx, mid.dy, target.dx, target.dy);
    }
    canvas.drawPath(path, pathPaint);
  }

  void _paintGardenPlots(
    Canvas canvas,
    Offset center,
    VillageLayoutBlueprint blueprint,
    double zoom,
  ) {
    if (zoom < 0.65) return;

    final plotPaint = Paint()..style = PaintingStyle.fill;
    final leafPaint = Paint()..style = PaintingStyle.fill;

    for (final plot in blueprint.gardenPlots) {
      final pCenter = center + plot * zoom;
      final pw = (32.0 * zoom).clamp(14.0, 50.0);
      final ph = (20.0 * zoom).clamp(10.0, 32.0);

      // Earthen furrows
      plotPaint.color = const Color(0xFF553215).withValues(alpha: 0.75);
      canvas.drawOval(Rect.fromCenter(center: pCenter, width: pw, height: ph), plotPaint);

      // Crop mounds (mandiocais)
      leafPaint.color = const Color(0xFF3E6B2A);
      canvas.drawCircle(pCenter - Offset(pw * 0.22, 0), pw * 0.26, leafPaint);
      leafPaint.color = const Color(0xFF5A8E3F);
      canvas.drawCircle(pCenter + Offset(pw * 0.20, 0), pw * 0.24, leafPaint);
    }
  }

  void _paintVillageProps(
    Canvas canvas,
    Offset center,
    VillageLayoutBlueprint blueprint,
    double zoom,
  ) {
    if (zoom < 0.85) return;

    final woodPaint = Paint()
      ..color = const Color(0xFF4A3423)
      ..strokeWidth = (1.8 * zoom).clamp(1.2, 3.5)
      ..strokeCap = StrokeCap.round;

    final clayPaint = Paint()..style = PaintingStyle.fill;

    // Drying racks (Moquém)
    for (final rack in blueprint.dryingRacks) {
      final rPos = center + rack * zoom;
      final rw = 12.0 * zoom;
      final rh = 8.0 * zoom;

      // Contact shadow under drying rack
      final rackShadow = Paint()
        ..color = const Color(0xFF140D07).withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(center: rPos + Offset(rw * 0.15, rh + 1.0), width: rw * 1.1, height: 3.5 * zoom),
        rackShadow,
      );

      // Legs
      canvas.drawLine(rPos - Offset(rw * 0.4, 0), rPos - Offset(rw * 0.4, rh), woodPaint);
      canvas.drawLine(rPos + Offset(rw * 0.4, 0), rPos + Offset(rw * 0.4, rh), woodPaint);
      // Grid
      canvas.drawLine(rPos - Offset(rw * 0.5, rh), rPos + Offset(rw * 0.5, rh), woodPaint);

      // Ceramic pots (Igaçabas) with contact shadow
      final potPos = rPos + Offset(rw * 0.6, 2.0);
      canvas.drawOval(
        Rect.fromCenter(center: potPos + Offset(1.0, 1.5), width: 3.2 * zoom, height: 1.6 * zoom),
        rackShadow,
      );
      clayPaint.color = const Color(0xFFB55D30);
      canvas.drawCircle(potPos, 2.8 * zoom, clayPaint);
    }
  }

  void _paintLinearPalisadeBarrier(
    Canvas canvas,
    Offset center,
    List<Offset> wallPoints,
    double zoom,
  ) {
    if (wallPoints.length < 2) return;

    final stakePaint = Paint()..style = PaintingStyle.fill;
    final shadowPaint = Paint()..style = PaintingStyle.fill;
    shadowPaint.color = const Color(0xFF140D07).withValues(alpha: 0.35);

    final stakeR = (2.2 * zoom).clamp(1.2, 4.0);

    for (int i = 0; i < wallPoints.length - 1; i++) {
      final p1 = center + wallPoints[i] * zoom;
      final p2 = center + wallPoints[i + 1] * zoom;
      final dist = (p2 - p1).distance;
      final steps = (dist / (stakeR * 2.2)).ceil().clamp(3, 30);

      for (int s = 0; s <= steps; s++) {
        final t = s / steps;
        final sx = p1.dx + (p2.dx - p1.dx) * t;
        final sy = p1.dy + (p2.dy - p1.dy) * t;

        // Shadow to Southeast
        canvas.drawCircle(Offset(sx + stakeR * 0.7, sy + stakeR * 0.6), stakeR, shadowPaint);

        // Wooden stake
        stakePaint.color = s % 2 == 0 ? const Color(0xFF6D4C41) : const Color(0xFF5D4037);
        canvas.drawCircle(Offset(sx, sy), stakeR, stakePaint);
      }
    }
  }

  void _paintCanoeDock(
    Canvas canvas,
    Offset center,
    Offset dockOffset,
    double zoom,
  ) {
    final dockPos = center + dockOffset * zoom;
    final canoeLength = (34.0 * zoom).clamp(15.0, 56.0);
    final canoeWidth = (7.5 * zoom).clamp(3.8, 13.0);

    // Canoe shadow in water
    final shadowPaint = Paint()
      ..color = const Color(0xFF09141B).withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: dockPos + Offset(2.0, 3.0), width: canoeLength, height: canoeWidth),
      shadowPaint,
    );

    // Carved wood canoe hull (Ubá)
    final hullPaint = Paint()
      ..color = const Color(0xFF754C34)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: dockPos, width: canoeLength, height: canoeWidth),
      hullPaint,
    );

    // Hollow interior
    final innerPaint = Paint()
      ..color = const Color(0xFF381F12)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: dockPos, width: canoeLength * 0.82, height: canoeWidth * 0.52),
      innerPaint,
    );
  }

  /// Renders a single authentic Tupi Maloca (longhouse) in 2.5D oblique perspective.
  void _paint3DMaloca({
    required Canvas canvas,
    required Offset center,
    required double width,
    required double height,
    required double rotation,
    required bool isMain,
    required double zoom,
    required bool isMastered,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    // 0. Ground Contact Ambient Occlusion Rim (prevents floating appearance)
    final aoPaint = Paint()
      ..color = const Color(0xFF0C0603).withValues(alpha: 0.62)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, height * 0.20),
          width: width * 1.05,
          height: height * 0.45,
        ),
        Radius.circular(height * 0.22),
      ),
      aoPaint,
    );

    // 1. Projected Ground Shadow (extends down & right to Southeast)
    final shadowPaint = Paint()
      ..color = const Color(0xFF140B06).withValues(alpha: 0.42)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(width * 0.18, height * 0.32),
          width: width * 1.15,
          height: height * 0.65,
        ),
        Radius.circular(height * 0.30),
      ),
      shadowPaint,
    );

    // 2. Packed Earthen Foundation Rim (reboco de barro batido na base da maloca)
    final foundationPaint = Paint()
      ..color = const Color(0xFF634125).withValues(alpha: 0.88)
      ..style = PaintingStyle.fill;
    final foundationRect = Rect.fromCenter(center: Offset(0, height * 0.18), width: width * 0.96, height: height * 0.40);
    canvas.drawRRect(RRect.fromRectAndRadius(foundationRect, Radius.circular(height * 0.20)), foundationPaint);

    // 3. Base Wooden Wall Frame (low side walls)
    final wallPaint = Paint()
      ..color = const Color(0xFF4E3629)
      ..style = PaintingStyle.fill;
    final wallRect = Rect.fromCenter(center: Offset(0, height * 0.15), width: width * 0.92, height: height * 0.45);
    canvas.drawRRect(RRect.fromRectAndRadius(wallRect, Radius.circular(height * 0.22)), wallPaint);

    // 3. Arched Thatch Roof (Sapê / Pindoba with 3D slope and lighting)
    final roofRect = Rect.fromCenter(center: Offset(0, -height * 0.08), width: width, height: height * 0.82);
    final roofRRect = RRect.fromRectAndRadius(roofRect, Radius.circular(height * 0.40));

    // Sunlit gradient from Northwest (sunlit straw) to Southeast (shaded brown)
    final roofGradient = ui.Gradient.linear(
      roofRect.topLeft,
      roofRect.bottomRight,
      [
        const Color(0xFFF0CA7D), // Topo dourado iluminado pelo sol
        const Color(0xFFCF9845), // Palha seca trançada
        const Color(0xFF8A551E), // Base sombreada
      ],
      [0.0, 0.52, 1.0],
    );

    final roofPaint = Paint()
      ..shader = roofGradient
      ..style = PaintingStyle.fill;
    canvas.drawRRect(roofRRect, roofPaint);

    // 4. Roof Ridge Lines (Woven thatch ribs)
    final ribPaint = Paint()
      ..color = const Color(0xFF6B4015).withValues(alpha: 0.45)
      ..strokeWidth = (1.5 * zoom).clamp(1.0, 3.0)
      ..style = PaintingStyle.stroke;

    final ribRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, -height * 0.14), width: width * 0.84, height: height * 0.45),
      Radius.circular(height * 0.28),
    );
    canvas.drawRRect(ribRRect, ribPaint);

    // 5. Central Ridgepole (Cumeeira de madeira ao longo do topo)
    final ridgepolePaint = Paint()
      ..color = const Color(0xFF5A3512)
      ..strokeWidth = (2.2 * zoom).clamp(1.4, 4.2)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-width * 0.38, -height * 0.18),
      Offset(width * 0.38, -height * 0.18),
      ridgepolePaint,
    );

    // 6. Low Arch Wooden Doorway (Porta baixa tupi)
    final doorW = width * 0.18;
    final doorH = height * 0.34;
    final doorCenter = Offset(0, height * 0.22);
    final doorRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: doorCenter, width: doorW, height: doorH),
      Radius.circular(doorW * 0.45),
    );

    final doorPaint = Paint()
      ..color = const Color(0xFF140803)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(doorRRect, doorPaint);

    // 7. Urucum Red Ancestral Markings for Mastered/Main Chief Malocas
    if (isMastered || isMain) {
      final chevronPaint = Paint()
        ..color = const Color(0xFFD32F2F).withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;
      const chevronCount = 3;
      final step = width * 0.45 / chevronCount;
      final startX = -(width * 0.22);
      for (int i = 0; i < chevronCount; i++) {
        final cx = startX + i * step;
        final p = Path()
          ..moveTo(cx, -height * 0.08)
          ..lineTo(cx + step * 0.5, -height * 0.24)
          ..lineTo(cx + step, -height * 0.08)
          ..close();
        canvas.drawPath(p, chevronPaint);
      }
    }

    canvas.restore();
  }

  void _paintCeremonialHearth({
    required Canvas canvas,
    required Offset center,
    required double zoom,
    required double animationTime,
    required double seed,
  }) {
    final r = (8.0 * zoom).clamp(4.5, 16.0);

    // 1. Warm Glow on the Soil
    final pulse = 0.88 + 0.12 * math.sin(animationTime * 5.5 + seed);
    final glowPaint = Paint()
      ..color = const Color(0xFFFF9800).withValues(alpha: 0.28 * pulse)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, r * 2.8, glowPaint);

    // 2. River Stone Circle
    const stoneCount = 6;
    final stonePaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < stoneCount; i++) {
      final angle = i * (2 * math.pi / stoneCount);
      final sx = center.dx + math.cos(angle) * (r * 0.95);
      final sy = center.dy + math.sin(angle) * (r * 0.85);
      stonePaint.color = i % 2 == 0 ? const Color(0xFF607D8B) : const Color(0xFF455A64);
      canvas.drawCircle(Offset(sx, sy), (2.0 * zoom).clamp(1.2, 3.5), stonePaint);
    }

    // 3. Glowing Red Embers
    final emberPaint = Paint()
      ..color = const Color(0xFFE64A19)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, r * 0.55, emberPaint);

    // 4. Dancing Flame
    final flicker = math.sin(animationTime * 8.0 + seed);
    final flameHeight = r * (1.6 + 0.3 * flicker);
    final flamePath = Path()
      ..moveTo(center.dx - r * 0.4, center.dy + r * 0.2)
      ..quadraticBezierTo(center.dx - r * 0.2, center.dy - flameHeight * 0.5, center.dx + flicker * 1.5, center.dy - flameHeight)
      ..quadraticBezierTo(center.dx + r * 0.2, center.dy - flameHeight * 0.5, center.dx + r * 0.4, center.dy + r * 0.2)
      ..close();

    final flamePaint = Paint()
      ..color = const Color(0xFFFFB300)
      ..style = PaintingStyle.fill;
    canvas.drawPath(flamePath, flamePaint);

    // Flame Core
    final corePaint = Paint()
      ..color = const Color(0xFFFFF59D)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center - Offset(0, r * 0.2), r * 0.28, corePaint);
  }

  /// Discrete zoom-dependent label (Section 11: World is the protagonist).
  void _paintDiscreetZoomLabel({
    required Canvas canvas,
    required Offset screenPt,
    required VillageNode village,
    required double zoom,
    required bool isMastered,
    required bool isSelected,
  }) {
    // When far away (zoom < 0.65): hide labels completely to let the natural world breathe!
    if (zoom < 0.65 && !isSelected) return;

    final titleText = village.tupiName;

    final textSpan = TextSpan(
      text: titleText,
      style: TextStyle(
        color: isSelected ? const Color(0xFFFFD54F) : const Color(0xFFF1F5F9),
        fontSize: (11.0 * zoom).clamp(10.0, 15.0),
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        shadows: const [
          Shadow(color: Color(0xCC000000), offset: Offset(0, 1.5), blurRadius: 3.0),
        ],
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final labelY = screenPt.dy - (65.0 * zoom);
    final labelCenter = Offset(screenPt.dx, labelY);

    // Small subtle wooden tag
    final tagRect = Rect.fromCenter(
      center: labelCenter,
      width: textPainter.width + 16.0,
      height: textPainter.height + 6.0,
    );

    final tagPaint = Paint()
      ..color = const Color(0xCC1A1108)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(tagRect, const Radius.circular(6.0)), tagPaint);

    if (isSelected || isMastered) {
      final borderPaint = Paint()
        ..color = isSelected ? const Color(0xFFFFD54F) : const Color(0xFFD4A359)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(RRect.fromRectAndRadius(tagRect, const Radius.circular(6.0)), borderPaint);
    }

    textPainter.paint(
      canvas,
      Offset(labelCenter.dx - textPainter.width / 2, labelCenter.dy - textPainter.height / 2),
    );
  }
}
