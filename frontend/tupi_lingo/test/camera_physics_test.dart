import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tupi_lingo/core/world_engine/camera/camera_state.dart';
import 'package:tupi_lingo/core/world_engine/camera/world_camera_controller.dart';
import 'package:tupi_lingo/core/world_engine/coordinates/world_coordinate.dart';

void main() {
  group('Camera UX & Elastic Physics Engine (RFC-012C Patch 1 Chapter 4)', () {
    test('Elastic bounds apply rubber-band damping beyond world edges', () {
      final controller = WorldCameraController(
        initialState: const CameraState(x: 0.0, y: 5000.0, zoom: 1.0),
      );

      // Drag right by 200 screen pixels -> camera tries to move left into negative space
      controller.panByScreenDelta(const Offset(200, 0));

      // With rubber-band resistance, camera overshoots into negative space but clamped within maxOvershoot
      expect(controller.x, lessThan(0.0));
      expect(controller.x, greaterThanOrEqualTo(-WorldCameraController.maxOvershoot));

      // Releasing gesture triggers snap-back spring towards clamped target [0, 10000]
      controller.onInteractionEnd();
      expect(controller.state.targetX, equals(0.0));

      // Tick camera physics to advance spring back
      for (int i = 0; i < 30; i++) {
        controller.tick(0.016);
      }
      expect(controller.x, closeTo(0.0, 1.0));
    });

    test('Desktop mouse wheel zoom scales smoothly around cursor focal point', () {
      final controller = WorldCameraController(
        initialState: const CameraState(x: 5000.0, y: 5000.0, zoom: 1.0),
      );
      const screenSize = Size(800, 600);
      const cursorScreenPoint = Offset(400, 300); // Screen center

      // Scroll up (zoom in)
      controller.zoomByMouseWheel(
        focalPointScreen: cursorScreenPoint,
        scrollDelta: -100.0,
        screenSize: screenSize,
      );

      expect(controller.zoom, greaterThan(1.0));
      // Since zoom is centered on screen center, camera position should remain at 5000, 5000
      expect(controller.x, closeTo(5000.0, 0.01));
      expect(controller.y, closeTo(5000.0, 0.01));

      // Scroll down (zoom out)
      controller.zoomByMouseWheel(
        focalPointScreen: cursorScreenPoint,
        scrollDelta: 200.0,
        screenSize: screenSize,
      );
      expect(controller.zoom, lessThan(1.15));
    });

    test('Fly-to animation smoothly targets destination without overshoot explosion', () {
      final controller = WorldCameraController(
        initialState: const CameraState(x: 5000.0, y: 5000.0, zoom: 1.0),
      );

      controller.flyTo(const WorldCoordinate(6000.0, 6000.0), zoom: 1.5);
      expect(controller.state.targetX, equals(6000.0));
      expect(controller.state.targetY, equals(6000.0));
      expect(controller.state.targetZoom, equals(1.5));

      // Tick spring simulation
      for (int i = 0; i < 60; i++) {
        controller.tick(0.016);
      }

      expect(controller.x, closeTo(6000.0, 0.1));
      expect(controller.y, closeTo(6000.0, 0.1));
      expect(controller.zoom, closeTo(1.5, 0.05));
    });
  });
}
