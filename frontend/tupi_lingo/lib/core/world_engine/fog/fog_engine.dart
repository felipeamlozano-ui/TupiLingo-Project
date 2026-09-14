import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../camera/camera_state.dart';
import '../trails/historical_trail.dart';
import '../villages/village_node.dart';
import 'fog_state.dart';

/// Computes and renders the dynamic Fog of War across Pindorama.
class FogEngine {
  /// Computes the active [FogState] given the known villages and discovered trails.
  static FogState computeFromWorld({
    required List<VillageNode> villages,
    required List<HistoricalTrail> trails,
    Map<String, double>? bktMasteryMap,
  }) {
    final clearances = <FogClearanceCircle>[];

    // 1. Village Clearances
    for (final village in villages) {
      if (village.stage == VillageEvolutionStage.oculta) {
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

      // Base radius varies by evolution stage and mastery
      final baseRadius = switch (village.stage) {
        VillageEvolutionStage.descoberta => 300.0,
        VillageEvolutionStage.explorada => 550.0,
        VillageEvolutionStage.dominada => 800.0,
        VillageEvolutionStage.historica => 1100.0,
        VillageEvolutionStage.oculta => 0.0,
      };

      final effectiveRadius = baseRadius + (mastery * 200.0);

      clearances.add(
        FogClearanceCircle(
          center: village.coordinate,
          radius: effectiveRadius,
          featherRadius: 160.0 + (mastery * 80.0),
          clearanceFactor: 0.70 + (mastery * 0.30),
        ),
      );
    }

    // 2. Discovered Trail Clearances (creates revealed corridors through the jungle)
    for (final trail in trails) {
      if (!trail.isDiscovered || trail.points.isEmpty) continue;

      for (final pt in trail.points) {
        clearances.add(
          FogClearanceCircle(
            center: pt,
            radius: 140.0,
            featherRadius: 90.0,
            clearanceFactor: 0.65,
          ),
        );
      }
    }

    return FogState(clearances: clearances);
  }

  /// Renders the Fog of War onto a [Canvas] with soft feathered boundaries
  /// for all cleared village and trail areas.
  static void renderFog({
    required Canvas canvas,
    required Size size,
    required CameraState camera,
    required FogState fogState,
    ui.FragmentShader? shader,
    double time = 0.0,
  }) {
    if (size.isEmpty) return;

    // Filter clearances that intersect the visible viewport
    final visibleBounds = camera.getVisibleBounds(size);
    final visibleClearances = fogState.clearances.where((c) {
      final margin = c.radius + c.featherRadius;
      return c.center.x >= visibleBounds.minX - margin &&
          c.center.x <= visibleBounds.maxX + margin &&
          c.center.y >= visibleBounds.minY - margin &&
          c.center.y <= visibleBounds.maxY + margin;
    }).toList();

    // 1. Save canvas layer for composite blending
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // 2. Fill the entire screen with the fog color
    final fogPaint = Paint();
    if (shader != null) {
      shader.setFloat(0, size.width);
      shader.setFloat(1, size.height);
      shader.setFloat(2, time);
      shader.setFloat(3, fogState.fogColor.r);
      shader.setFloat(4, fogState.fogColor.g);
      shader.setFloat(5, fogState.fogColor.b);
      shader.setFloat(6, fogState.fogColor.a);
      shader.setFloat(7, 0.0035);
      fogPaint.shader = shader;
    } else {
      fogPaint.color = fogState.fogColor;
    }

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), fogPaint);

    // 3. Clear revealed circles using BlendMode.dstOut with radial gradient feathers
    final clearPaint = Paint()..blendMode = BlendMode.dstOut;

    for (final clearance in visibleClearances) {
      final screenCenter = clearance.center.toScreen(
        cameraX: camera.x,
        cameraY: camera.y,
        zoom: camera.zoom,
        screenSize: size,
      );

      final screenInnerRadius = clearance.radius * camera.zoom;
      final screenOuterRadius =
          (clearance.radius + clearance.featherRadius) * camera.zoom;

      if (screenOuterRadius <= 0) continue;

      clearPaint.shader = ui.Gradient.radial(
        screenCenter,
        screenOuterRadius,
        [
          Colors.black.withValues(alpha: clearance.clearanceFactor.clamp(0.0, 1.0)),
          Colors.black.withValues(alpha: clearance.clearanceFactor.clamp(0.0, 1.0)),
          Colors.transparent,
        ],
        [
          0.0,
          (screenInnerRadius / screenOuterRadius).clamp(0.0, 0.99),
          1.0,
        ],
      );

      canvas.drawCircle(screenCenter, screenOuterRadius, clearPaint);
    }

    // 4. Restore composite layer
    canvas.restore();
  }
}
