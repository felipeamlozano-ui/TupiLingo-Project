import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../camera/camera_state.dart';
import '../coordinates/world_bounds.dart';
import '../coordinates/world_coordinate.dart';
import '../theme/pindorama_theme_palette.dart';

/// Segment of topographical relief (Hill ridge or mountain cliff).
class TerrainRidge {
  final WorldCoordinate start;
  final WorldCoordinate control;
  final WorldCoordinate end;
  final double elevation;
  final double width;
  final String label;

  const TerrainRidge({
    required this.start,
    required this.control,
    required this.end,
    required this.elevation,
    required this.width,
    required this.label,
  });
}

/// Represents a distinct natural geographic zone on the continuous map.
class TerrainBiomeZone {
  final String id;
  final String name;
  final WorldCoordinate center;
  final double radiusX;
  final double radiusY;
  final double rotation;
  final Color primaryColor;
  final Color secondaryColor;
  final Color soilColor;
  final double elevationBase;

  const TerrainBiomeZone({
    required this.id,
    required this.name,
    required this.center,
    required this.radiusX,
    required this.radiusY,
    this.rotation = 0.0,
    required this.primaryColor,
    required this.secondaryColor,
    required this.soilColor,
    this.elevationBase = 0.0,
  });
}

/// Coastal island formation
class CoastalIsland {
  final String name;
  final WorldCoordinate center;
  final double width;
  final double height;
  final double rotation;

  const CoastalIsland({
    required this.name,
    required this.center,
    required this.width,
    required this.height,
    this.rotation = 0.0,
  });
}

/// High-performance continuous 2.5D/3D Terrain & Relief Engine.
///
/// Constructs a living, natural historical landscape with:
/// - Real topographical relief (elevated plateaus, mountain escarpments, rolling hills).
/// - Layered continental geology with warm soil blending (terra roxa, aluvião, areia, granito).
/// - Directional 3D hill-shading (Sunlight from Northwest at 315°, shadow to Southeast at 135°).
/// - Atlantic coastline with shallow surf, restingas, sandbanks, and coastal islands.
class TerrainMeshEngine {
  TerrainMeshEngine._();
  static final TerrainMeshEngine instance = TerrainMeshEngine._();

  // Canonical Coastline of Pindorama (Cananéia -> Iguape -> Santos -> São Sebastião -> Ubatuba -> Paraty -> Guanabara -> Cabo Frio)
  static const List<WorldCoordinate> canonicalCoastline = [
    WorldCoordinate(3400, 7200),
    WorldCoordinate(3700, 6800),
    WorldCoordinate(4100, 6400),
    WorldCoordinate(4600, 6050),
    WorldCoordinate(5100, 5800),
    WorldCoordinate(5350, 5650), // Baixada Santista
    WorldCoordinate(5650, 5500),
    WorldCoordinate(6050, 5320), // Canal de São Sebastião
    WorldCoordinate(6500, 5150), // Ubatuba
    WorldCoordinate(6900, 4980), // Paraty / Ilha Grande
    WorldCoordinate(7350, 4820), // Entrada da Guanabara
    WorldCoordinate(7750, 4680), // Niterói / Maricá
    WorldCoordinate(8200, 4520), // Arraial do Cabo
    WorldCoordinate(8600, 4400), // Cabo Frio
    WorldCoordinate(9200, 4200), // Rumo ao Norte
  ];

  // Coastal islands
  static const List<CoastalIsland> canonicalIslands = [
    CoastalIsland(name: 'Ilhabela / São Sebastião', center: WorldCoordinate(6150, 5420), width: 140, height: 190, rotation: 0.35),
    CoastalIsland(name: 'Ilha Grande', center: WorldCoordinate(6950, 5080), width: 160, height: 110, rotation: -0.25),
    CoastalIsland(name: 'Ilha de Santo Amaro / Guarujá', center: WorldCoordinate(5450, 5720), width: 90, height: 75, rotation: 0.15),
  ];

  // Mountain ridges forming the Great Escarpment (Serra do Mar & Serra da Mantiqueira)
  static const List<TerrainRidge> canonicalRidges = [
    // 1. Escadaria da Serra do Mar (Paranapiacaba)
    TerrainRidge(
      start: WorldCoordinate(4600, 5900),
      control: WorldCoordinate(5150, 5450),
      end: WorldCoordinate(5800, 5150),
      elevation: 780.0,
      width: 180.0,
      label: 'Serra do Mar - Paranapiacaba',
    ),
    // 2. Serra de Paranapiacaba ao Sul
    TerrainRidge(
      start: WorldCoordinate(4000, 6500),
      control: WorldCoordinate(4350, 6150),
      end: WorldCoordinate(4650, 5850),
      elevation: 650.0,
      width: 140.0,
      label: 'Serra de Paranapiacaba',
    ),
    // 3. Serra da Bocaina / Litoral Norte
    TerrainRidge(
      start: WorldCoordinate(5850, 5100),
      control: WorldCoordinate(6450, 4800),
      end: WorldCoordinate(7100, 4600),
      elevation: 880.0,
      width: 190.0,
      label: 'Serra da Bocaina',
    ),
    // 4. Serra dos Órgãos / Serra do Mar Fluminense
    TerrainRidge(
      start: WorldCoordinate(7150, 4550),
      control: WorldCoordinate(7650, 4400),
      end: WorldCoordinate(8250, 4250),
      elevation: 940.0,
      width: 170.0,
      label: 'Serra dos Órgãos',
    ),
    // 5. Serra da Cantareira (Norte do Planalto de Piratininga)
    TerrainRidge(
      start: WorldCoordinate(4700, 4750),
      control: WorldCoordinate(5100, 4650),
      end: WorldCoordinate(5500, 4700),
      elevation: 580.0,
      width: 120.0,
      label: 'Serra da Cantareira',
    ),
    // 6. Serra da Mantiqueira (Cordilheira interiorana ancestral)
    TerrainRidge(
      start: WorldCoordinate(5300, 4400),
      control: WorldCoordinate(6100, 4200),
      end: WorldCoordinate(7000, 4100),
      elevation: 980.0,
      width: 220.0,
      label: 'Serra da Mantiqueira',
    ),
  ];

  // Biome zones that shape the environment
  static const List<TerrainBiomeZone> canonicalBiomes = [
    // 1. Planalto de Piratininga (Terra roxa fértil, cerrado arborizado, grama verde e dourada)
    TerrainBiomeZone(
      id: 'planalto_piratininga',
      name: 'Planalto de Piratininga',
      center: WorldCoordinate(4950, 5050),
      radiusX: 1500.0,
      radiusY: 1200.0,
      rotation: -0.2,
      primaryColor: Color(0xFF4A7238),   // Verde campos temperados vivos
      secondaryColor: Color(0xFF5E8548), // Grama de cerrado e planalto
      soilColor: Color(0xFF7A4222),      // Terra vermelha fértil
      elevationBase: 760.0,
    ),
    // 2. Corredor da Mata Atlântica das Encostas (Selva densa, verde profundo, umidade da serra)
    TerrainBiomeZone(
      id: 'mata_atlantica_escarpa',
      name: 'Mata Atlântica das Escarpas',
      center: WorldCoordinate(5600, 5300),
      radiusX: 2100.0,
      radiusY: 900.0,
      rotation: -0.45,
      primaryColor: Color(0xFF2C5532),   // Verde floresta exuberante
      secondaryColor: Color(0xFF38683D), // Dossel úmido
      soilColor: Color(0xFF3A2818),      // Húmus escuro rico
      elevationBase: 450.0,
    ),
    // 3. Planície Litorânea e Restinga (Areia clara, solo arenoso, restinga)
    TerrainBiomeZone(
      id: 'litoral_baixada',
      name: 'Planície Litorânea e Restingas',
      center: WorldCoordinate(5650, 5750),
      radiusX: 1900.0,
      radiusY: 750.0,
      rotation: -0.42,
      primaryColor: Color(0xFF527045),   // Vegetação de restinga
      secondaryColor: Color(0xFF888B5E), // Arbustos de dunas
      soilColor: Color(0xFFCEBD90),      // Areia dourada e sedimentos
      elevationBase: 20.0,
    ),
    // 4. Várzea do Vale do Paraíba (Campos aluviais férteis ao norte da Serra)
    TerrainBiomeZone(
      id: 'vale_paraiba',
      name: 'Vale Aluvial do Paraíba',
      center: WorldCoordinate(6300, 4650),
      radiusX: 1450.0,
      radiusY: 700.0,
      rotation: -0.38,
      primaryColor: Color(0xFF3D6638),
      secondaryColor: Color(0xFF4F7D47),
      soilColor: Color(0xFF583F25),
      elevationBase: 580.0,
    ),
    // 5. Enseada da Baía de Guanabara (Morros graníticos e restinga abrigada)
    TerrainBiomeZone(
      id: 'baia_guanabara',
      name: 'Enseada da Guanabara',
      center: WorldCoordinate(7300, 4800),
      radiusX: 1000.0,
      radiusY: 850.0,
      rotation: 0.1,
      primaryColor: Color(0xFF366138),
      secondaryColor: Color(0xFF48774B),
      soilColor: Color(0xFF5E4E36),
      elevationBase: 40.0,
    ),
  ];

  /// Master render pass for the continuous terrain.
  void renderTerrain({
    required Canvas canvas,
    required Size size,
    required CameraState camera,
    required PindoramaThemePalette palette,
    double animationTime = 0.0,
  }) {
    final visibleBounds = camera.getVisibleBounds(size);

    // 1. Base Continental Foundation com Micro-Variações de Solo e Grama
    _paintContinentalBase(canvas, size, camera, visibleBounds, palette);

    // 2. Manchas Geológicas de Solo Natural (Terra Roxa, Húmus, Argila e Várzea)
    _paintNaturalSoilPatches(canvas, size, camera, visibleBounds);

    // 3. Curvas de Nível e Relevo Topográfico Suave (Cotas de Altitude)
    _paintTopographicalContours(canvas, size, camera, visibleBounds);

    // 4. Biome Patches with Organic Soil & Foliage Blending
    _paintBiomeRegions(canvas, size, camera, visibleBounds);

    // 5. Rolling Hills (Mares de Morros) com Sombreamento Direcional 3D
    _paintRollingHills(canvas, size, camera, visibleBounds);

    // 6. Mountain Ridges & Escarpments with Sunlight and Shadow
    _paintMountainRidges(canvas, size, camera, visibleBounds);

    // 7. Afloramentos Rochosos Graníticos e Pedras Naturais de Encosta
    _paintGraniteOutcrops(canvas, size, camera, visibleBounds);
  }

  void _paintContinentalBase(
    Canvas canvas,
    Size size,
    CameraState camera,
    WorldBounds visibleBounds,
    PindoramaThemePalette palette,
  ) {
    final zoom = camera.zoom;

    // 1. Fundo continental terroso natural e fértil (eliminando qualquer sensação de vazio azul ou verde liso)
    final bgPaint = Paint()
      ..color = const Color(0xFF344E28)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final patchPaint = Paint()..style = PaintingStyle.fill;
    final flowerPaint = Paint()..style = PaintingStyle.fill;
    final pebblePaint = Paint()..style = PaintingStyle.fill;

    // 2. Macro-regiões de umidade e solo (440x440 world units)
    const double macroCellSize = 440.0;
    final minMx = (visibleBounds.minX / macroCellSize).floor();
    final maxMx = (visibleBounds.maxX / macroCellSize).ceil();
    final minMy = (visibleBounds.minY / macroCellSize).floor();
    final maxMy = (visibleBounds.maxY / macroCellSize).ceil();

    for (int mx = minMx; mx <= maxMx; mx++) {
      for (int my = minMy; my <= maxMy; my++) {
        final mh = ((mx * 374761393 + my * 668265263) ^ 0x5DEECE66D) & 0x7FFFFFFF;
        final mVariant = mh % 4;
        final offX = ((mh >> 4) % 80) - 40.0;
        final offY = ((mh >> 8) % 80) - 40.0;

        final worldX = mx * macroCellSize + macroCellSize / 2 + offX;
        final worldY = my * macroCellSize + macroCellSize / 2 + offY;

        final screenPt = WorldCoordinate(worldX, worldY).toScreen(
          cameraX: camera.x,
          cameraY: camera.y,
          zoom: zoom,
          screenSize: size,
        );

        final mRad = (macroCellSize * 0.85 * zoom).clamp(30.0, 750.0);

        switch (mVariant) {
          case 0:
            // Floresta úmida densa / terra rica
            patchPaint.color = const Color(0xFF284820).withValues(alpha: 0.65);
            break;
          case 1:
            // Savana / cerrado gramíneo dourado
            patchPaint.color = const Color(0xFF557B36).withValues(alpha: 0.58);
            break;
          case 2:
            // Terra roxa fértil de planalto
            patchPaint.color = const Color(0xFF6A3B1C).withValues(alpha: 0.38);
            break;
          case 3:
            // Campo verdejante aberto
            patchPaint.color = const Color(0xFF456F30).withValues(alpha: 0.52);
            break;
        }

        canvas.drawOval(
          Rect.fromCenter(center: screenPt, width: mRad * 1.6, height: mRad * 1.3),
          patchPaint,
        );
      }
    }

    // 3. Micro-variações de solo, tufos de capim, terra exposta e clareiras (160x160 world units)
    // Garante que em qualquer nível de zoom o solo tenha riqueza tátil e orgânica contínua
    const double microCellSize = 160.0;
    final minCx = (visibleBounds.minX / microCellSize).floor();
    final maxCx = (visibleBounds.maxX / microCellSize).ceil();
    final minCy = (visibleBounds.minY / microCellSize).floor();
    final maxCy = (visibleBounds.maxY / microCellSize).ceil();

    for (int cx = minCx; cx <= maxCx; cx++) {
      for (int cy = minCy; cy <= maxCy; cy++) {
        final h = ((cx * 1664525 + cy * 1013904223) ^ 0x4B3B82C1) & 0x7FFFFFFF;
        final variant = h % 8;
        final offsetX = ((h >> 3) % 40) - 20.0;
        final offsetY = ((h >> 7) % 40) - 20.0;

        final worldX = cx * microCellSize + microCellSize / 2 + offsetX;
        final worldY = cy * microCellSize + microCellSize / 2 + offsetY;

        final screenPt = WorldCoordinate(worldX, worldY).toScreen(
          cameraX: camera.x,
          cameraY: camera.y,
          zoom: zoom,
          screenSize: size,
        );

        final rad = (microCellSize * 0.65 * zoom).clamp(10.0, 220.0);

        switch (variant) {
          case 0:
            // Tufo denso de capim verde esmeralda
            patchPaint.color = const Color(0xFF3B682E).withValues(alpha: 0.60);
            canvas.drawOval(Rect.fromCenter(center: screenPt, width: rad * 1.4, height: rad * 1.1), patchPaint);
            break;
          case 1:
            // Capim claro ensolarado de planalto
            patchPaint.color = const Color(0xFF5A8440).withValues(alpha: 0.55);
            canvas.drawOval(Rect.fromCenter(center: screenPt, width: rad * 1.3, height: rad * 1.0), patchPaint);
            break;
          case 2:
            // Mancha de terra roxa / argila fértil sob a vegetação
            patchPaint.color = const Color(0xFF6B3A1A).withValues(alpha: 0.42);
            canvas.drawOval(Rect.fromCenter(center: screenPt, width: rad * 1.2, height: rad * 0.9), patchPaint);
            break;
          case 3:
            // Musgo escuro de sub-bosque úmido
            patchPaint.color = const Color(0xFF243F1C).withValues(alpha: 0.65);
            canvas.drawOval(Rect.fromCenter(center: screenPt, width: rad * 1.5, height: rad * 1.2), patchPaint);
            break;
          case 4:
            // Clareira de grama amarelada e seca
            patchPaint.color = const Color(0xFF688D4A).withValues(alpha: 0.48);
            canvas.drawOval(Rect.fromCenter(center: screenPt, width: rad * 1.35, height: rad * 1.15), patchPaint);
            // Pequenos pontinhos de flores amarelas nas clareiras se estiver próximo
            if (zoom >= 0.70) {
              flowerPaint.color = const Color(0xFFFACC15).withValues(alpha: 0.70);
              canvas.drawCircle(screenPt + Offset(rad * 0.2, rad * 0.15), 1.8 * zoom, flowerPaint);
              canvas.drawCircle(screenPt - Offset(rad * 0.25, rad * 0.1), 1.5 * zoom, flowerPaint);
            }
            break;
          case 5:
            // Húmus escuro rico e folhas secas caídas
            patchPaint.color = const Color(0xFF4A341E).withValues(alpha: 0.45);
            canvas.drawOval(Rect.fromCenter(center: screenPt, width: rad * 1.1, height: rad * 0.8), patchPaint);
            if (zoom >= 0.80) {
              pebblePaint.color = const Color(0xFF78716C).withValues(alpha: 0.55);
              canvas.drawOval(Rect.fromCenter(center: screenPt + Offset(rad * 0.3, rad * 0.2), width: 3.5 * zoom, height: 2.2 * zoom), pebblePaint);
            }
            break;
          case 6:
            // Sedimento claro e areia aluvial
            patchPaint.color = const Color(0xFFB5A172).withValues(alpha: 0.35);
            canvas.drawOval(Rect.fromCenter(center: screenPt, width: rad * 1.2, height: rad * 0.85), patchPaint);
            break;
          case 7:
            // Grama alta vibrante
            patchPaint.color = const Color(0xFF4A7635).withValues(alpha: 0.50);
            canvas.drawOval(Rect.fromCenter(center: screenPt, width: rad * 1.3, height: rad * 1.1), patchPaint);
            break;
        }
      }
    }
  }

  /// Manchas geológicas ricas de solo fértil: Terra Roxa, Várzea e Sedimentos.
  void _paintNaturalSoilPatches(
    Canvas canvas,
    Size size,
    CameraState camera,
    WorldBounds visibleBounds,
  ) {
    final zoom = camera.zoom;
    final soilPaint = Paint()..style = PaintingStyle.fill;

    // Manchas geológicas canônicas de Pindorama
    const soilDeposits = [
      // Terra roxa de Piratininga e colinas vizinhas
      {'wx': 4850.0, 'wy': 5120.0, 'rx': 380.0, 'ry': 240.0, 'color': Color(0xFF703D1E), 'alpha': 0.45},
      {'wx': 5150.0, 'wy': 4950.0, 'rx': 340.0, 'ry': 220.0, 'color': Color(0xFF68381A), 'alpha': 0.42},
      {'wx': 4550.0, 'wy': 4850.0, 'rx': 420.0, 'ry': 260.0, 'color': Color(0xFF5E3418), 'alpha': 0.38},
      // Sedimentos úmidos de vale no Tietê
      {'wx': 4200.0, 'wy': 4980.0, 'rx': 460.0, 'ry': 200.0, 'color': Color(0xFF4D3820), 'alpha': 0.48},
      {'wx': 3650.0, 'wy': 5020.0, 'rx': 520.0, 'ry': 240.0, 'color': Color(0xFF48351E), 'alpha': 0.45},
      // Húmus escuro da serra da Mantiqueira e Bocaina
      {'wx': 6400.0, 'wy': 4450.0, 'rx': 480.0, 'ry': 280.0, 'color': Color(0xFF281E14), 'alpha': 0.42},
      {'wx': 7200.0, 'wy': 4380.0, 'rx': 510.0, 'ry': 250.0, 'color': Color(0xFF251A10), 'alpha': 0.40},
    ];

    for (final deposit in soilDeposits) {
      final wx = deposit['wx'] as double;
      final wy = deposit['wy'] as double;
      final rx = (deposit['rx'] as double) * zoom;
      final ry = (deposit['ry'] as double) * zoom;

      if (wx + rx < visibleBounds.minX ||
          wx - rx > visibleBounds.maxX ||
          wy + ry < visibleBounds.minY ||
          wy - ry > visibleBounds.maxY) {
        continue;
      }

      final screenPt = WorldCoordinate(wx, wy).toScreen(
        cameraX: camera.x,
        cameraY: camera.y,
        zoom: zoom,
        screenSize: size,
      );

      final col = deposit['color'] as Color;
      final alpha = deposit['alpha'] as double;
      soilPaint.color = col.withValues(alpha: alpha);

      canvas.drawOval(
        Rect.fromCenter(center: screenPt, width: rx * 2.0, height: ry * 2.0),
        soilPaint,
      );
    }
  }

  /// Curvas de nível topográficas sutis que revelam a morfologia e altitude do terreno.
  void _paintTopographicalContours(
    Canvas canvas,
    Size size,
    CameraState camera,
    WorldBounds visibleBounds,
  ) {
    if (camera.zoom < 0.60) return;

    final contourPaint = Paint()
      ..color = const Color(0xFF7DA866).withValues(alpha: 0.18)
      ..strokeWidth = (1.5 * camera.zoom).clamp(1.0, 3.0)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Patamares de altitude do Planalto Paulista e Vale do Paraíba
    const contourPolygons = [
      // Cota 760m - Planalto de Piratininga
      [
        WorldCoordinate(4500, 5200),
        WorldCoordinate(4750, 4850),
        WorldCoordinate(5200, 4800),
        WorldCoordinate(5450, 5050),
        WorldCoordinate(5300, 5300),
        WorldCoordinate(4800, 5350),
      ],
      // Cota 880m - Serras da Bocaina e Cunha
      [
        WorldCoordinate(6100, 4750),
        WorldCoordinate(6550, 4520),
        WorldCoordinate(7050, 4420),
        WorldCoordinate(7300, 4650),
        WorldCoordinate(6800, 4850),
      ],
    ];

    for (final poly in contourPolygons) {
      final path = Path();
      final first = poly.first.toScreen(
        cameraX: camera.x,
        cameraY: camera.y,
        zoom: camera.zoom,
        screenSize: size,
      );
      path.moveTo(first.dx, first.dy);

      for (int i = 1; i < poly.length; i++) {
        final pt = poly[i].toScreen(
          cameraX: camera.x,
          cameraY: camera.y,
          zoom: camera.zoom,
          screenSize: size,
        );
        path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      canvas.drawPath(path, contourPaint);
    }
  }

  /// Afloramentos rochosos graníticos (pedras de morro, matacões e lajedos).
  void _paintGraniteOutcrops(
    Canvas canvas,
    Size size,
    CameraState camera,
    WorldBounds visibleBounds,
  ) {
    final zoom = camera.zoom;
    final stoneBasePaint = Paint()..style = PaintingStyle.fill;
    final stoneSunlitPaint = Paint()..style = PaintingStyle.fill;
    final stoneShadowPaint = Paint()..style = PaintingStyle.fill;

    // Matacões graníticos canônicos da Serra do Mar e da Cantareira
    const rockClusters = [
      {'wx': 4750.0, 'wy': 4700.0, 'w': 28.0, 'h': 18.0}, // Cantareira
      {'wx': 5100.0, 'wy': 4620.0, 'w': 34.0, 'h': 22.0},
      {'wx': 5400.0, 'wy': 4680.0, 'w': 26.0, 'h': 16.0},
      {'wx': 5200.0, 'wy': 5350.0, 'w': 32.0, 'h': 20.0}, // Encosta Paranapiacaba
      {'wx': 5550.0, 'wy': 5220.0, 'w': 38.0, 'h': 24.0},
      {'wx': 6400.0, 'wy': 4750.0, 'w': 42.0, 'h': 26.0}, // Bocaina
      {'wx': 6850.0, 'wy': 4650.0, 'w': 36.0, 'h': 22.0},
      {'wx': 7500.0, 'wy': 4420.0, 'w': 45.0, 'h': 28.0}, // Serra dos Órgãos / Dedo de Deus
      {'wx': 7900.0, 'wy': 4320.0, 'w': 40.0, 'h': 25.0},
    ];

    for (final rock in rockClusters) {
      final wx = rock['wx'] as double;
      final wy = rock['wy'] as double;
      final w = (rock['w'] as double) * zoom;
      final h = (rock['h'] as double) * zoom;

      if (!visibleBounds.contains(WorldCoordinate(wx, wy))) continue;

      final pt = WorldCoordinate(wx, wy).toScreen(
        cameraX: camera.x,
        cameraY: camera.y,
        zoom: zoom,
        screenSize: size,
      );

      // 1. Sombra de Contato com o Solo (Ambient Occlusion a Sudeste)
      stoneShadowPaint.color = const Color(0xFF152216).withValues(alpha: 0.52);
      canvas.drawOval(
        Rect.fromCenter(center: pt + Offset(w * 0.22, h * 0.25), width: w * 1.35, height: h * 0.95),
        stoneShadowPaint,
      );

      // 2. Rocha Granítica Escura (Base mineral)
      stoneBasePaint.color = const Color(0xFF5D6B60);
      canvas.drawOval(
        Rect.fromCenter(center: pt, width: w, height: h),
        stoneBasePaint,
      );

      // 3. Faceta Iluminada a Noroeste pelo Sol Matinal
      stoneSunlitPaint.color = const Color(0xFF8A9A8C);
      canvas.drawOval(
        Rect.fromCenter(center: pt - Offset(w * 0.18, h * 0.18), width: w * 0.65, height: h * 0.55),
        stoneSunlitPaint,
      );
    }
  }

  void _paintBiomeRegions(
    Canvas canvas,
    Size size,
    CameraState camera,
    WorldBounds visibleBounds,
  ) {
    for (final biome in canonicalBiomes) {
      final margin = math.max(biome.radiusX, biome.radiusY);
      if (biome.center.x + margin < visibleBounds.minX ||
          biome.center.x - margin > visibleBounds.maxX ||
          biome.center.y + margin < visibleBounds.minY ||
          biome.center.y - margin > visibleBounds.maxY) {
        continue;
      }

      final screenCenter = biome.center.toScreen(
        cameraX: camera.x,
        cameraY: camera.y,
        zoom: camera.zoom,
        screenSize: size,
      );

      final rx = biome.radiusX * camera.zoom;
      final ry = biome.radiusY * camera.zoom;

      canvas.save();
      canvas.translate(screenCenter.dx, screenCenter.dy);
      canvas.rotate(biome.rotation);

      // Primary lush biome wash
      final primaryPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          rx,
          [
            biome.primaryColor.withValues(alpha: 0.85),
            biome.secondaryColor.withValues(alpha: 0.55),
            Colors.transparent,
          ],
          [0.0, 0.65, 1.0],
        );
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), primaryPaint);

      // Soil underlay showing through vegetation (terra roxa / húmus)
      final soilPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          rx * 0.75,
          [
            biome.soilColor.withValues(alpha: 0.35),
            Colors.transparent,
          ],
          [0.0, 1.0],
        );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(rx * 0.08, ry * 0.05), width: rx * 1.5, height: ry * 1.3),
        soilPaint,
      );

      canvas.restore();
    }
  }

  /// Renders soft rolling hills (Mares de Morros) across the highland plateau.
  void _paintRollingHills(
    Canvas canvas,
    Size size,
    CameraState camera,
    WorldBounds visibleBounds,
  ) {
    final zoom = camera.zoom;
    final hillPaint = Paint()..style = PaintingStyle.fill;
    final sunlitPaint = Paint()..style = PaintingStyle.fill;

    // Deterministic hill mounds across the Planalto de Piratininga & Vale do Paraíba
    const hillMounds = [
      {'coord': WorldCoordinate(4650, 4850), 'rx': 220.0, 'ry': 150.0, 'h': 65.0},
      {'coord': WorldCoordinate(4850, 5250), 'rx': 260.0, 'ry': 170.0, 'h': 75.0},
      {'coord': WorldCoordinate(5150, 4850), 'rx': 240.0, 'ry': 160.0, 'h': 70.0},
      {'coord': WorldCoordinate(5400, 5150), 'rx': 280.0, 'ry': 180.0, 'h': 85.0},
      {'coord': WorldCoordinate(6050, 4800), 'rx': 250.0, 'ry': 160.0, 'h': 80.0},
      {'coord': WorldCoordinate(6450, 4550), 'rx': 270.0, 'ry': 175.0, 'h': 90.0},
      {'coord': WorldCoordinate(6750, 4750), 'rx': 230.0, 'ry': 150.0, 'h': 70.0},
    ];

    for (final hill in hillMounds) {
      final coord = hill['coord'] as WorldCoordinate;
      final rx = (hill['rx'] as double) * zoom;
      final ry = (hill['ry'] as double) * zoom;

      if (!visibleBounds.contains(coord)) continue;

      final pt = coord.toScreen(
        cameraX: camera.x,
        cameraY: camera.y,
        zoom: zoom,
        screenSize: size,
      );

      // 1. Shaded Southeast Hill Slope
      hillPaint.color = const Color(0xFF274220).withValues(alpha: 0.38);
      canvas.drawOval(
        Rect.fromCenter(center: pt + Offset(rx * 0.18, ry * 0.18), width: rx * 1.8, height: ry * 1.6),
        hillPaint,
      );

      // 2. Warm Sunlit Northwest Crest
      sunlitPaint.color = const Color(0xFF658F4A).withValues(alpha: 0.45);
      canvas.drawOval(
        Rect.fromCenter(center: pt - Offset(rx * 0.15, ry * 0.15), width: rx * 1.3, height: ry * 1.1),
        sunlitPaint,
      );
    }
  }

  /// Renders mountain ridges and escarpments with authentic 3D hillshading.
  void _paintMountainRidges(
    Canvas canvas,
    Size size,
    CameraState camera,
    WorldBounds visibleBounds,
  ) {
    final zoom = camera.zoom;
    final sunDirection = const Offset(-0.707, -0.707); // Sunlight from Northwest
    final shadowDirection = const Offset(0.707, 0.707); // Shadow towards Southeast

    for (final ridge in canonicalRidges) {
      final pStart = ridge.start.toScreen(
        cameraX: camera.x,
        cameraY: camera.y,
        zoom: camera.zoom,
        screenSize: size,
      );
      final pCtrl = ridge.control.toScreen(
        cameraX: camera.x,
        cameraY: camera.y,
        zoom: camera.zoom,
        screenSize: size,
      );
      final pEnd = ridge.end.toScreen(
        cameraX: camera.x,
        cameraY: camera.y,
        zoom: camera.zoom,
        screenSize: size,
      );

      final w = (ridge.width * zoom).clamp(24.0, 240.0);

      // 1. Ridge Shadow Side (Southeast slope falls in shadow)
      final shadowPath = Path()
        ..moveTo(pStart.dx + shadowDirection.dx * (w * 0.45), pStart.dy + shadowDirection.dy * (w * 0.45))
        ..quadraticBezierTo(
          pCtrl.dx + shadowDirection.dx * (w * 0.45),
          pCtrl.dy + shadowDirection.dy * (w * 0.45),
          pEnd.dx + shadowDirection.dx * (w * 0.45),
          pEnd.dy + shadowDirection.dy * (w * 0.45),
        );

      final shadowPaint = Paint()
        ..color = const Color(0xFF142416).withValues(alpha: 0.55)
        ..strokeWidth = w * 0.85
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(shadowPath, shadowPaint);

      // 2. Main Mountain Bulk (Rocky granitic ridge)
      final mainPath = Path()
        ..moveTo(pStart.dx, pStart.dy)
        ..quadraticBezierTo(pCtrl.dx, pCtrl.dy, pEnd.dx, pEnd.dy);

      final mountainPaint = Paint()
        ..color = const Color(0xFF385732).withValues(alpha: 0.75)
        ..strokeWidth = w * 0.60
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(mainPath, mountainPaint);

      // 3. Sunlit Northwest Ridge Crest (Warm morning sun on rocks)
      final sunlitPath = Path()
        ..moveTo(pStart.dx + sunDirection.dx * (w * 0.22), pStart.dy + sunDirection.dy * (w * 0.22))
        ..quadraticBezierTo(
          pCtrl.dx + sunDirection.dx * (w * 0.22),
          pCtrl.dy + sunDirection.dy * (w * 0.22),
          pEnd.dx + sunDirection.dx * (w * 0.22),
          pEnd.dy + sunDirection.dy * (w * 0.22),
        );

      final sunlitPaint = Paint()
        ..color = const Color(0xFF75A062).withValues(alpha: 0.60)
        ..strokeWidth = w * 0.38
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(sunlitPath, sunlitPaint);

      // 4. Sharp Granite Ridge Spine (The high rocky divide)
      final spinePaint = Paint()
        ..color = const Color(0xFF8DAA78).withValues(alpha: 0.65)
        ..strokeWidth = (3.0 * zoom).clamp(1.5, 6.0)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(mainPath, spinePaint);
    }
  }
}

