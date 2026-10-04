import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tupi_lingo/core/telemetry/telemetry_service.dart';

/// Developer HUD Overlay flutuante e interativo (RFC-013 Capítulo 20).
/// Renderiza métricas em tempo real (FPS, Build/Raster Thread, RAM, Câmera, Partículas)
/// com impacto visual zero no usuário comum (ativado apenas em Dev ou modo Admin).
class DeveloperHudOverlay extends ConsumerStatefulWidget {
  final Widget child;
  final bool initialVisible;

  const DeveloperHudOverlay({
    super.key,
    required this.child,
    this.initialVisible = false,
  });

  @override
  ConsumerState<DeveloperHudOverlay> createState() => _DeveloperHudOverlayState();
}

class _DeveloperHudOverlayState extends ConsumerState<DeveloperHudOverlay> {
  late bool _isVisible;
  bool _isExpanded = true;
  Offset _position = const Offset(20, 80);

  @override
  void initState() {
    super.initState();
    _isVisible = widget.initialVisible;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(telemetryServiceProvider.notifier).startMonitoring();
    });
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = ref.watch(telemetryServiceProvider);

    return Stack(
      children: [
        widget.child,
        if (_isVisible)
          Positioned(
            left: _position.dx,
            top: _position.dy,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _position += details.delta;
                });
              },
              child: Material(
                color: Colors.transparent,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xEB0F172A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: telemetry.currentFps < 45.0
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981).withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: _isExpanded
                      ? _buildExpandedHud(telemetry)
                      : _buildCollapsedBadge(telemetry),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCollapsedBadge(TelemetryState telemetry) {
    return InkWell(
      onTap: () => setState(() => _isExpanded = true),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: telemetry.currentFps >= 55.0
                  ? const Color(0xFF10B981)
                  : const Color(0xFFF59E0B),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${telemetry.currentFps.toStringAsFixed(0)} FPS',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.tune, color: Colors.white70, size: 14),
        ],
      ),
    );
  }

  Widget _buildExpandedHud(TelemetryState telemetry) {
    final fpsColor = telemetry.currentFps >= 55.0
        ? const Color(0xFF10B981)
        : (telemetry.currentFps >= 40.0 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: fpsColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'WORLD ENGINE HUD',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(width: 16),
            InkWell(
              onTap: () => setState(() => _isExpanded = false),
              child: const Icon(Icons.remove, color: Colors.white70, size: 16),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () => setState(() => _isVisible = false),
              child: const Icon(Icons.close, color: Colors.white54, size: 16),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMetricItem('FPS', telemetry.currentFps.toStringAsFixed(1), fpsColor),
            const SizedBox(width: 12),
            _buildMetricItem('BUILD', '${telemetry.avgBuildMs.toStringAsFixed(1)}ms', Colors.white),
            const SizedBox(width: 12),
            _buildMetricItem('RASTER', '${telemetry.avgRasterMs.toStringAsFixed(1)}ms', Colors.white),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMetricItem('RAM', '${telemetry.memoryMb.toStringAsFixed(0)} MB', const Color(0xFF38BDF8)),
            const SizedBox(width: 12),
            _buildMetricItem('LATENCY', '${telemetry.networkLatencyMs.toStringAsFixed(0)}ms', const Color(0xFFA78BFA)),
            const SizedBox(width: 12),
            _buildMetricItem('DROPS', '${telemetry.droppedFrames}', telemetry.droppedFrames > 0 ? const Color(0xFFF59E0B) : Colors.white70),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
