import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../camera/camera_state.dart';
import '../coordinates/world_coordinate.dart';

enum LandmarkType {
  sacredStone,     // Marco de pedra com petroglifo solar
  coastalTreaty,   // Marco do Armistício de Iperoig
  tribalFort,      // Entrincheiramento da Confederação dos Tamoios
  brazilwoodStack, // Entreposto de toras de pau-brasil
  mountainOverlook,// Mirante ancestral da serra
}

/// Represents a physical landmark grounded directly in the 3D game world.
class HistoricalLandmark {
  final String id;
  final String title;
  final String subtitle;
  final String historicalLore;
  final WorldCoordinate coordinate;
  final LandmarkType type;
  final String epochId;

  const HistoricalLandmark({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.historicalLore,
    required this.coordinate,
    required this.type,
    required this.epochId,
  });

  static const List<HistoricalLandmark> canonicalLandmarks = [
    HistoricalLandmark(
      id: 'landmark_pedra_peabiru',
      title: 'Itá-Kûara do Peabiru',
      subtitle: 'Marco Solar Ancestral',
      historicalLore: 'Monólito sagrado de granito entalhado com grafismos astronômicos que orientavam os viajantes transcontinentais do Peabiru rumo aos Andes.',
      coordinate: WorldCoordinate(5180, 5220),
      type: LandmarkType.sacredStone,
      epochId: 'pre1500',
    ),
    HistoricalLandmark(
      id: 'landmark_armisticio_iperoig',
      title: 'Mirante da Paz de Iperoig',
      subtitle: 'Tratado de 1563',
      historicalLore: 'Local na praia onde o Grande Cacique Cunhambebe e o Padre Anchieta selaram as conferências de paz que suspenderam os ataques da Confederação dos Tamoios.',
      coordinate: WorldCoordinate(5820, 5320),
      type: LandmarkType.coastalTreaty,
      epochId: 'epoch1554',
    ),
    HistoricalLandmark(
      id: 'landmark_forte_guanabara',
      title: 'Paliçada de Uruçumirim',
      subtitle: 'Bastião Tupinambá & Villegagnon',
      historicalLore: 'Fortificação defensiva erguida pelos Tupinambás da Guanabara sob liderança de Aimberê durante o confronto contra as forças coloniais portuguesas.',
      coordinate: WorldCoordinate(6720, 4820),
      type: LandmarkType.tribalFort,
      epochId: 'epoch1555',
    ),
    HistoricalLandmark(
      id: 'landmark_feitoria_pau_brasil',
      title: 'Feitoria de Mapeg',
      subtitle: 'Entreposto de Ibirapitanga',
      historicalLore: 'Primeiro grande ponto de escambo e guarda de toras de pau-brasil (Ibirapitanga) operado por indígenas Tupinambás e navegadores franceses em Cabo Frio.',
      coordinate: WorldCoordinate(7220, 4580),
      type: LandmarkType.brazilwoodStack,
      epochId: 'epoch1532',
    ),
    HistoricalLandmark(
      id: 'landmark_mirante_paranapiacaba',
      title: 'Mirante de Paranapiacaba',
      subtitle: 'Vista do Grande Mar',
      historicalLore: 'Ponto cimeiro da escarpa da Serra do Mar de onde os sentinelas indígenas vigiavam as fumaças de sinalização e as movimentações entre o litoral e o planalto.',
      coordinate: WorldCoordinate(5100, 5520),
      type: LandmarkType.mountainOverlook,
      epochId: 'pre1500',
    ),
  ];

  /// Renders the physical landmark directly in screen coordinates.
  void render({
    required Canvas canvas,
    required CameraState camera,
    required Size size,
    required double animationTime,
    required bool isHovered,
  }) {
    final screenPt = coordinate.toScreen(
      cameraX: camera.x,
      cameraY: camera.y,
      zoom: camera.zoom,
      screenSize: size,
    );

    final zoom = camera.zoom;
    final r = (16.0 * zoom).clamp(8.0, 36.0);

    // 1. Projected Ground Shadow
    final shadowPaint = Paint()
      ..color = const Color(0xFF140D07).withValues(alpha: 0.38)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: screenPt + Offset(r * 0.45, r * 0.35), width: r * 1.5, height: r * 0.8),
      shadowPaint,
    );

    // 2. Physical Structure Rendering
    switch (type) {
      case LandmarkType.sacredStone:
        _renderSacredStone(canvas, screenPt, r, zoom);
        break;
      case LandmarkType.coastalTreaty:
        _renderTreatyMarker(canvas, screenPt, r, zoom);
        break;
      case LandmarkType.tribalFort:
        _renderTribalFort(canvas, screenPt, r, zoom);
        break;
      case LandmarkType.brazilwoodStack:
        _renderBrazilwoodStack(canvas, screenPt, r, zoom);
        break;
      case LandmarkType.mountainOverlook:
        _renderOverlook(canvas, screenPt, r, zoom);
        break;
    }

    // 3. Subtle Atmospheric Pulse Indicator
    final pulse = 0.85 + 0.15 * math.sin(animationTime * 3.5);
    final indicatorPaint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.65 * pulse)
      ..strokeWidth = (1.5 * zoom).clamp(1.0, 3.0)
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(screenPt - Offset(0, r * 1.3), 5.0 * zoom, indicatorPaint);
  }

  void _renderSacredStone(Canvas canvas, Offset pt, double r, double zoom) {
    final stonePath = Path()
      ..moveTo(pt.dx - r * 0.5, pt.dy + r * 0.2)
      ..lineTo(pt.dx - r * 0.3, pt.dy - r * 1.1)
      ..lineTo(pt.dx + r * 0.4, pt.dy - r * 1.0)
      ..lineTo(pt.dx + r * 0.6, pt.dy + r * 0.2)
      ..close();

    final stonePaint = Paint()
      ..color = const Color(0xFF6B7280)
      ..style = PaintingStyle.fill;
    canvas.drawPath(stonePath, stonePaint);

    // Sunlit edge
    final edgePaint = Paint()
      ..color = const Color(0xFF9CA3AF)
      ..strokeWidth = 1.5 * zoom
      ..style = PaintingStyle.stroke;
    canvas.drawPath(stonePath, edgePaint);

    // Sun glyph engraving
    final glyphPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 1.2 * zoom
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(pt - Offset(0, r * 0.5), r * 0.22, glyphPaint);
  }

  void _renderTreatyMarker(Canvas canvas, Offset pt, double r, double zoom) {
    // Cross/Peace wooden monument
    final postPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 3.0 * zoom
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(pt + Offset(0, r * 0.2), pt - Offset(0, r * 1.2), postPaint);
    canvas.drawLine(pt - Offset(r * 0.4, r * 0.8), pt - Offset(-r * 0.4, r * 0.8), postPaint);
  }

  void _renderTribalFort(Canvas canvas, Offset pt, double r, double zoom) {
    // Wooden watchtower/palisade bastion
    final baseRect = Rect.fromCenter(center: pt - Offset(0, r * 0.4), width: r * 1.2, height: r * 0.9);
    final fortPaint = Paint()
      ..color = const Color(0xFF4E342E)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(baseRect, Radius.circular(r * 0.2)), fortPaint);
  }

  void _renderBrazilwoodStack(Canvas canvas, Offset pt, double r, double zoom) {
    // Piled red logs
    final logPaint = Paint()
      ..color = const Color(0xFF8B2500)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: pt - Offset(0, r * 0.2), width: r * 1.4, height: r * 0.4),
        Radius.circular(r * 0.15),
      ),
      logPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: pt - Offset(0, r * 0.5), width: r * 1.1, height: r * 0.35),
        Radius.circular(r * 0.15),
      ),
      logPaint,
    );
  }

  void _renderOverlook(Canvas canvas, Offset pt, double r, double zoom) {
    // High mountain cliff cairn
    final rockPaint = Paint()
      ..color = const Color(0xFF4B5563)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pt - Offset(0, r * 0.4), r * 0.6, rockPaint);
    canvas.drawCircle(pt - Offset(0, r * 0.8), r * 0.4, rockPaint);
  }
}
