import 'package:flutter/material.dart';

/// CameraNode manages the 2D viewport, camera zoom, pan, and visible frustum.
class CameraNode {
  Offset center;
  double zoom;
  Size viewportSize;

  CameraNode({
    this.center = Offset.zero,
    this.zoom = 1.0,
    this.viewportSize = const Size(800, 600),
  });

  /// The visible world rectangle bounded by the current camera viewport and zoom.
  Rect get visibleFrustum {
    final effectiveWidth = viewportSize.width / zoom;
    final effectiveHeight = viewportSize.height / zoom;
    return Rect.fromCenter(
      center: center,
      width: effectiveWidth,
      height: effectiveHeight,
    );
  }

  void pan(Offset delta) {
    center += delta / zoom;
  }

  void setZoom(double newZoom, {Offset? focalPoint}) {
    zoom = newZoom.clamp(0.2, 5.0);
  }

  /// Converts a screen/viewport coordinate to world space.
  Offset screenToWorld(Offset screenPoint) {
    final dx = (screenPoint.dx - viewportSize.width / 2) / zoom + center.dx;
    final dy = (screenPoint.dy - viewportSize.height / 2) / zoom + center.dy;
    return Offset(dx, dy);
  }

  /// Converts a world coordinate to screen/viewport space.
  Offset worldToScreen(Offset worldPoint) {
    final dx = (worldPoint.dx - center.dx) * zoom + viewportSize.width / 2;
    final dy = (worldPoint.dy - center.dy) * zoom + viewportSize.height / 2;
    return Offset(dx, dy);
  }

  /// Applies camera transform to canvas.
  void apply(Canvas canvas) {
    canvas.translate(viewportSize.width / 2, viewportSize.height / 2);
    canvas.scale(zoom);
    canvas.translate(-center.dx, -center.dy);
  }
}
