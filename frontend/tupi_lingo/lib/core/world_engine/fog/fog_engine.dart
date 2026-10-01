import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../camera/camera_state.dart';
import '../trails/historical_trail.dart';
import '../villages/village_node.dart';
import 'fog_state.dart';
import 'world_discovery_engine.dart';

/// Computes and renders the dynamic Fog of War across Pindorama (Section 4, 5, 7 & 11).
class FogEngine {
  /// Computes the active [FogState] given the known villages and discovered trails.
  static FogState computeFromWorld({
    required List<VillageNode> villages,
    required List<HistoricalTrail> trails,
    Map<String, double>? bktMasteryMap,
    Color? fogColor,
  }) {
    // 0. Synchronize with high-performance persistent chunk discovery grid
    WorldDiscoveryEngine.instance.synchronizeProgression(
      villages: villages,
      trails: trails,
      bktMasteryMap: bktMasteryMap,
    );

    final organicClearances = <OrganicFogClearance>[];
    final circularClearances = <FogClearanceCircle>[];

    // 1. Village Clearances (Settlement Hulls)
    for (final village in villages) {
      final isCurrentActive = village.status == VillageStatus.current ||
          village.stage == VillageEvolutionStage.descoberta ||
          village.stage == VillageEvolutionStage.explorada;

      final isDiscovered = village.isDiscovered ||
          WorldDiscoveryEngine.instance.isVillageDiscovered(village.id) ||
          isCurrentActive ||
          village.stage != VillageEvolutionStage.oculta;

      if ((!village.isUnlocked && !isCurrentActive) ||
          (!isDiscovered && !isCurrentActive) ||
          (village.stage == VillageEvolutionStage.oculta && !isCurrentActive)) {
        if (village.isFrontier) {
          // Subtle organic clearing on the edge of the fog for the next frontier target
          organicClearances.add(
            OrganicFogClearance(
              center: village.coordinate,
              radius: 180.0,
              featherRadius: 180.0,
              clearanceFactor: 0.55,
              state: DiscoveryState.revealed,
              seed: village.id.hashCode,
            ),
          );
          circularClearances.add(
            FogClearanceCircle(
              center: village.coordinate,
              radius: 120.0,
              featherRadius: 140.0,
              clearanceFactor: 0.55,
            ),
          );
        }
        continue; // Still completely enveloped in fog
      }

      final mastery = bktMasteryMap?[village.id] ??
          (village.stage == VillageEvolutionStage.historica
              ? 1.0
              : village.stage == VillageEvolutionStage.dominada
                  ? 0.85
                  : village.stage == VillageEvolutionStage.explorada
                      ? 0.60
                      : 0.35);

      final isCurrentlyActive = isCurrentActive &&
          village.stage != VillageEvolutionStage.historica &&
          village.stage != VillageEvolutionStage.dominada &&
          village.status != VillageStatus.completed;

      // Base radius varies by evolution stage and mastery
      final baseRadius = switch (village.stage) {
        VillageEvolutionStage.descoberta => 720.0,
        VillageEvolutionStage.explorada => 780.0,
        VillageEvolutionStage.dominada => 880.0,
        VillageEvolutionStage.historica => 1150.0,
        VillageEvolutionStage.oculta => isCurrentActive ? 720.0 : 0.0,
      };

      final effectiveRadius = baseRadius + (mastery * 220.0);
      final featherRadius = 180.0 + (mastery * 80.0);
      final factor = 0.70 + (mastery * 0.30);

      organicClearances.add(
        OrganicFogClearance(
          center: village.coordinate,
          radius: effectiveRadius,
          featherRadius: featherRadius,
          clearanceFactor: factor,
          state: isCurrentlyActive ? DiscoveryState.currentlyVisible : DiscoveryState.revealed,
          seed: village.id.hashCode,
        ),
      );

      circularClearances.add(
        FogClearanceCircle(
          center: village.coordinate,
          radius: effectiveRadius,
          featherRadius: featherRadius,
          clearanceFactor: factor,
        ),
      );
    }

    // 2. Discovered Trail Clearances (creates organic revealed corridors through the jungle)
    for (final trail in trails) {
      if (!trail.isDiscovered || trail.points.isEmpty) continue;

      for (int i = 0; i < trail.points.length; i++) {
        final pt = trail.points[i];
        organicClearances.add(
          OrganicFogClearance(
            center: pt,
            radius: 160.0,
            featherRadius: 130.0,
            clearanceFactor: 0.70,
            state: DiscoveryState.revealed,
            seed: trail.id.hashCode + i,
          ),
        );
        circularClearances.add(
          FogClearanceCircle(
            center: pt,
            radius: 140.0,
            featherRadius: 90.0,
            clearanceFactor: 0.65,
          ),
        );
      }
    }

    return FogState(
      organicClearances: organicClearances,
      clearances: circularClearances,
      fogColor: fogColor ?? const Color(0x35142820),
      fogDensity: 0.85,
    );
  }

  /// Renders the Fog of War onto a [Canvas] with soft feathered organic boundaries
  /// for all cleared village and trail areas (Section 5, 7, 9 & 22).
  ///
  /// Zero-allocation direct path clipping eliminates canvas.saveLayer overhead,
  /// preventing emulator crashes and avoiding Skia composite blend bugs.
  static void renderFog({
    required Canvas canvas,
    required Size size,
    required CameraState camera,
    required FogState fogState,
    ui.FragmentShader? shader,
    double time = 0.0,
  }) {
    if (size.isEmpty) return;

    final visibleBounds = camera.getVisibleBounds(size);
    final screenRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // 1. Filter clearances that intersect the visible bounds
    final visibleOrganic = fogState.organicClearances.where((c) {
      final margin = c.radius + c.featherRadius;
      return c.center.x >= visibleBounds.minX - margin &&
          c.center.x <= visibleBounds.maxX + margin &&
          c.center.y >= visibleBounds.minY - margin &&
          c.center.y <= visibleBounds.maxY + margin;
    }).toList();

    // 2. Build composite holes path from visible clear zones
    final holesPath = Path();
    for (final clearance in visibleOrganic) {
      final path = clearance.toScreenPath(
        cameraX: camera.x,
        cameraY: camera.y,
        zoom: camera.zoom,
        screenSize: size,
        extraRadius: 0.0,
      );
      holesPath.addPath(path, Offset.zero);
    }

    // Backwards-compatible radial circles fallback if organic is empty
    if (visibleOrganic.isEmpty && fogState.clearances.isNotEmpty) {
      for (final c in fogState.clearances) {
        final screenCenter = c.center.toScreen(
          cameraX: camera.x,
          cameraY: camera.y,
          zoom: camera.zoom,
          screenSize: size,
        );
        final r = c.radius * camera.zoom;
        if (r > 0) {
          holesPath.addOval(Rect.fromCircle(center: screenCenter, radius: r));
        }
      }
    }

    // 3. Subtract holes from screen rect: zero saveLayer, zero offscreen memory
    final fogPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(screenRect),
      holesPath,
    );

    // 4. Fill shrouded mist area with soft atmospheric tint (alpha <= 0.28)
    final effectiveColor = fogState.fogColor.withValues(
      alpha: fogState.fogColor.a.clamp(0.0, 0.28),
    );

    final fogPaint = Paint()..style = PaintingStyle.fill;
    if (shader != null) {
      shader.setFloat(0, size.width);
      shader.setFloat(1, size.height);
      shader.setFloat(2, time);
      shader.setFloat(3, effectiveColor.r);
      shader.setFloat(4, effectiveColor.g);
      shader.setFloat(5, effectiveColor.b);
      shader.setFloat(6, effectiveColor.a);
      shader.setFloat(7, 0.0035);
      fogPaint.shader = shader;
    } else {
      fogPaint.color = effectiveColor;
    }

    canvas.drawPath(fogPath, fogPaint);

    // 5. Draw smooth radial gradient vignettes at clearance perimeters (zero saveLayer)
    final vignettePaint = Paint()..style = PaintingStyle.fill;
    for (final clearance in visibleOrganic) {
      final screenCenter = clearance.center.toScreen(
        cameraX: camera.x,
        cameraY: camera.y,
        zoom: camera.zoom,
        screenSize: size,
      );
      final innerR = clearance.radius * camera.zoom;
      final outerR = (clearance.radius + clearance.featherRadius * 0.75) * camera.zoom;
      if (outerR <= innerR || outerR <= 0) continue;

      vignettePaint.shader = ui.Gradient.radial(
        screenCenter,
        outerR,
        [
          Colors.transparent,
          Colors.transparent,
          effectiveColor.withValues(alpha: effectiveColor.a * 0.4),
          effectiveColor,
        ],
        [
          0.0,
          (innerR / outerR).clamp(0.0, 0.85),
          (innerR / outerR + (1.0 - innerR / outerR) * 0.5).clamp(0.0, 0.95),
          1.0,
        ],
      );
      canvas.drawCircle(screenCenter, outerR, vignettePaint);
    }
  }
}

