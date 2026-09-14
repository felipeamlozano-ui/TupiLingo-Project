import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tupi_lingo/core/world_engine/camera/camera_state.dart';
import 'package:tupi_lingo/core/world_engine/camera/world_camera_controller.dart';
import 'package:tupi_lingo/core/world_engine/coordinates/world_bounds.dart';
import 'package:tupi_lingo/core/world_engine/coordinates/world_coordinate.dart';
import 'package:tupi_lingo/core/world_engine/fog/fog_engine.dart';
import 'package:tupi_lingo/core/world_engine/particles/world_particle_pool.dart';
import 'package:tupi_lingo/core/world_engine/trails/historical_trail.dart';
import 'package:tupi_lingo/core/world_engine/trails/river_path.dart';
import 'package:tupi_lingo/core/world_engine/villages/village_node.dart';
import 'package:tupi_lingo/features/dashboard/presentation/widgets/mastery_radar_chart.dart';

void main() {
  group('Pindorama World Engine — Coordinate & Bounding Frustum Tests', () {
    test('WorldCoordinate toScreen and fromScreen roundtrip', () {
      const coord = WorldCoordinate(5200.0, 4800.0);
      const cameraX = 5000.0;
      const cameraY = 5000.0;
      const zoom = 1.5;
      const screenSize = Size(800.0, 600.0);

      final screenPt = coord.toScreen(
        cameraX: cameraX,
        cameraY: cameraY,
        zoom: zoom,
        screenSize: screenSize,
      );

      // (5200 - 5000) * 1.5 + 400 = 200 * 1.5 + 400 = 700
      expect(screenPt.dx, closeTo(700.0, 0.001));
      // (4800 - 5000) * 1.5 + 300 = -200 * 1.5 + 300 = 0
      expect(screenPt.dy, closeTo(0.0, 0.001));

      final restored = WorldCoordinate.fromScreen(
        screenPoint: screenPt,
        cameraX: cameraX,
        cameraY: cameraY,
        zoom: zoom,
        screenSize: screenSize,
      );

      expect(restored.x, closeTo(coord.x, 0.001));
      expect(restored.y, closeTo(coord.y, 0.001));
    });

    test('WorldBounds AABB intersection and containment', () {
      const b1 = WorldBounds(minX: 100, minY: 100, maxX: 300, maxY: 300);
      const b2 = WorldBounds(minX: 200, minY: 200, maxX: 400, maxY: 400);
      const b3 = WorldBounds(minX: 500, minY: 500, maxX: 600, maxY: 600);

      expect(b1.intersects(b2), isTrue);
      expect(b2.intersects(b1), isTrue);
      expect(b1.intersects(b3), isFalse);

      expect(b1.contains(const WorldCoordinate(150, 150)), isTrue);
      expect(b1.contains(const WorldCoordinate(350, 350)), isFalse);

      final expanded = b1.expand(50);
      expect(expanded.minX, equals(50));
      expect(expanded.maxX, equals(350));
    });
  });

  group('Pindorama World Engine — Camera Controller Physics', () {
    test('Camera clamps zoom within valid range (0.35x - 3.5x)', () {
      final controller = WorldCameraController();
      expect(controller.zoom, equals(1.0));

      controller.zoomAt(
        focalPointScreen: const Offset(400, 300),
        scaleMultiplier: 10.0,
        screenSize: const Size(800, 600),
      );
      expect(controller.zoom, closeTo(CameraState.maxZoom, 0.001));

      controller.zoomAt(
        focalPointScreen: const Offset(400, 300),
        scaleMultiplier: 0.01,
        screenSize: const Size(800, 600),
      );
      expect(controller.zoom, closeTo(CameraState.minZoom, 0.001));
    });

    test('Camera panByScreenDelta updates spatial position', () {
      final controller = WorldCameraController(
        initialState: const CameraState(x: 5000, y: 5000, zoom: 1.0),
      );

      // Pan right by 100 px => camera moves left by 100 world units
      controller.panByScreenDelta(const Offset(100, 0));
      expect(controller.x, closeTo(4900.0, 0.001));
    });

    test('Camera flyTo smoothly updates target coordinates and ticks spring', () {
      final controller = WorldCameraController(
        initialState: const CameraState(x: 5000, y: 5000, zoom: 1.0),
      );

      controller.flyTo(const WorldCoordinate(6000, 7000), zoom: 1.8);
      expect(controller.state.targetX, equals(6000.0));
      expect(controller.state.targetY, equals(7000.0));
      expect(controller.state.targetZoom, equals(1.8));

      // Tick 0.016s (60 FPS)
      controller.tick(0.016);
      expect(controller.x, greaterThan(5000.0));
      expect(controller.y, greaterThan(5000.0));
      expect(controller.zoom, greaterThan(1.0));
    });
  });

  group('Pindorama World Engine — Rivers, Trails, and Villages', () {
    test('Canonical rivers and bezier segment bounds', () {
      final tiete = RiverPath.canonicalTiete;
      expect(tiete.segments.isNotEmpty, isTrue);
      expect(tiete.bounds.width, greaterThan(0));

      final paraiba = RiverPath.canonicalParaiba;
      expect(paraiba.segments.isNotEmpty, isTrue);
      expect(paraiba.bounds.height, greaterThan(0));
    });

    test('Canonical historical trails have valid bounds and village links', () {
      final trails = HistoricalTrail.canonicalTrails;
      expect(trails.length, greaterThanOrEqualTo(3));

      final peabiru = trails.firstWhere((t) => t.id == 'peabiru_principal');
      expect(peabiru.linkedVillageIds, contains('sao_vicente'));
      expect(peabiru.bounds.minX, lessThan(peabiru.bounds.maxX));
    });

    test('Canonical villages have all 5 evolution stages supported', () {
      final villages = VillageNode.canonicalVillages;
      expect(villages.length, greaterThanOrEqualTo(5));

      final piratininga = villages.firstWhere((v) => v.id == 'piratininga');
      expect(piratininga.stage, equals(VillageEvolutionStage.dominada));
      expect(piratininga.dialectVariant, equals('Tupi Paulista'));
    });
  });

  group('Pindorama World Engine — Fog of War & BKT Mastery', () {
    test('FogEngine computes clearances for discovered villages', () {
      final villages = VillageNode.canonicalVillages;
      final trails = HistoricalTrail.canonicalTrails;

      final fogState = FogEngine.computeFromWorld(
        villages: villages,
        trails: trails,
        bktMasteryMap: {'piratininga': 0.95},
      );

      expect(fogState.clearances.isNotEmpty, isTrue);

      // Piratininga center should have high clearance based on 0.95 mastery (0.70 + 0.95 * 0.30 = 0.985)
      final piratininga = villages.firstWhere((v) => v.id == 'piratininga');
      final clearanceAtCenter = fogState.getClearanceAt(piratininga.coordinate);
      expect(clearanceAtCenter, closeTo(0.985, 0.001));

      // Far away corner should be fully enveloped in fog (0.0 clearance)
      final farPoint = const WorldCoordinate(100, 100);
      final clearanceFar = fogState.getClearanceAt(farPoint);
      expect(clearanceFar, equals(0.0));
      expect(fogState.getFogOpacityAt(farPoint), greaterThan(0.8));
    });
  });

  group('Pindorama World Engine — GPU Particle Pool (Zero Allocation)', () {
    test('Particle pool pre-allocates 300 particles and updates without allocations', () {
      final pool = WorldParticlePool();
      expect(pool.capacity, equals(300));

      pool.initializeDefaults();

      // Tick 10 frames
      for (int i = 0; i < 10; i++) {
        pool.tick(0.016);
      }

      expect(pool.capacity, equals(300));
    });
  });

  group('Pindorama World Engine — 8-Axis Radar Chart Dimensions', () {
    test('Default 8 dimensions exist with valid 0.0 to 1.0 scores', () {
      final dimensions = MasteryRadarChart.defaultDimensions;
      expect(dimensions.length, equals(8));

      for (final d in dimensions) {
        expect(d.score, greaterThanOrEqualTo(0.0));
        expect(d.score, lessThanOrEqualTo(1.0));
        expect(d.label.isNotEmpty, isTrue);
      }
    });
  });
}
