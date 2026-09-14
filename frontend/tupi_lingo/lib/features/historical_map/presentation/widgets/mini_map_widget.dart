import 'package:flutter/material.dart';
import '../../../../core/world_engine/camera/camera_state.dart';
import '../../../../core/world_engine/coordinates/world_coordinate.dart';
import '../../../../core/world_engine/villages/village_node.dart';

/// Circular radar mini-map displaying continuous Pindorama world space and camera frustum.
class MiniMapWidget extends StatelessWidget {
  final CameraState camera;
  final List<VillageNode> villages;
  final ValueChanged<WorldCoordinate>? onCoordinateTapped;
  final double size;

  const MiniMapWidget({
    super.key,
    required this.camera,
    required this.villages,
    this.onCoordinateTapped,
    this.size = 114.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xDD0D1B1E),
        border: Border.all(
          color: const Color(0x66E5A93C),
          width: 2.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 12.0,
            spreadRadius: 2.0,
          ),
        ],
      ),
      child: ClipOval(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final local = details.localPosition;
            final worldX = (local.dx / size) * CameraState.worldSize;
            final worldY = (local.dy / size) * CameraState.worldSize;
            onCoordinateTapped?.call(
              WorldCoordinate(worldX, worldY),
            );
          },
          child: CustomPaint(
            size: Size(size, size),
            painter: _MiniMapPainter(
              camera: camera,
              villages: villages,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  final CameraState camera;
  final List<VillageNode> villages;

  _MiniMapPainter({
    required this.camera,
    required this.villages,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / CameraState.worldSize;

    // 1. Landmass & coast indicator
    final oceanPaint = Paint()..color = const Color(0xFF0B212B);
    final oceanRect = Rect.fromPoints(
      Offset(5800 * scale, 5800 * scale),
      Offset(size.width, size.height),
    );
    canvas.drawRect(oceanRect, oceanPaint);

    // 2. Village blips
    final villagePaint = Paint()..style = PaintingStyle.fill;
    for (final v in villages) {
      if (v.stage == VillageEvolutionStage.oculta) continue;

      final px = v.coordinate.x * scale;
      final py = v.coordinate.y * scale;

      villagePaint.color = switch (v.stage) {
        VillageEvolutionStage.descoberta => const Color(0xFF8D6E63),
        VillageEvolutionStage.explorada => const Color(0xFF4CAF50),
        VillageEvolutionStage.dominada => const Color(0xFFFFB300),
        VillageEvolutionStage.historica => const Color(0xFFAB47BC),
        VillageEvolutionStage.oculta => Colors.transparent,
      };

      canvas.drawCircle(Offset(px, py), 2.5, villagePaint);
    }

    // 3. Camera Viewport Frustum Box
    // Estimate visible world bounds assuming standard screen aspect
    final halfW = (400.0 / camera.zoom) * scale;
    final halfH = (700.0 / camera.zoom) * scale;
    final cx = camera.x * scale;
    final cy = camera.y * scale;

    final frustumRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: halfW * 2.0,
      height: halfH * 2.0,
    );

    final frustumFill = Paint()
      ..color = const Color(0x22E5A93C)
      ..style = PaintingStyle.fill;
    canvas.drawRect(frustumRect, frustumFill);

    final frustumStroke = Paint()
      ..color = const Color(0xFFFFD54F)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(frustumRect, frustumStroke);

    // Center camera dot
    final centerDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 2.0, centerDotPaint);
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) {
    return oldDelegate.camera != camera || oldDelegate.villages != villages;
  }
}
