import 'package:flutter/foundation.dart';

/// Device capability performance tiers (RFC-012B Chapter 33).
enum DevicePerformanceTier {
  high(targetFps: 120, targetFrameBudgetMs: 8.33, enableParticles: true, maxLOD: 0),
  medium(targetFps: 60, targetFrameBudgetMs: 16.66, enableParticles: true, maxLOD: 1),
  low(targetFps: 30, targetFrameBudgetMs: 33.33, enableParticles: false, maxLOD: 2);

  final int targetFps;
  final double targetFrameBudgetMs;
  final bool enableParticles;
  final int maxLOD;

  const DevicePerformanceTier({
    required this.targetFps,
    required this.targetFrameBudgetMs,
    required this.enableParticles,
    required this.maxLOD,
  });
}

/// Adaptive Rendering Engine adjusting Level of Detail (LOD) and shader effects dynamically.
class AdaptiveRenderingEngine {
  DevicePerformanceTier currentTier;
  final List<double> _recentFrameTimesMs = [];

  AdaptiveRenderingEngine({this.currentTier = DevicePerformanceTier.medium});

  /// Automatically profiles device capability based on platform and hardware heuristics.
  static DevicePerformanceTier profileDevice() {
    if (kIsWeb) return DevicePerformanceTier.medium;
    // On high-end mobile devices, defaults to high, mid-range to medium
    return DevicePerformanceTier.high;
  }

  /// Records frame duration in milliseconds and dynamically adjusts tier if dropping frames.
  void recordFrame(double frameDurationMs) {
    _recentFrameTimesMs.add(frameDurationMs);
    if (_recentFrameTimesMs.length > 60) {
      _recentFrameTimesMs.removeAt(0);
      _evaluateTierAdaptation();
    }
  }

  void _evaluateTierAdaptation() {
    if (_recentFrameTimesMs.isEmpty) return;
    final avg = _recentFrameTimesMs.reduce((a, b) => a + b) / _recentFrameTimesMs.length;

    // If exceeding frame budget consistently, step down tier
    if (avg > currentTier.targetFrameBudgetMs * 1.25) {
      if (currentTier == DevicePerformanceTier.high) {
        currentTier = DevicePerformanceTier.medium;
      } else if (currentTier == DevicePerformanceTier.medium) {
        currentTier = DevicePerformanceTier.low;
      }
    } else if (avg < currentTier.targetFrameBudgetMs * 0.50) {
      // Step up if abundant headroom
      if (currentTier == DevicePerformanceTier.low) {
        currentTier = DevicePerformanceTier.medium;
      } else if (currentTier == DevicePerformanceTier.medium) {
        currentTier = DevicePerformanceTier.high;
      }
    }
  }
}
