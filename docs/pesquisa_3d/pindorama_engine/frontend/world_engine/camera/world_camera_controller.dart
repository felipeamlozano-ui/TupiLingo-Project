import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../coordinates/world_bounds.dart';
import '../coordinates/world_coordinate.dart';
import 'camera_state.dart';

/// Smooth, physics-driven camera controller for Pindorama continuous world (RFC-012C Patch 1 Chapter 4).
///
/// Features:
/// - Dynamic RTS / LoL-style viewport bounding (camera cannot pan into unexplored Terra Incognita).
/// - Critically damped spring physics for target transitions (flyTo).
/// - Exponential velocity decay inertia for pan flicks.
/// - Elastic rubber-band boundary overshoot with spring-back.
/// - Desktop mouse wheel and trackpad focal zoom.
/// - Adaptive gesture sensitivity for high-precision inspection.
class WorldCameraController extends ChangeNotifier {
  CameraState _state;

  // Spring & inertia parameters (suavizados para movimentação orgânica)
  static const double friction = 0.86;
  static const double springStiffness = 10.0;
  static const double zoomSpringStiffness = 11.0;
  static const double boundarySpringStiffness = 16.0;
  static const double stopThreshold = 0.05;
  static const double maxOvershoot = 35.0;

  WorldBounds? allowedBounds;

  WorldCameraController({CameraState? initialState, this.allowedBounds})
      : _state = initialState ?? const CameraState();

  CameraState get state => _state;
  double get x => _state.x;
  double get y => _state.y;
  double get zoom => _state.zoom;
  WorldCoordinate get position => _state.position;

  double get minAllowedX => allowedBounds?.minX ?? 0.0;
  double get maxAllowedX => allowedBounds?.maxX ?? CameraState.worldSize;
  double get minAllowedY => allowedBounds?.minY ?? 0.0;
  double get maxAllowedY => allowedBounds?.maxY ?? CameraState.worldSize;

  /// Atualiza os limites de movimentação permitidos da câmera (RTS / LoL style boundary).
  void setAllowedBounds(WorldBounds? bounds, {bool snapImmediately = false}) {
    allowedBounds = bounds;
    if (bounds != null) {
      final clampedX = _state.targetX.clamp(bounds.minX, bounds.maxX);
      final clampedY = _state.targetY.clamp(bounds.minY, bounds.maxY);
      if (snapImmediately) {
        _state = _state.copyWith(
          x: clampedX,
          y: clampedY,
          targetX: clampedX,
          targetY: clampedY,
        );
      } else if (clampedX != _state.targetX || clampedY != _state.targetY) {
        _state = _state.copyWith(targetX: clampedX, targetY: clampedY);
      }
      notifyListeners();
    }
  }

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
    // Clampa estritamente ao limite do território liberado
    final targetX = _state.x.clamp(minAllowedX, maxAllowedX);
    final targetY = _state.y.clamp(minAllowedY, maxAllowedY);

    final isOutOfBounds = (_state.x != targetX) || (_state.y != targetY);

    // Se estiver na borda ou fora dela, anula a velocidade na direção bloqueada
    final worldVx = isOutOfBounds ? 0.0 : (velocity.dx / _state.zoom) * 0.045;
    final worldVy = isOutOfBounds ? 0.0 : (velocity.dy / _state.zoom) * 0.045;

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

    // Resistência firme nas bordas do território liberado
    double effectiveDeltaX = worldDeltaX;
    if (_state.x <= minAllowedX && worldDeltaX < 0) {
      effectiveDeltaX *= 0.12;
    } else if (_state.x >= maxAllowedX && worldDeltaX > 0) {
      effectiveDeltaX *= 0.12;
    }

    double effectiveDeltaY = worldDeltaY;
    if (_state.y <= minAllowedY && worldDeltaY < 0) {
      effectiveDeltaY *= 0.12;
    } else if (_state.y >= maxAllowedY && worldDeltaY > 0) {
      effectiveDeltaY *= 0.12;
    }

    final newX = (_state.x + effectiveDeltaX).clamp(minAllowedX - maxOvershoot, maxAllowedX + maxOvershoot);
    final newY = (_state.y + effectiveDeltaY).clamp(minAllowedY - maxOvershoot, maxAllowedY + maxOvershoot);

    _state = _state.copyWith(
      x: newX,
      y: newY,
      targetX: newX.clamp(minAllowedX, maxAllowedX),
      targetY: newY.clamp(minAllowedY, maxAllowedY),
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
        .clamp(minAllowedX, maxAllowedX);
    final newY = (focalWorldBefore.y - (focalPointScreen.dy - halfH) / newZoom)
        .clamp(minAllowedY, maxAllowedY);

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
    final factor = math.exp(-scrollDelta * 0.0007).clamp(0.94, 1.06);
    zoomAt(
      focalPointScreen: focalPointScreen,
      scaleMultiplier: factor,
      screenSize: screenSize,
    );
  }

  /// Smoothly animates camera to a target coordinate and zoom level within allowed bounds.
  void flyTo(WorldCoordinate target, {double? zoom}) {
    final clampedX = target.x.clamp(minAllowedX, maxAllowedX);
    final clampedY = target.y.clamp(minAllowedY, maxAllowedY);
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

  /// Instantly snaps the camera to [target] coordinate without spring delay.
  void jumpTo(WorldCoordinate target, {double? zoom}) {
    final clampedX = target.x.clamp(minAllowedX, maxAllowedX);
    final clampedY = target.y.clamp(minAllowedY, maxAllowedY);
    final newZoom = (zoom ?? _state.zoom).clamp(
      CameraState.minZoom,
      CameraState.maxZoom,
    );

    _state = _state.copyWith(
      x: clampedX,
      y: clampedY,
      targetX: clampedX,
      targetY: clampedY,
      zoom: newZoom,
      targetZoom: newZoom,
      velocityX: 0.0,
      velocityY: 0.0,
      isInteracting: false,
    );
    notifyListeners();
  }

  /// Centers the camera on the center of the unlocked territory.
  void resetToCenter() {
    final cx = (minAllowedX + maxAllowedX) / 2.0;
    final cy = (minAllowedY + maxAllowedY) / 2.0;
    flyTo(WorldCoordinate(cx, cy), zoom: 1.15);
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

      // Trava estrita: a inércia não pode ultrapassar o limite do território liberado
      if (newX <= minAllowedX || newX >= maxAllowedX) {
        newVx = 0.0;
        newX = newX.clamp(minAllowedX, maxAllowedX);
      }
      if (newY <= minAllowedY || newY >= maxAllowedY) {
        newVy = 0.0;
        newY = newY.clamp(minAllowedY, maxAllowedY);
      }

      if (newVx.abs() <= stopThreshold) newVx = 0.0;
      if (newVy.abs() <= stopThreshold) newVy = 0.0;

      _state = _state.copyWith(
        x: newX,
        y: newY,
        targetX: newX.clamp(minAllowedX, maxAllowedX),
        targetY: newY.clamp(minAllowedY, maxAllowedY),
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
      final currentStiffness = (_state.x < minAllowedX || _state.x > maxAllowedX || _state.y < minAllowedY || _state.y > maxAllowedY)
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
