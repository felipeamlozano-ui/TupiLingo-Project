import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../coordinates/world_coordinate.dart';
import 'world_discovery_engine.dart';

/// Represents an organic, non-circular clearance zone within the Fog of War (Section 5 & 7).
class OrganicFogClearance {
  final WorldCoordinate center;
  final double radius;
  final double featherRadius;
  final double clearanceFactor; // 0.0 = fully fogged, 0.65 = revealed, 1.0 = crystal clear
  final DiscoveryState state;
  final int seed;

  const OrganicFogClearance({
    required this.center,
    required this.radius,
    this.featherRadius = 140.0,
    this.clearanceFactor = 1.0,
    this.state = DiscoveryState.currentlyVisible,
    this.seed = 42,
  });

  /// Builds a wavy, natural organic polygon path around the center (eliminating circular contours).
  Path toScreenPath({
    required double cameraX,
    required double cameraY,
    required double zoom,
    required Size screenSize,
    double extraRadius = 0.0,
  }) {
    final screenCenter = center.toScreen(
      cameraX: cameraX,
      cameraY: cameraY,
      zoom: zoom,
      screenSize: screenSize,
    );

    final path = Path();
    const pointCount = 16;
    final r = (radius + extraRadius) * zoom;

    for (int i = 0; i <= pointCount; i++) {
      final theta = (i % pointCount) * (2 * math.pi / pointCount);
      // Multi-frequency procedural noise displacement for an organic boundary
      final noise = 1.0 +
          0.16 * math.sin(theta * 3.0 + seed * 0.1) +
          0.10 * math.cos(theta * 5.0 + seed * 0.2);
      final pr = r * noise;
      final px = screenCenter.dx + math.cos(theta) * pr;
      final py = screenCenter.dy + math.sin(theta) * (pr * 0.88); // slight 2.5D compression

      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    return path;
  }

  /// Evaluates clearance (0.0 to 1.0) at a specific world coordinate.
  double clearanceAt(WorldCoordinate point) {
    final dist = center.distanceTo(point);
    if (dist <= radius) {
      return clearanceFactor;
    } else if (dist < radius + featherRadius) {
      final t = (dist - radius) / featherRadius;
      final smooth = 1.0 - (t * t * (3.0 - 2.0 * t));
      return smooth * clearanceFactor;
    }
    return 0.0;
  }
}

/// Backwards-compatible circular clearance interface.
class FogClearanceCircle {
  final WorldCoordinate center;
  final double radius;
  final double featherRadius;
  final double clearanceFactor;

  const FogClearanceCircle({
    required this.center,
    required this.radius,
    this.featherRadius = 120.0,
    this.clearanceFactor = 1.0,
  });

  double clearanceAt(WorldCoordinate point) {
    final dist = center.distanceTo(point);
    if (dist <= radius) {
      return clearanceFactor;
    } else if (dist < radius + featherRadius) {
      final t = (dist - radius) / featherRadius;
      final smooth = 1.0 - (t * t * (3.0 - 2.0 * t));
      return smooth * clearanceFactor;
    }
    return 0.0;
  }
}

/// Immutable state of the Fog of War across Pindorama (Section 4 & 11).
class FogState {
  final List<OrganicFogClearance> organicClearances;
  final List<FogClearanceCircle> clearances;
  final Color fogColor;
  final double fogDensity;

  const FogState({
    this.organicClearances = const [],
    this.clearances = const [],
    this.fogColor = const Color(0x35142820), // Natural atmospheric mountain mist
    this.fogDensity = 0.85,
  });

  double getClearanceAt(WorldCoordinate point) {
    double maxClearance = 0.0;
    for (final c in organicClearances) {
      final cl = c.clearanceAt(point);
      if (cl > maxClearance) maxClearance = cl;
    }
    for (final c in clearances) {
      final cl = c.clearanceAt(point);
      if (cl > maxClearance) maxClearance = cl;
    }
    return maxClearance.clamp(0.0, 1.0);
  }

  double getFogOpacityAt(WorldCoordinate point) {
    final clearance = getClearanceAt(point);
    return math.max(0.0, fogDensity * (1.0 - clearance));
  }

  FogState copyWith({
    List<OrganicFogClearance>? organicClearances,
    List<FogClearanceCircle>? clearances,
    Color? fogColor,
    double? fogDensity,
  }) {
    return FogState(
      organicClearances: organicClearances ?? this.organicClearances,
      clearances: clearances ?? this.clearances,
      fogColor: fogColor ?? this.fogColor,
      fogDensity: fogDensity ?? this.fogDensity,
    );
  }
}
