import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../camera/world_camera_controller.dart';
import '../coordinates/world_coordinate.dart';
import '../fog/fog_state.dart';
import '../fog/world_discovery_engine.dart';
import '../landmarks/historical_landmark.dart';
import '../particles/world_particle_pool.dart';
import '../trails/historical_trail.dart';
import '../trails/historical_overlay.dart';
import '../trails/river_path.dart';
import '../villages/village_node.dart';
import '../theme/pindorama_theme_palette.dart';
import 'pindorama_world_painter.dart';
import '../../../../features/historical_map/presentation/widgets/historical_timeline_slider.dart';

/// Master interactive widget hosting the continuous Pindorama World Engine (RFC-012C Patch 1 Chapter 4 & 6).
///
/// Features:
/// - 120 FPS hardware Ticker loop with bound frame delta.
/// - Desktop mouse wheel and trackpad focal zoom.
/// - Fluid pan with elastic rubber-band boundaries.
/// - Short tap, long-press preview, and double-tap zoom hit-testing for both settlements and landmarks.
/// - Contextual mouse hover detection.
/// - RepaintBoundary for silky smooth rendering isolation.
class PindoramaWorldViewport extends StatefulWidget {
  final WorldCameraController controller;
  final List<VillageNode> villages;
  final List<RiverPath> rivers;
  final List<HistoricalTrail> trails;
  final List<HistoricalOverlay> overlays;
  final List<HistoricalLandmark>? landmarks;
  final FogState fogState;
  final WorldParticlePool particlePool;
  final PindoramaThemePalette? palette;
  final VillageNode? selectedVillage;
  final HistoricalLandmark? selectedLandmark;
  final ValueChanged<VillageNode>? onVillageSelected;
  final ValueChanged<VillageNode>? onVillageLongPressed;
  final ValueChanged<VillageNode>? onVillageDoubleTapped;
  final ValueChanged<HistoricalLandmark>? onLandmarkSelected;
  final VoidCallback? onBackgroundTapped;
  final Widget? overlay;
  final HistoricalEpoch currentEpoch;
  final HistoricalEpoch previousEpoch;
  final double epochTransitionProgress;

  const PindoramaWorldViewport({
    super.key,
    required this.controller,
    required this.villages,
    required this.rivers,
    required this.trails,
    this.overlays = const [],
    this.landmarks,
    required this.fogState,
    required this.particlePool,
    this.palette,
    this.selectedVillage,
    this.selectedLandmark,
    this.onVillageSelected,
    this.onVillageLongPressed,
    this.onVillageDoubleTapped,
    this.onLandmarkSelected,
    this.onBackgroundTapped,
    this.overlay,
    this.currentEpoch = HistoricalEpoch.pre1500,
    this.previousEpoch = HistoricalEpoch.pre1500,
    this.epochTransitionProgress = 1.0,
  });

  @override
  State<PindoramaWorldViewport> createState() => _PindoramaWorldViewportState();
}

class _PindoramaWorldViewportState extends State<PindoramaWorldViewport>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _elapsedTime = 0.0;
  final ValueNotifier<double> _frameNotifier = ValueNotifier<double>(0.0);
  late Listenable _repaintSignal;

  // Gesture state tracking
  double _lastScale = 1.0;
  Offset _lastFocalPoint = Offset.zero;
  bool _isHoveringInteractive = false;

  // Optional Impeller fragment shader for volumetric fog
  ui.FragmentShader? _fogShader;

  @override
  void initState() {
    super.initState();
    _repaintSignal = Listenable.merge([_frameNotifier, widget.controller]);
    widget.particlePool.initializeDefaults();
    _loadShader();

    _ticker = createTicker((elapsed) {
      if (_lastTick == Duration.zero) {
        _lastTick = elapsed;
        return;
      }
      final dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
      _lastTick = elapsed;

      final boundedDt = dt.clamp(0.001, 0.033);
      _elapsedTime += boundedDt;

      widget.controller.tick(boundedDt);
      widget.particlePool.tick(boundedDt);
      WorldDiscoveryEngine.instance.tick(boundedDt);

      _frameNotifier.value = _elapsedTime;
    });

    _ticker.start();
  }

  @override
  void didUpdateWidget(PindoramaWorldViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _repaintSignal = Listenable.merge([_frameNotifier, widget.controller]);
    }
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'assets/shaders/fog_of_war.frag',
      );
      if (mounted) {
        setState(() {
          _fogShader = program.fragmentShader();
        });
      }
    } catch (_) {
      // Graceful fallback to CPU canvas radial blend mode
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frameNotifier.dispose();
    _fogShader?.dispose();
    super.dispose();
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _lastScale = 1.0;
    _lastFocalPoint = details.localFocalPoint;
    widget.controller.onInteractionStart();
  }

  void _handleScaleUpdate(ScaleUpdateDetails details, Size screenSize) {
    // 1. Pinch Zoom update
    if ((details.scale - 1.0).abs() > 0.005) {
      final scaleMultiplier = details.scale / _lastScale;
      _lastScale = details.scale;

      widget.controller.zoomAt(
        focalPointScreen: details.localFocalPoint,
        scaleMultiplier: scaleMultiplier,
        screenSize: screenSize,
      );
    } else {
      // 2. Pure Pan update
      final delta = details.localFocalPoint - _lastFocalPoint;
      if (delta != Offset.zero) {
        widget.controller.panByScreenDelta(delta);
      }
    }
    _lastFocalPoint = details.localFocalPoint;
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    widget.controller.onInteractionEnd(
      velocity: details.velocity.pixelsPerSecond,
    );
  }

  VillageNode? _findVillageAt(Offset localPosition, Size screenSize) {
    final camera = widget.controller.state;
    for (final village in widget.villages.reversed) {
      if (village.stage == VillageEvolutionStage.oculta && !village.isFrontier) continue;

      final screenPt = village.coordinate.toScreen(
        cameraX: camera.x,
        cameraY: camera.y,
        zoom: camera.zoom,
        screenSize: screenSize,
      );

      // Hit area covers both the settlement ground and the floating plaque
      final hitRadius = (80.0 * camera.zoom).clamp(42.0, 160.0);
      final dist = (localPosition - screenPt).distance;

      // Check settlement center
      if (dist <= hitRadius) {
        return village;
      }

      // Check plaque area above settlement
      final plaqueCenter = Offset(screenPt.dx, screenPt.dy - 78.0 * camera.zoom);
      if ((localPosition - plaqueCenter).distance <= 38.0 * camera.zoom.clamp(0.8, 1.8)) {
        return village;
      }
    }
    return null;
  }

  HistoricalLandmark? _findLandmarkAt(Offset localPosition, Size screenSize) {
    final camera = widget.controller.state;
    final landmarks = widget.landmarks ?? HistoricalLandmark.canonicalLandmarks;

    for (final landmark in landmarks) {
      final screenPt = landmark.coordinate.toScreen(
        cameraX: camera.x,
        cameraY: camera.y,
        zoom: camera.zoom,
        screenSize: screenSize,
      );

      final hitRadius = (32.0 * camera.zoom).clamp(20.0, 60.0);
      if ((localPosition - screenPt).distance <= hitRadius) {
        return landmark;
      }
    }
    return null;
  }

  void _handleTapUp(TapUpDetails details, Size screenSize) {
    final villageHit = _findVillageAt(details.localPosition, screenSize);
    if (villageHit != null) {
      widget.onVillageSelected?.call(villageHit);
      return;
    }

    final landmarkHit = _findLandmarkAt(details.localPosition, screenSize);
    if (landmarkHit != null) {
      widget.onLandmarkSelected?.call(landmarkHit);
      return;
    }

    widget.onBackgroundTapped?.call();
  }

  void _handleLongPress(LongPressStartDetails details, Size screenSize) {
    final hit = _findVillageAt(details.localPosition, screenSize);
    if (hit != null) {
      widget.onVillageLongPressed?.call(hit);
    }
  }

  void _handleDoubleTapDown(TapDownDetails details, Size screenSize) {
    final hit = _findVillageAt(details.localPosition, screenSize);
    if (hit != null) {
      widget.onVillageDoubleTapped?.call(hit);
    } else {
      final currentZoom = widget.controller.zoom;
      final targetZoom = currentZoom < 1.8 ? currentZoom * 1.6 : 1.0;

      final targetWorld = WorldCoordinate.fromScreen(
        screenPoint: details.localPosition,
        cameraX: widget.controller.x,
        cameraY: widget.controller.y,
        zoom: currentZoom,
        screenSize: screenSize,
      );

      widget.controller.flyTo(targetWorld, zoom: targetZoom);
    }
  }

  void _handlePointerSignal(PointerSignalEvent event, Size screenSize) {
    if (event is PointerScrollEvent) {
      widget.controller.zoomByMouseWheel(
        focalPointScreen: event.localPosition,
        scrollDelta: event.scrollDelta.dy,
        screenSize: screenSize,
      );
    }
  }

  void _handlePointerPanZoomUpdate(PointerPanZoomUpdateEvent event, Size screenSize) {
    if (event.scale != 1.0) {
      widget.controller.zoomAt(
        focalPointScreen: event.localPosition,
        scaleMultiplier: event.scale,
        screenSize: screenSize,
      );
    } else if (event.panDelta != Offset.zero) {
      widget.controller.panByScreenDelta(event.panDelta);
    }
  }

  void _handlePointerHover(PointerHoverEvent event, Size screenSize) {
    final vHit = _findVillageAt(event.localPosition, screenSize);
    final lHit = _findLandmarkAt(event.localPosition, screenSize);
    final isHovering = vHit != null || lHit != null;
    if (_isHoveringInteractive != isHovering) {
      setState(() {
        _isHoveringInteractive = isHovering;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = Size(constraints.maxWidth, constraints.maxHeight);

        return MouseRegion(
          cursor: _isHoveringInteractive ? SystemMouseCursors.click : SystemMouseCursors.grab,
          onHover: (e) => _handlePointerHover(e, screenSize),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerSignal: (e) => _handlePointerSignal(e, screenSize),
            onPointerPanZoomUpdate: (e) => _handlePointerPanZoomUpdate(e, screenSize),
            child: Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: _handleScaleStart,
                  onScaleUpdate: (details) => _handleScaleUpdate(details, screenSize),
                  onScaleEnd: _handleScaleEnd,
                  onTapUp: (details) => _handleTapUp(details, screenSize),
                  onLongPressStart: (details) => _handleLongPress(details, screenSize),
                  onDoubleTapDown: (details) => _handleDoubleTapDown(details, screenSize),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: screenSize,
                      painter: PindoramaWorldPainter(
                        repaint: _repaintSignal,
                        cameraController: widget.controller,
                        getAnimationTime: () => _elapsedTime,
                        villages: widget.villages,
                        rivers: widget.rivers,
                        trails: widget.trails,
                        overlays: widget.overlays,
                        landmarks: widget.landmarks,
                        fogState: widget.fogState,
                        particlePool: widget.particlePool,
                        palette: widget.palette,
                        selectedVillage: widget.selectedVillage,
                        selectedLandmark: widget.selectedLandmark,
                        fogShader: _fogShader,
                        currentEpoch: widget.currentEpoch,
                        previousEpoch: widget.previousEpoch,
                        epochTransitionProgress: widget.epochTransitionProgress,
                      ),
                    ),
                  ),
                ),
                if (widget.overlay != null) widget.overlay!,
              ],
            ),
          ),
        );
      },
    );
  }
}
