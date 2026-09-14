import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/world_engine/coordinates/world_coordinate.dart';

/// Axis-Aligned Bounding Box (AABB) in world coordinates for spatial queries and culling.
@immutable
class WorldBounds {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const WorldBounds({
    double? left,
    double? top,
    double? right,
    double? bottom,
    double? minX,
    double? minY,
    double? maxX,
    double? maxY,
  })  : left = left ?? minX ?? 0.0,
        top = top ?? minY ?? 0.0,
        right = right ?? maxX ?? 0.0,
        bottom = bottom ?? maxY ?? 0.0;

  double get minX => left;
  double get minY => top;
  double get maxX => right;
  double get maxY => bottom;

  /// Creates a bounding box covering the entire Pindorama world continent.
  static const WorldBounds entireWorld = WorldBounds(
    left: 0.0,
    top: 0.0,
    right: 10000.0,
    bottom: 10000.0,
  );

  /// Factory creating bounds from a center coordinate and uniform radius.
  factory WorldBounds.fromCenterRadius(WorldCoordinate center, double radius) {
    return WorldBounds(
      left: center.wx - radius,
      top: center.wy - radius,
      right: center.wx + radius,
      bottom: center.wy + radius,
    );
  }

  /// Factory from LTWH (Left, Top, Width, Height).
  factory WorldBounds.fromLTWH(double left, double top, double width, double height) {
    return WorldBounds(
      left: left,
      top: top,
      right: left + width,
      bottom: top + height,
    );
  }

  double get width => right - left;
  double get height => bottom - top;

  WorldCoordinate get center => WorldCoordinate((left + right) / 2.0, (top + bottom) / 2.0);

  /// Checks if [coord] is inside this bounding box.
  bool contains(WorldCoordinate coord) {
    return coord.wx >= left && coord.wx <= right && coord.wy >= top && coord.wy <= bottom;
  }

  /// Checks if this bounding box overlaps with [other].
  bool intersects(WorldBounds other) {
    return !(left > other.right || right < other.left || top > other.bottom || bottom < other.top);
  }

  /// Expands bounds outward by [margin] world units.
  WorldBounds expanded(double margin) {
    return WorldBounds(
      left: left - margin,
      top: top - margin,
      right: right + margin,
      bottom: bottom + margin,
    );
  }

  /// Alias for expanded.
  WorldBounds expand(double margin) => expanded(margin);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorldBounds &&
          runtimeType == other.runtimeType &&
          left == other.left &&
          top == other.top &&
          right == other.right &&
          bottom == other.bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() =>
      'WorldBounds(L: ${left.toStringAsFixed(1)}, T: ${top.toStringAsFixed(1)}, R: ${right.toStringAsFixed(1)}, B: ${bottom.toStringAsFixed(1)})';
}
