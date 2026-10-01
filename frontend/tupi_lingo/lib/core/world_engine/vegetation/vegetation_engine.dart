import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../camera/camera_state.dart';
import '../coordinates/world_bounds.dart';
import '../coordinates/world_coordinate.dart';

/// Botanical classifications of native Atlantic Forest / Pindorama vegetation.
enum VegetationType {
  canopyGiant,    // Jequitibá / Figueira ancestral de grande porte
  denseMata,      // Árvore frondosa clássica da Mata Atlântica
  palmeiraJucara, // Palmeira Juçara / Buriti esguio litorâneo
  araucaria,      // Araucária ancestral das altitudes do planalto
  shrubBush,      // Arbusto denso de sub-bosque e restinga
  highlandTree,   // Árvore menor / borda de floresta
  tallGrassTuft,  // Tufos de mato alto e capim silvestre com flores
  wildFern,       // Samambaia nativa de sub-bosque
  mossyLog,       // Tronco de árvore caído com musgo
  forestStone,    // Rocha / pedra natural apoiada no solo
}

/// Compact data-oriented representation of an individual tree instance.
class TreeInstance {
  final double wx;
  final double wy;
  final double scale;
  final VegetationType type;
  final int seed;

  const TreeInstance({
    required this.wx,
    required this.wy,
    required this.scale,
    required this.type,
    required this.seed,
  });

  WorldCoordinate get coordinate => WorldCoordinate(wx, wy);
}

/// Spatial cluster of forest vegetation.
class ForestChunk {
  final int chunkX;
  final int chunkY;
  final List<TreeInstance> trees;
  final WorldBounds bounds;

  const ForestChunk({
    required this.chunkX,
    required this.chunkY,
    required this.trees,
    required this.bounds,
  });
}

/// High-performance Continuous Forest & Vegetation Engine.
///
/// Implements:
/// - Dense continuous forest regions where canopies overlap naturally.
/// - Rich understory: tall grass, wild ferns, mossy logs, forest stones, shrubs.
/// - Clear environmental distinction: Dense Mata, Open Woods, Riparian Corridors, Clearings.
/// - Trees strictly avoid trails, riverbeds, and settlement courtyards.
/// - 2.5D vertical trunks, multi-tier foliage domes with Northwest sunlight highlights, and ground shadows.
/// - Spatial Chunk Grid (800x800) with aggressive Frustum Culling and 3-Tier LOD.
class VegetationEngine {
  VegetationEngine._() {
    _generateWorldForest();
  }

  static final VegetationEngine instance = VegetationEngine._();

  static const double chunkSize = 800.0;
  static const double clearanceRadius = 180.0;

  // Pre-allocated static reusable Paint instances to prevent per-frame GC churn on mobile/Android
  static final Paint _sharedShadowPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _sharedTrunkPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _sharedFoliagePaint = Paint()..style = PaintingStyle.fill;
  static final Paint _sharedStrokePaint = Paint()..style = PaintingStyle.stroke;

  final Map<int, ForestChunk> _chunkGrid = {};
  final List<TreeInstance> _allTrees = [];

  List<TreeInstance> get allTrees => _allTrees;

  int _chunkKey(int cx, int cy) => (cx & 0xFFFF) | ((cy & 0xFFFF) << 16);

  /// High-performance spatial query: retrieves only trees within visible bounds
  /// using the spatial chunk grid, avoiding iteration over 10,000+ trees each frame.
  List<TreeInstance> getTreesInBounds(WorldBounds bounds) {
    final minCx = (bounds.minX / chunkSize).floor();
    final maxCx = (bounds.maxX / chunkSize).ceil();
    final minCy = (bounds.minY / chunkSize).floor();
    final maxCy = (bounds.maxY / chunkSize).ceil();

    final result = <TreeInstance>[];
    for (int cx = minCx; cx <= maxCx; cx++) {
      for (int cy = minCy; cy <= maxCy; cy++) {
        final chunk = _chunkGrid[_chunkKey(cx, cy)];
        if (chunk != null) {
          for (final tree in chunk.trees) {
            if (tree.wx >= bounds.minX &&
                tree.wx <= bounds.maxX &&
                tree.wy >= bounds.minY &&
                tree.wy <= bounds.maxY) {
              result.add(tree);
            }
          }
        }
      }
    }
    return result;
  }

  /// Procedurally populates continuous forest zones across Pindorama.
  void _generateWorldForest() {
    _chunkGrid.clear();
    _allTrees.clear();

    // Village clearing exclusion zones (village center and generous clearance radius: 180.0px minimum)
    final villageClearings = [
      {'center': const WorldCoordinate(5000, 5000), 'radius': 190.0}, // Piratininga
      {'center': const WorldCoordinate(5350, 5550), 'radius': 180.0}, // São Vicente
      {'center': const WorldCoordinate(5700, 5350), 'radius': 180.0}, // Ubatuba
      {'center': const WorldCoordinate(6600, 4850), 'radius': 180.0}, // Guanabara
      {'center': const WorldCoordinate(7100, 4600), 'radius': 180.0}, // Cabo Frio
      // Regional Chapter Villages (mapa_pindorama):
      {'center': const WorldCoordinate(6900, 7000), 'radius': 210.0}, // Paranapiacaba (Reg 03)
      {'center': const WorldCoordinate(6800, 7200), 'radius': 190.0}, // Guaíbe / São Vicente (Reg 04)
      {'center': const WorldCoordinate(6700, 6900), 'radius': 180.0}, // Piratininga Campos (Reg 05)
      {'center': const WorldCoordinate(6000, 8400), 'radius': 180.0}, // Meiembipe (Reg 06)
      {'center': const WorldCoordinate(7400, 6500), 'radius': 180.0}, // Urucumirim (Reg 02)
      {'center': const WorldCoordinate(7200, 6800), 'radius': 180.0}, // Iperoig (Reg 01)
    ];

    // Forest Zones with rich botanical coverage across Pindorama
    // Total count reduced by 45% (from ~19,400 to ~10,670) to optimize canvas draw calls and mobile frame rates:
    // 1. Região de Iperoig, Ubatuba e Litoral Norte (3500 * 0.55 = 1925)
    _populateZone(
      center: const WorldCoordinate(7200, 6800),
      radiusX: 2000,
      radiusY: 1500,
      count: 1925,
      allowedTypes: [
        VegetationType.denseMata,
        VegetationType.canopyGiant,
        VegetationType.palmeiraJucara,
        VegetationType.shrubBush,
        VegetationType.wildFern,
        VegetationType.forestStone,
        VegetationType.tallGrassTuft,
      ],
      villageClearings: villageClearings,
    );

    // 2. Serra do Mar & Encostas de Paranapiacaba (3200 * 0.55 = 1760)
    _populateZone(
      center: const WorldCoordinate(6800, 7000),
      radiusX: 1800,
      radiusY: 1400,
      count: 1760,
      allowedTypes: [
        VegetationType.denseMata,
        VegetationType.canopyGiant,
        VegetationType.highlandTree,
        VegetationType.shrubBush,
        VegetationType.wildFern,
        VegetationType.mossyLog,
        VegetationType.forestStone,
      ],
      villageClearings: villageClearings,
    );

    // 3. Planalto de Piratininga & Cantareira (2800 * 0.55 = 1540)
    _populateZone(
      center: const WorldCoordinate(5000, 5000),
      radiusX: 1800,
      radiusY: 1400,
      count: 1540,
      allowedTypes: [
        VegetationType.denseMata,
        VegetationType.araucaria,
        VegetationType.highlandTree,
        VegetationType.shrubBush,
        VegetationType.tallGrassTuft,
        VegetationType.mossyLog,
      ],
      villageClearings: villageClearings,
    );

    // 4. Corredor Fluvial do Paraíba e Várzeas (2800 * 0.55 = 1540)
    _populateZone(
      center: const WorldCoordinate(6200, 6200),
      radiusX: 2000,
      radiusY: 1600,
      count: 1540,
      allowedTypes: [
        VegetationType.canopyGiant,
        VegetationType.palmeiraJucara,
        VegetationType.denseMata,
        VegetationType.wildFern,
        VegetationType.tallGrassTuft,
        VegetationType.mossyLog,
      ],
      villageClearings: villageClearings,
    );

    // 5. Baixada Santista, São Vicente e Restinga (2400 * 0.55 = 1320)
    _populateZone(
      center: const WorldCoordinate(5500, 5600),
      radiusX: 1600,
      radiusY: 1200,
      count: 1320,
      allowedTypes: [
        VegetationType.palmeiraJucara,
        VegetationType.shrubBush,
        VegetationType.tallGrassTuft,
        VegetationType.denseMata,
      ],
      villageClearings: villageClearings,
    );

    // 6. Baía de Guanabara & Encostas Tropicais (2500 * 0.55 = 1375)
    _populateZone(
      center: const WorldCoordinate(7500, 6400),
      radiusX: 1600,
      radiusY: 1300,
      count: 1375,
      allowedTypes: [
        VegetationType.palmeiraJucara,
        VegetationType.denseMata,
        VegetationType.shrubBush,
        VegetationType.tallGrassTuft,
        VegetationType.forestStone,
      ],
      villageClearings: villageClearings,
    );

    // 7. Encostas Altas do Norte e Serra da Mantiqueira (2200 * 0.55 = 1210)
    _populateZone(
      center: const WorldCoordinate(6400, 4500),
      radiusX: 1700,
      radiusY: 1200,
      count: 1210,
      allowedTypes: [
        VegetationType.araucaria,
        VegetationType.highlandTree,
        VegetationType.denseMata,
        VegetationType.forestStone,
        VegetationType.tallGrassTuft,
      ],
      villageClearings: villageClearings,
    );

    // Build spatial chunk index
    for (final tree in _allTrees) {
      final cx = (tree.wx / chunkSize).floor();
      final cy = (tree.wy / chunkSize).floor();
      final key = _chunkKey(cx, cy);

      if (!_chunkGrid.containsKey(key)) {
        _chunkGrid[key] = ForestChunk(
          chunkX: cx,
          chunkY: cy,
          trees: [],
          bounds: WorldBounds(
            minX: cx * chunkSize,
            minY: cy * chunkSize,
            maxX: (cx + 1) * chunkSize,
            maxY: (cy + 1) * chunkSize,
          ),
        );
      }
      _chunkGrid[key]!.trees.add(tree);
    }
  }

  // Helper to compute point-to-segment distance squared
  double _distToSegmentSq(double px, double py, double x1, double y1, double x2, double y2) {
    final l2 = (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1);
    if (l2 == 0) return (px - x1) * (px - x1) + (py - y1) * (py - y1);
    final t = (((px - x1) * (x2 - x1) + (py - y1) * (y2 - y1)) / l2).clamp(0.0, 1.0);
    final projX = x1 + t * (x2 - x1);
    final projY = y1 + t * (y2 - y1);
    return (px - projX) * (px - projX) + (py - projY) * (py - projY);
  }

  bool _isInsideRiverWater(double wx, double wy) {
    // Check main river centerlines with safe alluvial margins (65.0px minimum margin)
    const tieteWaypoints = [
      [6200.0, 5300.0], [5950.0, 5200.0], [5500.0, 5020.0], [5120.0, 4920.0],
      [4900.0, 4960.0], [4680.0, 5020.0], [4350.0, 4980.0], [3950.0, 4920.0],
      [3500.0, 4850.0], [2800.0, 4800.0],
    ];
    for (int i = 0; i < tieteWaypoints.length - 1; i++) {
      final p1 = tieteWaypoints[i];
      final p2 = tieteWaypoints[i + 1];
      if (_distToSegmentSq(wx, wy, p1[0], p1[1], p2[0], p2[1]) < 65.0 * 65.0) {
        return true;
      }
    }

    const paraibaWaypoints = [
      [5800.0, 4850.0], [6200.0, 4650.0], [6650.0, 4400.0], [7150.0, 4200.0], [7800.0, 3950.0],
      [6800.0, 6900.0], [8200.0, 6500.0],
    ];
    for (int i = 0; i < paraibaWaypoints.length - 1; i++) {
      final p1 = paraibaWaypoints[i];
      final p2 = paraibaWaypoints[i + 1];
      if (_distToSegmentSq(wx, wy, p1[0], p1[1], p2[0], p2[1]) < 65.0 * 65.0) {
        return true;
      }
    }

    const coastalEstuaryWaypoints = [
      [4500.0, 5150.0], [5100.0, 5380.0], [5380.0, 5580.0], [5600.0, 5800.0],
      [6400.0, 7200.0], [5800.0, 6900.0], [6700.0, 6750.0],
    ];
    for (int i = 0; i < coastalEstuaryWaypoints.length - 1; i++) {
      final p1 = coastalEstuaryWaypoints[i];
      final p2 = coastalEstuaryWaypoints[i + 1];
      if (_distToSegmentSq(wx, wy, p1[0], p1[1], p2[0], p2[1]) < 65.0 * 65.0) {
        return true;
      }
    }

    return false;
  }

  bool _isInsideTrailCorridor(double wx, double wy) {
    // 1. Caminho do Peabiru principal (55.0px clearance)
    const peabiruWaypoints = [
      [5350.0, 5550.0], [5200.0, 5300.0], [5000.0, 5000.0], [4600.0, 4800.0],
      [4100.0, 4700.0], [3500.0, 4650.0], [2800.0, 4600.0], [2100.0, 4550.0],
    ];
    for (int i = 0; i < peabiruWaypoints.length - 1; i++) {
      final p1 = peabiruWaypoints[i];
      final p2 = peabiruWaypoints[i + 1];
      if (_distToSegmentSq(wx, wy, p1[0], p1[1], p2[0], p2[1]) < 55.0 * 55.0) {
        return true;
      }
    }

    // 2. Trilha Litorânea entre as Aldeias
    const coastalTrailWaypoints = [
      [5350.0, 5550.0], [5700.0, 5350.0], [6150.0, 5100.0], [6600.0, 4850.0], [7100.0, 4600.0],
    ];
    for (int i = 0; i < coastalTrailWaypoints.length - 1; i++) {
      final p1 = coastalTrailWaypoints[i];
      final p2 = coastalTrailWaypoints[i + 1];
      if (_distToSegmentSq(wx, wy, p1[0], p1[1], p2[0], p2[1]) < 55.0 * 55.0) {
        return true;
      }
    }

    // 3. Trilhas de Fases entre os Capítulos Históricos (Paranapiacaba, Guaíbe, etc.)
    const regionalTrailWaypoints = [
      [6900.0, 7000.0], [6800.0, 7200.0], [6700.0, 6900.0], [6000.0, 8400.0], [7400.0, 6500.0],
    ];
    for (int i = 0; i < regionalTrailWaypoints.length - 1; i++) {
      final p1 = regionalTrailWaypoints[i];
      final p2 = regionalTrailWaypoints[i + 1];
      if (_distToSegmentSq(wx, wy, p1[0], p1[1], p2[0], p2[1]) < 55.0 * 55.0) {
        return true;
      }
    }

    return false;
  }

  void _populateZone({
    required WorldCoordinate center,
    required double radiusX,
    required double radiusY,
    required int count,
    required List<VegetationType> allowedTypes,
    required List<Map<String, dynamic>> villageClearings,
  }) {
    var seed = center.wx.toInt() ^ (center.wy.toInt() << 8);

    double nextRand() {
      seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF;
      return (seed & 0x7FFFFFFF) / 0x7FFFFFFF;
    }

    for (int i = 0; i < count; i++) {
      // Natural cluster distribution
      final angle = nextRand() * 2 * math.pi;
      final distFrac = math.sqrt(nextRand());
      final wx = center.wx + math.cos(angle) * (radiusX * distFrac);
      final wy = center.wy + math.sin(angle) * (radiusY * distFrac);

      // Check distance to village clearings: ensure at least clearanceRadius (90.0px)
      bool isInClearing = false;
      for (final cl in villageClearings) {
        final cCoord = cl['center'] as WorldCoordinate;
        final cRad = math.max(cl['radius'] as double, clearanceRadius);
        final d = cCoord.distanceTo(WorldCoordinate(wx, wy));
        if (d < cRad) {
          isInClearing = true;
          break;
        }
      }
      if (isInClearing) continue;

      // Don't spawn inside active river water beds
      if (_isInsideRiverWater(wx, wy)) continue;

      // Don't spawn large trees inside trail walking corridors (100% unobstructed)
      if (_isInsideTrailCorridor(wx, wy)) continue;

      // Increased canopy scale to fill natural volume with fewer draw calls
      final scale = 1.15 + nextRand() * 0.65;
      final typeIndex = (nextRand() * allowedTypes.length).toInt().clamp(0, allowedTypes.length - 1);
      final tree = TreeInstance(
        wx: wx,
        wy: wy,
        scale: scale,
        type: allowedTypes[typeIndex],
        seed: i + seed,
      );

      _allTrees.add(tree);
    }
  }

  /// Master render pass for the continuous forest with culling & LOD.
  void renderForest({
    required Canvas canvas,
    required Size size,
    required CameraState camera,
  }) {
    final visibleBounds = camera.getVisibleBounds(size);
    final zoom = camera.zoom;

    // Determine Level of Detail (LOD) based on zoom
    final int lod = zoom >= 1.2 ? 0 : (zoom >= 0.70 ? 1 : 2);

    // Identify visible chunks
    final minCx = ((visibleBounds.minX - 100) / chunkSize).floor();
    final maxCx = ((visibleBounds.maxX + 100) / chunkSize).floor();
    final minCy = ((visibleBounds.minY - 100) / chunkSize).floor();
    final maxCy = ((visibleBounds.maxY + 100) / chunkSize).floor();

    final visibleTrees = <TreeInstance>[];

    for (int cx = minCx; cx <= maxCx; cx++) {
      for (int cy = minCy; cy <= maxCy; cy++) {
        final chunk = _chunkGrid[_chunkKey(cx, cy)];
        if (chunk == null) continue;
        for (final tree in chunk.trees) {
          if (tree.wx >= visibleBounds.minX - 80 &&
              tree.wx <= visibleBounds.maxX + 80 &&
              tree.wy >= visibleBounds.minY - 80 &&
              tree.wy <= visibleBounds.maxY + 80) {
            visibleTrees.add(tree);
          }
        }
      }
    }

    if (visibleTrees.isEmpty) return;

    // Y-sorting: Sort trees from North to South so foreground trees overlap background trees!
    visibleTrees.sort((a, b) => a.wy.compareTo(b.wy));

    for (final tree in visibleTrees) {
      final screenPt = tree.coordinate.toScreen(
        cameraX: camera.x,
        cameraY: camera.y,
        zoom: zoom,
        screenSize: size,
      );

      renderSingleTree(
        canvas: canvas,
        screenPt: screenPt,
        tree: tree,
        zoom: zoom,
        lod: lod,
        shadowPaint: _sharedShadowPaint,
        trunkPaint: _sharedTrunkPaint,
        foliagePaint: _sharedFoliagePaint,
        screenSize: size,
      );
    }
  }

  void renderSingleTree({
    required Canvas canvas,
    required Offset screenPt,
    required TreeInstance tree,
    required double zoom,
    required int lod,
    required Paint shadowPaint,
    required Paint trunkPaint,
    required Paint foliagePaint,
    Size? screenSize,
  }) {
    final baseR = (26.0 * tree.scale * zoom).clamp(4.0, 95.0);

    // Viewport Culling Simples:
    // Se o retângulo da árvore estiver fora da viewport, ignore o desenho imediatamente
    if (screenSize != null) {
      final cullMargin = baseR * 1.8;
      if (screenPt.dx + cullMargin < 0 ||
          screenPt.dx - cullMargin > screenSize.width ||
          screenPt.dy + cullMargin < 0 ||
          screenPt.dy - cullMargin > screenSize.height) {
        return;
      }
    }

    // 0. Ambient Occlusion de Contato com o Terreno (Root AO disc)
    // Elimina completamente a impressão de 'PNG/sprite flutuando' ao colar o objeto na terra
    shadowPaint.color = const Color(0xFF0F1E10).withValues(alpha: 0.45);
    canvas.drawOval(
      Rect.fromCenter(
        center: screenPt,
        width: baseR * 1.05,
        height: baseR * 0.42,
      ),
      shadowPaint,
    );

    // 1. Sombra Direcional de Contato com o Terreno (Sudeste - luz de Noroeste)
    final shadowOffset = Offset(baseR * 0.45, baseR * 0.35);
    shadowPaint.color = const Color(0xFF142416).withValues(alpha: 0.38);
    canvas.drawOval(
      Rect.fromCenter(
        center: screenPt + shadowOffset,
        width: baseR * 1.55,
        height: baseR * 0.70,
      ),
      shadowPaint,
    );

    // 2. Nível de Detalhe Distante (LOD 2): Manta Contínua de Copa da Mata Atlântica
    if (lod == 2) {
      foliagePaint.color = const Color(0xFF1B4022);
      canvas.drawCircle(screenPt - Offset(0, baseR * 0.70), baseR * 0.90, foliagePaint);
      foliagePaint.color = const Color(0xFF2E6336);
      canvas.drawCircle(screenPt - Offset(baseR * 0.15, baseR * 0.80), baseR * 0.65, foliagePaint);
      return;
    }

    // 3. Tronco 2.5D enraizado no terreno para árvores de grande e médio porte
    final hasTrunk = tree.type == VegetationType.canopyGiant ||
        tree.type == VegetationType.denseMata ||
        tree.type == VegetationType.araucaria ||
        tree.type == VegetationType.highlandTree;

    if (lod <= 1 && hasTrunk) {
      trunkPaint.color = const Color(0xFF4A3423);
      final trunkH = baseR * 0.90;
      final trunkW = (baseR * 0.26).clamp(2.0, 10.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: screenPt - Offset(0, trunkH * 0.45),
            width: trunkW,
            height: trunkH,
          ),
          Radius.circular(trunkW * 0.4),
        ),
        trunkPaint,
      );
    }

    // 4. Copa e Geometria Botânica
    switch (tree.type) {
      case VegetationType.canopyGiant:
        _renderGiantCanopy(canvas, screenPt, baseR, lod, foliagePaint);
        break;
      case VegetationType.denseMata:
        _renderDenseMata(canvas, screenPt, baseR, lod, foliagePaint);
        break;
      case VegetationType.palmeiraJucara:
        _renderPalmeira(canvas, screenPt, baseR, lod, foliagePaint);
        break;
      case VegetationType.araucaria:
        _renderAraucaria(canvas, screenPt, baseR, lod, foliagePaint);
        break;
      case VegetationType.shrubBush:
        _renderShrub(canvas, screenPt, baseR, lod, foliagePaint, shadowPaint);
        break;
      case VegetationType.highlandTree:
        _renderHighlandTree(canvas, screenPt, baseR, lod, foliagePaint);
        break;
      case VegetationType.tallGrassTuft:
        _renderTallGrass(canvas, screenPt, baseR, lod, foliagePaint, shadowPaint);
        break;
      case VegetationType.wildFern:
        _renderWildFern(canvas, screenPt, baseR, lod, foliagePaint, shadowPaint);
        break;
      case VegetationType.mossyLog:
        _renderMossyLog(canvas, screenPt, baseR, lod, foliagePaint, shadowPaint);
        break;
      case VegetationType.forestStone:
        _renderForestStone(canvas, screenPt, baseR, lod, foliagePaint, shadowPaint);
        break;
    }
  }

  void _renderGiantCanopy(Canvas canvas, Offset pt, double r, int lod, Paint paint) {
    final canopyCenter = pt - Offset(0, r * 1.15);

    // Tier 1 - Deep shadow base
    paint.color = const Color(0xFF193B1F);
    canvas.drawCircle(canopyCenter + Offset(r * 0.15, r * 0.15), r * 1.05, paint);

    // Tier 2 - Mid lush canopy
    paint.color = const Color(0xFF25522B);
    canvas.drawCircle(canopyCenter, r * 0.95, paint);

    if (lod <= 1) {
      // Tier 3 - Sunlit highlights facing Northwest
      paint.color = const Color(0xFF45784A);
      canvas.drawCircle(canopyCenter - Offset(r * 0.28, r * 0.28), r * 0.62, paint);

      // Gold-green canopy crown
      paint.color = const Color(0xFF5D9652);
      canvas.drawCircle(canopyCenter - Offset(r * 0.38, r * 0.38), r * 0.32, paint);
    }
  }

  void _renderDenseMata(Canvas canvas, Offset pt, double r, int lod, Paint paint) {
    final canopyCenter = pt - Offset(0, r * 0.90);

    // Shaded foliage base
    paint.color = const Color(0xFF1F4225);
    canvas.drawOval(
      Rect.fromCenter(center: canopyCenter + Offset(r * 0.1, r * 0.1), width: r * 1.7, height: r * 1.4),
      paint,
    );

    // Primary canopy dome
    paint.color = const Color(0xFF326338);
    canvas.drawOval(
      Rect.fromCenter(center: canopyCenter, width: r * 1.5, height: r * 1.25),
      paint,
    );

    if (lod <= 1) {
      // Sunlit crest facing Northwest
      paint.color = const Color(0xFF528850);
      canvas.drawCircle(canopyCenter - Offset(r * 0.25, r * 0.22), r * 0.52, paint);
    }
  }

  void _renderPalmeira(Canvas canvas, Offset pt, double r, int lod, Paint paint) {
    final top = pt - Offset(0, r * 1.4);

    // Slender fronds radiating out using preallocated stroke paint
    _sharedStrokePaint.strokeWidth = (r * 0.24).clamp(1.5, 6.5);
    _sharedStrokePaint.strokeCap = StrokeCap.round;

    const frondAngles = [-2.2, -1.5, -0.8, -0.2, 0.4, 1.2];
    for (final angle in frondAngles) {
      _sharedStrokePaint.color = angle < -1.0 ? const Color(0xFF689F38) : const Color(0xFF457828);
      final fx = top.dx + math.cos(angle) * (r * 0.85);
      final fy = top.dy + math.sin(angle) * (r * 0.85);
      canvas.drawLine(top, Offset(fx, fy), _sharedStrokePaint);
    }
  }

  void _renderAraucaria(Canvas canvas, Offset pt, double r, int lod, Paint paint) {
    final top = pt - Offset(0, r * 1.35);

    // Umbrella-like ancestral highland crown
    paint.color = const Color(0xFF1B4228);
    canvas.drawOval(
      Rect.fromCenter(center: top + Offset(0, r * 0.1), width: r * 1.8, height: r * 0.55),
      paint,
    );

    paint.color = const Color(0xFF2F663C);
    canvas.drawOval(
      Rect.fromCenter(center: top, width: r * 1.5, height: r * 0.45),
      paint,
    );

    if (lod <= 1) {
      paint.color = const Color(0xFF4C8A59);
      canvas.drawOval(
        Rect.fromCenter(center: top - Offset(r * 0.2, r * 0.08), width: r * 0.8, height: r * 0.25),
        paint,
      );
    }
  }

  void _renderShrub(Canvas canvas, Offset pt, double r, int lod, Paint paint, Paint shadowPaint) {
    // Ground contact shadow
    shadowPaint.color = const Color(0xFF111E11).withValues(alpha: 0.35);
    canvas.drawOval(Rect.fromCenter(center: pt + Offset(r * 0.15, r * 0.08), width: r * 1.2, height: r * 0.45), shadowPaint);

    // Low undergrowth mound
    paint.color = const Color(0xFF33572E);
    canvas.drawOval(
      Rect.fromCenter(center: pt - Offset(0, r * 0.3), width: r * 1.3, height: r * 0.8),
      paint,
    );

    paint.color = const Color(0xFF4F7A40);
    canvas.drawCircle(pt - Offset(r * 0.15, r * 0.4), r * 0.45, paint);
  }

  void _renderHighlandTree(Canvas canvas, Offset pt, double r, int lod, Paint paint) {
    final top = pt - Offset(0, r * 0.85);
    paint.color = const Color(0xFF2B5430);
    canvas.drawCircle(top + Offset(r * 0.08, r * 0.08), r * 0.85, paint);

    paint.color = const Color(0xFF487A42);
    canvas.drawCircle(top, r * 0.72, paint);

    if (lod <= 1) {
      paint.color = const Color(0xFF68A358);
      canvas.drawCircle(top - Offset(r * 0.22, r * 0.20), r * 0.40, paint);
    }
  }

  void _renderTallGrass(Canvas canvas, Offset pt, double r, int lod, Paint paint, Paint shadowPaint) {
    // Ground contact shadow
    shadowPaint.color = const Color(0xFF111E11).withValues(alpha: 0.30);
    canvas.drawOval(Rect.fromCenter(center: pt, width: r * 1.0, height: r * 0.35), shadowPaint);

    // Tufo de capim silvestre
    paint.color = const Color(0xFF4C7532);
    canvas.drawOval(Rect.fromCenter(center: pt - Offset(0, r * 0.2), width: r * 1.1, height: r * 0.55), paint);

    paint.color = const Color(0xFF6B9B45);
    canvas.drawCircle(pt - Offset(r * 0.2, r * 0.25), r * 0.35, paint);
    canvas.drawCircle(pt + Offset(r * 0.18, r * 0.22), r * 0.30, paint);

    // Pequenas flores silvestres amarelas nas clareiras
    if (lod <= 1) {
      paint.color = const Color(0xFFFACC15);
      canvas.drawCircle(pt - Offset(r * 0.1, r * 0.45), 1.8, paint);
      canvas.drawCircle(pt + Offset(r * 0.25, r * 0.38), 1.5, paint);
    }
  }

  void _renderWildFern(Canvas canvas, Offset pt, double r, int lod, Paint paint, Paint shadowPaint) {
    // Ground contact shadow
    shadowPaint.color = const Color(0xFF0F1E10).withValues(alpha: 0.32);
    canvas.drawOval(Rect.fromCenter(center: pt, width: r * 0.95, height: r * 0.35), shadowPaint);

    // Samambaia de sub-bosque úmido
    paint.color = const Color(0xFF1E5228);
    canvas.drawCircle(pt - Offset(0, r * 0.2), r * 0.50, paint);

    paint.color = const Color(0xFF2E7D32);
    canvas.drawOval(Rect.fromCenter(center: pt - Offset(0, r * 0.3), width: r * 1.2, height: r * 0.40), paint);

    if (lod <= 1) {
      paint.color = const Color(0xFF4CAF50);
      canvas.drawCircle(pt - Offset(r * 0.15, r * 0.35), r * 0.25, paint);
    }
  }

  void _renderMossyLog(Canvas canvas, Offset pt, double r, int lod, Paint paint, Paint shadowPaint) {
    // Ground contact shadow under log
    shadowPaint.color = const Color(0xFF0F140F).withValues(alpha: 0.45);
    canvas.drawOval(Rect.fromCenter(center: pt + Offset(r * 0.1, r * 0.05), width: r * 1.6, height: r * 0.40), shadowPaint);

    // Tronco caído com musgo
    paint.color = const Color(0xFF3E2A1C);
    final logRect = Rect.fromCenter(center: pt - Offset(0, r * 0.15), width: r * 1.6, height: r * 0.45);
    canvas.drawRRect(RRect.fromRectAndRadius(logRect, Radius.circular(r * 0.2)), paint);

    // Mancha de musgo verde vivo sobre o tronco
    paint.color = const Color(0xFF558B2F);
    canvas.drawOval(
      Rect.fromCenter(center: pt - Offset(r * 0.15, r * 0.25), width: r * 0.9, height: r * 0.25),
      paint,
    );
  }

  void _renderForestStone(Canvas canvas, Offset pt, double r, int lod, Paint paint, Paint shadowPaint) {
    // Ground contact shadow under stone
    shadowPaint.color = const Color(0xFF0F140F).withValues(alpha: 0.48);
    canvas.drawOval(Rect.fromCenter(center: pt + Offset(r * 0.1, r * 0.05), width: r * 1.2, height: r * 0.45), shadowPaint);

    // Pedra / rocha natural com contato ao solo
    paint.color = const Color(0xFF4B5563);
    canvas.drawOval(Rect.fromCenter(center: pt - Offset(0, r * 0.15), width: r * 1.1, height: r * 0.70), paint);

    if (lod <= 1) {
      paint.color = const Color(0xFF6B7280);
      canvas.drawCircle(pt - Offset(r * 0.18, r * 0.25), r * 0.38, paint);

      // Musgo na base
      paint.color = const Color(0xFF365314).withValues(alpha: 0.75);
      canvas.drawOval(Rect.fromCenter(center: pt + Offset(0, r * 0.05), width: r * 0.95, height: r * 0.25), paint);
    }
  }
}
