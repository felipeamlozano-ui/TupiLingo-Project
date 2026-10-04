import 'package:flutter/material.dart';
import '../coordinates/world_bounds.dart';
import '../coordinates/world_coordinate.dart';

/// Immutable representation of the world camera's spatial state.
class CameraState {
  final double x;
  final double y;
  final double zoom;
  final double targetX;
  final double targetY;
  final double targetZoom;
  final double velocityX;
  final double velocityY;
  final bool isInteracting;

  static const double minZoom = 0.35;
  static const double maxZoom = 3.50;
  static const double worldSize = 10000.0;

  const CameraState({
    this.x = 5000.0,
    this.y = 5000.0,
    this.zoom = 1.0,
    this.targetX = 5000.0,
    this.targetY = 5000.0,
    this.targetZoom = 1.0,
    this.velocityX = 0.0,
    this.velocityY = 0.0,
    this.isInteracting = false,
  });

  CameraState copyWith({
    double? x,
    double? y,
    double? zoom,
    double? targetX,
    double? targetY,
    double? targetZoom,
    double? velocityX,
    double? velocityY,
    bool? isInteracting,
  }) {
    return CameraState(
      x: x ?? this.x,
      y: y ?? this.y,
      zoom: zoom ?? this.zoom,
      targetX: targetX ?? this.targetX,
      targetY: targetY ?? this.targetY,
      targetZoom: targetZoom ?? this.targetZoom,
      velocityX: velocityX ?? this.velocityX,
      velocityY: velocityY ?? this.velocityY,
      isInteracting: isInteracting ?? this.isInteracting,
    );
  }

  /// Calculates the visible [WorldBounds] corresponding to the given screen size.
  WorldBounds getVisibleBounds(Size screenSize) {
    if (screenSize.isEmpty || zoom <= 0) {
      return const WorldBounds(minX: 0, minY: 0, maxX: worldSize, maxY: worldSize);
    }

    final halfWidth = (screenSize.width / 2.0) / zoom;
    final halfHeight = (screenSize.height / 2.0) / zoom;

    return WorldBounds(
      minX: (x - halfWidth).clamp(0.0, worldSize),
      minY: (y - halfHeight).clamp(0.0, worldSize),
      maxX: (x + halfWidth).clamp(0.0, worldSize),
      maxY: (y + halfHeight).clamp(0.0, worldSize),
    );
  }

  WorldCoordinate get position => WorldCoordinate(x, y);
  WorldCoordinate get targetPosition => WorldCoordinate(targetX, targetY);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CameraState &&
        other.x == x &&
        other.y == y &&
        other.zoom == zoom &&
        other.targetX == targetX &&
        other.targetY == targetY &&
        other.targetZoom == targetZoom &&
        other.velocityX == velocityX &&
        other.velocityY == velocityY &&
        other.isInteracting == isInteracting;
  }

  @override
  int get hashCode => Object.hash(
        x,
        y,
        zoom,
        targetX,
        targetY,
        targetZoom,
        velocityX,
        velocityY,
        isInteracting,
      );
}
