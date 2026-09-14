import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../coordinates/world_coordinate.dart';
import 'camera_state.dart';

/// Smooth, physics-driven camera controller for Pindorama continuous world (RFC-012C Patch 1 Chapter 4).
///
/// Features:
/// - Critically damped spring physics for target transitions (flyTo).
/// - Exponential velocity decay inertia for pan flicks.
/// - Elastic rubber-band boundary overshoot with spring-back.
/// - Desktop mouse wheel and trackpad focal zoom.
/// - Adaptive gesture sensitivity for high-precision inspection.
class WorldCameraController extends ChangeNotifier {
  CameraState _state;

  // Spring & inertia parameters
  static const double friction = 0.92;
  static const double springStiffness = 12.0;
  static const double zoomSpringStiffness = 14.0;
  static const double boundarySpringStiffness = 18.0;
  static const double stopThreshold = 0.05;
  static const double maxOvershoot = 350.0;

  WorldCameraController({CameraState? initialState})
      : _state = initialState ?? const CameraState();

  CameraState get state => _state;
  double get x => _state.x;
  double get y => _state.y;
  double get zoom => _state.zoom;
  WorldCoordinate get position => _state.position;

  /// Updates camera state directly and notifies listeners.
  void setState(CameraState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  /// Begins interactive pan/pinch gesture.
  void onInteractionStart() {
    _state = _state.copyWith(
      isInteracting: true,
      velocityX: 0.0,
      velocityY: 0.0,
      targetX: _state.x,
      targetY: _state.y,
      targetZoom: _state.zoom,
    );
    notifyListeners();
  }

  /// Ends interactive pan/pinch gesture and registers release velocity.
  void onInteractionEnd({Offset velocity = Offset.zero}) {
    // If overshooting boundaries, force target to snap back inside [0, worldSize]
    final targetX = _state.x.clamp(0.0, CameraState.worldSize);
    final targetY = _state.y.clamp(0.0, CameraState.worldSize);

    final isOutOfBounds = (_state.x != targetX) || (_state.y != targetY);

    // Convert screen velocity (px/s) to world velocity units with adaptive damping
    final worldVx = isOutOfBounds ? 0.0 : (velocity.dx / _state.zoom) * 0.12;
    final worldVy = isOutOfBounds ? 0.0 : (velocity.dy / _state.zoom) * 0.12;

    _state = _state.copyWith(
      isInteracting: false,
      velocityX: -worldVx,
      velocityY: -worldVy,
      targetX: targetX,
      targetY: targetY,
    );
    notifyListeners();
  }

  /// Moves camera by screen pixel delta (pan) with elastic boundary resistance.
  void panByScreenDelta(Offset delta) {
    final worldDeltaX = -delta.dx / _state.zoom;
    final worldDeltaY = -delta.dy / _state.zoom;

    // Apply quadratic rubber-band resistance if dragging past world bounds
    double effectiveDeltaX = worldDeltaX;
    if (_state.x < 0.0 && worldDeltaX < 0) {
      final ratio = (-_state.x / maxOvershoot).clamp(0.0, 1.0);
      effectiveDeltaX *= (1.0 - ratio * 0.75);
    } else if (_state.x > CameraState.worldSize && worldDeltaX > 0) {
      final ratio = ((_state.x - CameraState.worldSize) / maxOvershoot).clamp(0.0, 1.0);
      effectiveDeltaX *= (1.0 - ratio * 0.75);
    }

    double effectiveDeltaY = worldDeltaY;
    if (_state.y < 0.0 && worldDeltaY < 0) {
      final ratio = (-_state.y / maxOvershoot).clamp(0.0, 1.0);
      effectiveDeltaY *= (1.0 - ratio * 0.75);
    } else if (_state.y > CameraState.worldSize && worldDeltaY > 0) {
      final ratio = ((_state.y - CameraState.worldSize) / maxOvershoot).clamp(0.0, 1.0);
      effectiveDeltaY *= (1.0 - ratio * 0.75);
    }

    final newX = (_state.x + effectiveDeltaX).clamp(-maxOvershoot, CameraState.worldSize + maxOvershoot);
    final newY = (_state.y + effectiveDeltaY).clamp(-maxOvershoot, CameraState.worldSize + maxOvershoot);

    _state = _state.copyWith(
      x: newX,
      y: newY,
      targetX: newX,
      targetY: newY,
    );
    notifyListeners();
  }

  /// Scales zoom centered around [focalPointScreen].
  void zoomAt({
    required Offset focalPointScreen,
    required double scaleMultiplier,
    required Size screenSize,
  }) {
    final oldZoom = _state.zoom;
    final newZoom = (oldZoom * scaleMultiplier).clamp(
      CameraState.minZoom,
      CameraState.maxZoom,
    );

    if ((newZoom - oldZoom).abs() < 1e-6) return;

    // Convert focal screen point to world coordinate before zoom
    final focalWorldBefore = WorldCoordinate.fromScreen(
      screenPoint: focalPointScreen,
      cameraX: _state.x,
      cameraY: _state.y,
      zoom: oldZoom,
      screenSize: screenSize,
    );

    // Reposition camera so focalWorldBefore maps to the exact same screenPoint under newZoom
    final halfW = screenSize.width / 2.0;
    final halfH = screenSize.height / 2.0;

    final newX = (focalWorldBefore.x - (focalPointScreen.dx - halfW) / newZoom)
        .clamp(-maxOvershoot, CameraState.worldSize + maxOvershoot);
    final newY = (focalWorldBefore.y - (focalPointScreen.dy - halfH) / newZoom)
        .clamp(-maxOvershoot, CameraState.worldSize + maxOvershoot);

    _state = _state.copyWith(
      x: newX,
      y: newY,
      zoom: newZoom,
      targetX: newX,
      targetY: newY,
      targetZoom: newZoom,
    );
    notifyListeners();
  }

  /// Desktop mouse wheel zoom around cursor position.
  void zoomByMouseWheel({
    required Offset focalPointScreen,
    required double scrollDelta,
    required Size screenSize,
  }) {
    // scrollDelta > 0 means scroll down (zoom out), < 0 means scroll up (zoom in)
    final factor = math.exp(-scrollDelta * 0.0018).clamp(0.80, 1.25);
    zoomAt(
      focalPointScreen: focalPointScreen,
      scaleMultiplier: factor,
      screenSize: screenSize,
    );
  }

  /// Smoothly animates camera to a target coordinate and zoom level.
  void flyTo(WorldCoordinate target, {double? zoom}) {
    final clampedX = target.x.clamp(0.0, CameraState.worldSize);
    final clampedY = target.y.clamp(0.0, CameraState.worldSize);
    final clampedZoom = (zoom ?? _state.zoom).clamp(
      CameraState.minZoom,
      CameraState.maxZoom,
    );

    _state = _state.copyWith(
      targetX: clampedX,
      targetY: clampedY,
      targetZoom: clampedZoom,
      velocityX: 0.0,
      velocityY: 0.0,
      isInteracting: false,
    );
    notifyListeners();
  }

  /// Centers the camera on the middle of Pindorama.
  void resetToCenter() {
    flyTo(const WorldCoordinate(5000.0, 5000.0), zoom: 1.0);
  }

  /// Advances camera physics tick by [dt] seconds.
  void tick(double dt) {
    if (_state.isInteracting) return;

    bool stateChanged = false;
    double newX = _state.x;
    double newY = _state.y;
    double newZoom = _state.zoom;
    double newVx = _state.velocityX;
    double newVy = _state.velocityY;

    // 1. Inertial glide from flick
    if (newVx.abs() > stopThreshold || newVy.abs() > stopThreshold) {
      newX += newVx * dt * 60.0;
      newY += newVy * dt * 60.0;
      newVx *= math.pow(friction, dt * 60.0);
      newVy *= math.pow(friction, dt * 60.0);

      if (newVx.abs() <= stopThreshold) newVx = 0.0;
      if (newVy.abs() <= stopThreshold) newVy = 0.0;

      // If out of bounds during glide, damp velocity rapidly and steer target inside
      if (newX < 0.0 || newX > CameraState.worldSize) newVx *= 0.7;
      if (newY < 0.0 || newY > CameraState.worldSize) newVy *= 0.7;

      _state = _state.copyWith(
        x: newX,
        y: newY,
        targetX: newX.clamp(0.0, CameraState.worldSize),
        targetY: newY.clamp(0.0, CameraState.worldSize),
        velocityX: newVx,
        velocityY: newVy,
      );
      stateChanged = true;
    } else {
      // 2. Spring towards target position (critically damped)
      final dx = _state.targetX - _state.x;
      final dy = _state.targetY - _state.y;
      final dZoom = _state.targetZoom - _state.zoom;

      // Check if spring back from rubber-band overshoot
      final currentStiffness = (_state.x < 0 || _state.x > CameraState.worldSize || _state.y < 0 || _state.y > CameraState.worldSize)
          ? boundarySpringStiffness
          : springStiffness;

      if (dx.abs() > 0.05 || dy.abs() > 0.05) {
        final springFactor = 1.0 - math.exp(-currentStiffness * dt);
        newX = _state.x + dx * springFactor;
        newY = _state.y + dy * springFactor;
        stateChanged = true;
      } else {
        newX = _state.targetX;
        newY = _state.targetY;
      }

      if (dZoom.abs() > 0.001) {
        final zoomSpringFactor = 1.0 - math.exp(-zoomSpringStiffness * dt);
        newZoom = _state.zoom + dZoom * zoomSpringFactor;
        stateChanged = true;
      } else {
        newZoom = _state.targetZoom;
      }

      if (stateChanged) {
        _state = _state.copyWith(
          x: newX,
          y: newY,
          zoom: newZoom.clamp(CameraState.minZoom, CameraState.maxZoom),
        );
      }
    }

    if (stateChanged) {
      notifyListeners();
    }
  }
}
