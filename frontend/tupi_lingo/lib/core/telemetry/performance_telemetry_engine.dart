import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Instant Loading Engine Telemetry & Frame Pacing Inspector.
///
/// Monitora em tempo real:
/// - UI Thread Build Duration (Meta: < 4.0ms)
/// - Raster Thread Duration (Meta: < 4.0ms)
/// - Dropped Frames & Stutter Events
/// - Taxa de FPS média (60 / 90 / 120 Hz)
class PerformanceTelemetryEngine {
  PerformanceTelemetryEngine._();

  static final PerformanceTelemetryEngine instance = PerformanceTelemetryEngine._();

  bool _isMonitoring = false;
  int _totalFrames = 0;
  int _droppedFrames = 0;
  double _lastFps = 60.0;
  double _avgBuildMs = 0.0;
  double _avgRasterMs = 0.0;

  int get totalFrames => _totalFrames;
  int get droppedFrames => _droppedFrames;
  double get currentFps => _lastFps;
  double get averageBuildDurationMs => _avgBuildMs;
  double get averageRasterDurationMs => _avgRasterMs;

  /// Inicia o monitoramento de frame timings com zero overhead.
  void start() {
    if (_isMonitoring) return;
    _isMonitoring = true;

    WidgetsBinding.instance.addTimingsCallback(_onReportTimings);
    debugPrint('📊 [TelemetryEngine] Telemetria de Frame Timing ativa (Alvo: Build < 4ms, Raster < 4ms).');
  }

  void stop() {
    if (!_isMonitoring) return;
    WidgetsBinding.instance.removeTimingsCallback(_onReportTimings);
    _isMonitoring = false;
  }

  void _onReportTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _totalFrames++;

      final buildMs = timing.buildDuration.inMicroseconds / 1000.0;
      final rasterMs = timing.rasterDuration.inMicroseconds / 1000.0;
      final totalSpanMs = timing.totalSpan.inMicroseconds / 1000.0;

      // Média móvel exponencial (EMA) com alpha = 0.05
      _avgBuildMs = (_avgBuildMs == 0.0) ? buildMs : (_avgBuildMs * 0.95 + buildMs * 0.05);
      _avgRasterMs = (_avgRasterMs == 0.0) ? rasterMs : (_avgRasterMs * 0.95 + rasterMs * 0.05);

      // Alvo para 60Hz: 16.6ms. Para 120Hz: 8.33ms.
      final targetBudgetMs = 16.66;
      final isDropped = totalSpanMs > targetBudgetMs;

      if (isDropped) {
        _droppedFrames++;
        if (kDebugMode && totalSpanMs > 32.0) {
          debugPrint(
            '⚠️ [Telemetry Jank Alert] Frame lento: ${totalSpanMs.toStringAsFixed(1)}ms '
            '(Build: ${buildMs.toStringAsFixed(1)}ms, Raster: ${rasterMs.toStringAsFixed(1)}ms)',
          );
        }
      }

      if (totalSpanMs > 0) {
        final instantFps = 1000.0 / totalSpanMs;
        _lastFps = (_lastFps * 0.9 + instantFps * 0.1).clamp(0.0, 144.0);
      }
    }
  }

  /// Retorna um relatório consolidado de desempenho.
  Map<String, dynamic> getReport() {
    return {
      'total_frames': _totalFrames,
      'dropped_frames': _droppedFrames,
      'drop_rate_pct': _totalFrames > 0 ? ((_droppedFrames / _totalFrames) * 100.0).toStringAsFixed(2) : '0.0',
      'avg_build_ms': _avgBuildMs.toStringAsFixed(2),
      'avg_raster_ms': _avgRasterMs.toStringAsFixed(2),
      'fps': _lastFps.toStringAsFixed(1),
    };
  }
}
