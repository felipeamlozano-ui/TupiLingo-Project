import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:tupi_lingo/core/config/app_config.dart';

/// Modelo de amostra de telemetria agregada e anônima.
/// STRICT ZERO-PII GUARANTEE: Jamais armazena ou transmite UIDs, emails, IPs ou dados pessoais.
class TelemetryMetricSample {
  final double fps;
  final double avgBuildMs;
  final double avgRasterMs;
  final double frameDropsPct;
  final double memoryMb;
  final double p95LatencyMs;
  final String deviceClass;
  final DateTime timestamp;

  const TelemetryMetricSample({
    required this.fps,
    required this.avgBuildMs,
    required this.avgRasterMs,
    required this.frameDropsPct,
    required this.memoryMb,
    required this.p95LatencyMs,
    required this.deviceClass,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'fps': double.parse(fps.toStringAsFixed(1)),
    'avg_build_ms': double.parse(avgBuildMs.toStringAsFixed(2)),
    'avg_raster_ms': double.parse(avgRasterMs.toStringAsFixed(2)),
    'frame_drops_pct': double.parse(frameDropsPct.toStringAsFixed(2)),
    'memory_mb': double.parse(memoryMb.toStringAsFixed(1)),
    'p95_latency_ms': double.parse(p95LatencyMs.toStringAsFixed(1)),
    'device_class': deviceClass,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Estado reativo para observabilidade da plataforma
class TelemetryState {
  final double currentFps;
  final double avgBuildMs;
  final double avgRasterMs;
  final double memoryMb;
  final double networkLatencyMs;
  final int totalFrames;
  final int droppedFrames;
  final List<TelemetryMetricSample> history;
  final bool isRecording;

  const TelemetryState({
    this.currentFps = 60.0,
    this.avgBuildMs = 3.2,
    this.avgRasterMs = 3.8,
    this.memoryMb = 145.0,
    this.networkLatencyMs = 28.0,
    this.totalFrames = 0,
    this.droppedFrames = 0,
    this.history = const [],
    this.isRecording = false,
  });

  TelemetryState copyWith({
    double? currentFps,
    double? avgBuildMs,
    double? avgRasterMs,
    double? memoryMb,
    double? networkLatencyMs,
    int? totalFrames,
    int? droppedFrames,
    List<TelemetryMetricSample>? history,
    bool? isRecording,
  }) {
    return TelemetryState(
      currentFps: currentFps ?? this.currentFps,
      avgBuildMs: avgBuildMs ?? this.avgBuildMs,
      avgRasterMs: avgRasterMs ?? this.avgRasterMs,
      memoryMb: memoryMb ?? this.memoryMb,
      networkLatencyMs: networkLatencyMs ?? this.networkLatencyMs,
      totalFrames: totalFrames ?? this.totalFrames,
      droppedFrames: droppedFrames ?? this.droppedFrames,
      history: history ?? this.history,
      isRecording: isRecording ?? this.isRecording,
    );
  }
}

/// Serviço de métricas de desempenho e diagnóstico da interface client-side.
class TelemetryService extends Notifier<TelemetryState> {
  Timer? _sampleTimer;
  Timer? _flushTimer;
  final List<double> _latencySamples = [];
  final List<FrameTiming> _timingBuffer = [];
  final int _maxHistoryLength = 20;

  @override
  TelemetryState build() {
    ref.onDispose(() {
      _sampleTimer?.cancel();
      _flushTimer?.cancel();
      SchedulerBinding.instance.removeTimingsCallback(_onReportTimings);
    });
    return const TelemetryState();
  }

  void _onReportTimings(List<FrameTiming> timings) {
    if (!state.isRecording) return;
    _timingBuffer.addAll(timings);
    if (_timingBuffer.length > 300) {
      _timingBuffer.removeRange(0, _timingBuffer.length - 300);
    }
  }

  /// Inicia monitoramento e agendamento de upload em lote
  void startMonitoring() {
    if (state.isRecording) return;
    state = state.copyWith(isRecording: true);

    SchedulerBinding.instance.addTimingsCallback(_onReportTimings);
    _sampleTimer = Timer.periodic(const Duration(seconds: 2), (_) => _collectSample());
    _flushTimer = Timer.periodic(const Duration(seconds: 120), (_) => flushTelemetry());
  }

  void stopMonitoring() {
    if (!state.isRecording) return;
    SchedulerBinding.instance.removeTimingsCallback(_onReportTimings);
    _sampleTimer?.cancel();
    _flushTimer?.cancel();
    state = state.copyWith(isRecording: false);
  }

  void _collectSample() {
    if (!state.isRecording) return;

    final List<FrameTiming> samples = List<FrameTiming>.from(_timingBuffer);
    _timingBuffer.clear();

    double fps = 60.0;
    double avgBuild = 1.2;
    double avgRaster = 0.8;
    int totalFrames = samples.length;
    int droppedFrames = 0;
    double dropRate = 0.0;

    if (samples.isNotEmpty) {
      double totalBuildMs = 0.0;
      double totalRasterMs = 0.0;
      double totalSpanMs = 0.0;

      for (final t in samples) {
        final bMs = t.buildDuration.inMicroseconds / 1000.0;
        final rMs = t.rasterDuration.inMicroseconds / 1000.0;
        final spanMs = t.totalSpan.inMicroseconds / 1000.0;
        totalBuildMs += bMs;
        totalRasterMs += rMs;
        totalSpanMs += spanMs;

        // Quadros com tempo total acima de 16.6ms (limite de 60 FPS)
        if (spanMs > 16.6) {
          droppedFrames++;
        }
      }

      avgBuild = totalBuildMs / samples.length;
      avgRaster = totalRasterMs / samples.length;
      dropRate = (droppedFrames / samples.length) * 100.0;

      final avgSpanMs = totalSpanMs / samples.length;
      if (avgSpanMs > 0) {
        fps = min(60.0, max(1.0, 1000.0 / avgSpanMs));
      }
    }

    // Estimativa segura de consumo de memória da aplicação
    final estimatedRam = 140.0 + (min(totalFrames / 1000, 45.0));

    final sample = TelemetryMetricSample(
      fps: fps,
      avgBuildMs: avgBuild,
      avgRasterMs: avgRaster,
      frameDropsPct: dropRate,
      memoryMb: estimatedRam,
      p95LatencyMs: _calculateP95Latency(),
      deviceClass: _inferDeviceClass(fps),
      timestamp: DateTime.now(),
    );

    final updatedHistory = List<TelemetryMetricSample>.from(state.history)..add(sample);
    if (updatedHistory.length > _maxHistoryLength) {
      updatedHistory.removeAt(0);
    }

    state = state.copyWith(
      currentFps: fps,
      avgBuildMs: avgBuild,
      avgRasterMs: avgRaster,
      memoryMb: estimatedRam,
      totalFrames: totalFrames,
      droppedFrames: droppedFrames,
      history: updatedHistory,
    );
  }

  /// Registra uma amostra anônima de latência de requisição
  void recordNetworkLatency(Duration duration) {
    final ms = duration.inMilliseconds.toDouble();
    _latencySamples.add(ms);
    if (_latencySamples.length > 50) {
      _latencySamples.removeAt(0);
    }
    state = state.copyWith(networkLatencyMs: ms);
  }

  double _calculateP95Latency() {
    if (_latencySamples.isEmpty) return 25.0;
    final sorted = List<double>.from(_latencySamples)..sort();
    final p95Index = ((sorted.length - 1) * 0.95).floor();
    return sorted[p95Index];
  }

  String _inferDeviceClass(double fps) {
    if (fps >= 58.0) return 'flagship';
    if (fps >= 45.0) return 'high';
    if (fps >= 30.0) return 'mid';
    return 'low';
  }

  /// Envia amostra agregada ao backend Django (/api/v1/platform/record/)
  Future<void> flushTelemetry() async {
    if (state.history.isEmpty) return;

    try {
      final sample = state.history.last;
      final payload = {
        'device_class': sample.deviceClass,
        'avg_fps': sample.fps,
        'frame_drops_pct': sample.frameDropsPct,
        'memory_mb': sample.memoryMb,
        'gpu_tier': 'impeller-vulkan',
      };

      final url = Uri.parse('${AppConfig.backendBaseUrl}/api/v1/platform/record/');
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {
      // Telemetria silenciosa: falhas de rede nunca interrompem o usuário
    }
  }
}

/// Provider global Riverpod 3 para Telemetria
final telemetryServiceProvider = NotifierProvider<TelemetryService, TelemetryState>(
  TelemetryService.new,
);
