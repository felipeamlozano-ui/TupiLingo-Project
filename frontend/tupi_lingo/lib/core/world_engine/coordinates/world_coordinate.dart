import 'dart:math';
import 'package:flutter/material.dart';

/// Represents a continuous 2D coordinate in the Pindorama World Engine (RFC-012C Chapter 1).
/// Global coordinate space spans [0.0, 10000.0] x [0.0, 10000.0] normalized world units.
@immutable
class WorldCoordinate {
  final double wx;
  final double wy;

  const WorldCoordinate(this.wx, this.wy);
  const WorldCoordinate.xy({required double x, required double y})
      : wx = x,
        wy = y;

  double get x => wx;
  double get y => wy;

  static const WorldCoordinate zero = WorldCoordinate(0.0, 0.0);
  static const WorldCoordinate center = WorldCoordinate(5000.0, 5000.0);

  /// Converts this world coordinate into screen pixel coordinates.
  /// Supports both standard camera parameters (cameraX, cameraY, zoom, screenSize)
  /// and raw Matrix4 transformations.
  Offset toScreen({
    double? cameraX,
    double? cameraY,
    double? zoom,
    required Size screenSize,
    Matrix4? cameraTransform,
  }) {
    if (cameraTransform != null) {
      final screenCenter = Offset(screenSize.width / 2.0, screenSize.height / 2.0);
      final s = cameraTransform.storage;
      final x = s[0] * wx + s[4] * wy + s[12];
      final y = s[1] * wx + s[5] * wy + s[13];
      return Offset(x + screenCenter.dx, y + screenCenter.dy);
    }

    final cX = cameraX ?? 5000.0;
    final cY = cameraY ?? 5000.0;
    final z = zoom ?? 1.0;

    return Offset(
      (wx - cX) * z + (screenSize.width / 2.0),
      (wy - cY) * z + (screenSize.height / 2.0),
    );
  }

  /// Converts a screen pixel coordinate back into world coordinates.
  static WorldCoordinate fromScreen({
    required Offset screenPoint,
    double? cameraX,
    double? cameraY,
    double? zoom,
    required Size screenSize,
    Matrix4? cameraTransform,
  }) {
    if (cameraTransform != null) {
      final screenCenter = Offset(screenSize.width / 2.0, screenSize.height / 2.0);
      final relX = screenPoint.dx - screenCenter.dx;
      final relY = screenPoint.dy - screenCenter.dy;

      final invertedMatrix = Matrix4.inverted(cameraTransform);
      final s = invertedMatrix.storage;
      final x = s[0] * relX + s[4] * relY + s[12];
      final y = s[1] * relX + s[5] * relY + s[13];
      return WorldCoordinate(x, y);
    }

    final cX = cameraX ?? 5000.0;
    final cY = cameraY ?? 5000.0;
    final z = zoom ?? 1.0;

    return WorldCoordinate(
      (screenPoint.dx - screenSize.width / 2.0) / z + cX,
      (screenPoint.dy - screenSize.height / 2.0) / z + cY,
    );
  }

  /// Euclidean distance to [other] in world units.
  double distanceTo(WorldCoordinate other) {
    final dx = wx - other.wx;
    final dy = wy - other.wy;
    return sqrt(dx * dx + dy * dy);
  }

  /// Linearly interpolates between this coordinate and [other] by fraction [t].
  WorldCoordinate lerp(WorldCoordinate other, double t) {
    return WorldCoordinate(
      wx + (other.wx - wx) * t,
      wy + (other.wy - wy) * t,
    );
  }

  WorldCoordinate operator +(Offset offset) => WorldCoordinate(wx + offset.dx, wy + offset.dy);
  WorldCoordinate operator -(Offset offset) => WorldCoordinate(wx - offset.dx, wy - offset.dy);

  Offset toOffset() => Offset(wx, wy);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorldCoordinate && runtimeType == other.runtimeType && wx == other.wx && wy == other.wy;

  @override
  int get hashCode => Object.hash(wx, wy);

  @override
  String toString() => 'WorldCoordinate(${wx.toStringAsFixed(1)}, ${wy.toStringAsFixed(1)})';
}
