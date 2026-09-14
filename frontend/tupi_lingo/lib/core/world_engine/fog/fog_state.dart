import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../coordinates/world_coordinate.dart';

/// Represents a circular clearing within the Fog of War.
class FogClearanceCircle {
  final WorldCoordinate center;
  final double radius;
  final double featherRadius;
  final double clearanceFactor; // 0.0 = fully fogged, 1.0 = crystal clear

  const FogClearanceCircle({
    required this.center,
    required this.radius,
    this.featherRadius = 120.0,
    this.clearanceFactor = 1.0,
  });

  /// Evaluates the clearance (0.0 to 1.0) at a specific world coordinate.
  double clearanceAt(WorldCoordinate point) {
    final dist = center.distanceTo(point);
    if (dist <= radius) {
      return clearanceFactor;
    } else if (dist < radius + featherRadius) {
      final t = (dist - radius) / featherRadius;
      // Smooth Hermite interpolation (smoothstep)
      final smooth = 1.0 - (t * t * (3.0 - 2.0 * t));
      return smooth * clearanceFactor;
    }
    return 0.0;
  }
}

/// Immutable state of the Fog of War across Pindorama.
class FogState {
  final List<FogClearanceCircle> clearances;
  final Color fogColor;
  final double fogDensity;

  const FogState({
    this.clearances = const [],
    this.fogColor = const Color(0xEE121D28),
    this.fogDensity = 0.92,
  });

  /// Calculates total clearance at a given coordinate across all active clearings.
  double getClearanceAt(WorldCoordinate point) {
    double maxClearance = 0.0;
    for (final circle in clearances) {
      final c = circle.clearanceAt(point);
      if (c > maxClearance) {
        maxClearance = c;
        if (maxClearance >= 1.0) break;
      }
    }
    return maxClearance;
  }

  /// Evaluates fog opacity at a given coordinate.
  double getFogOpacityAt(WorldCoordinate point) {
    final clearance = getClearanceAt(point);
    return math.max(0.0, fogDensity * (1.0 - clearance));
  }

  FogState copyWith({
    List<FogClearanceCircle>? clearances,
    Color? fogColor,
    double? fogDensity,
  }) {
    return FogState(
      clearances: clearances ?? this.clearances,
      fogColor: fogColor ?? this.fogColor,
      fogDensity: fogDensity ?? this.fogDensity,
    );
  }
}
