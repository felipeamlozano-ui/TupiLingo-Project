import 'package:flutter/material.dart';
import '../camera/camera_state.dart';
import '../coordinates/world_coordinate.dart';

/// Supported historical alliance or territory overlay types (RFC-012C Patch 1 Chapter 8).
enum HistoricalOverlayType {
  confederacaoTamoios, // Military alliance between Ubatuba, Guanabara and Cabo Frio
  caminhoPeabiru,      // Transcontinental sacred road with Andean solar symbols
  linguaGeralPaulista, // Trade expansion corridor along the Tietê basin
  missoesJesuiticas,   // Missionary network along Piratininga and São Vicente
}

/// Dynamic historical overlay representing alliances, expansion borders, and events.
class HistoricalOverlay {
  final String id;
  final String title;
  final String description;
  final HistoricalOverlayType type;
  final List<WorldCoordinate> polygonPoints;
  final Color baseColor;
  final String epochId;

  const HistoricalOverlay({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.polygonPoints,
    required this.baseColor,
    required this.epochId,
  });

  /// Canonical historical overlays across Pindorama
  static List<HistoricalOverlay> get canonicalOverlays => const [
        HistoricalOverlay(
          id: 'overlay_tamoios',
          title: 'Confederação dos Tamoios',
          description: 'Pacto de defesa militar unindo Tupinambás contra a escravização colonial.',
          type: HistoricalOverlayType.confederacaoTamoios,
          polygonPoints: [
            WorldCoordinate(5700, 5350), // Ubatuba
            WorldCoordinate(6600, 4850), // Guanabara
            WorldCoordinate(7100, 4600), // Cabo Frio
            WorldCoordinate(6800, 4400),
            WorldCoordinate(5900, 5000),
          ],
          baseColor: Color(0xFFE53935), // Fiery red
          epochId: 'epoch1567',
        ),
        HistoricalOverlay(
          id: 'overlay_peabiru',
          title: 'Rede Ancestral do Peabiru',
          description: 'Caminho sagrado transcontinental que conectava o litoral atlântico aos Andes.',
          type: HistoricalOverlayType.caminhoPeabiru,
          polygonPoints: [
            WorldCoordinate(4000, 5600),
            WorldCoordinate(4800, 5200),
            WorldCoordinate(5350, 5550), // São Vicente
            WorldCoordinate(5000, 5000), // Piratininga
          ],
          baseColor: Color(0xFFFFB300), // Sacred golden amber
          epochId: 'pre1500',
        ),
        HistoricalOverlay(
          id: 'overlay_lingua_geral',
          title: 'Bacia da Língua Geral Paulista',
          description: 'Corredor hidrográfico do Tietê onde o Tupi se consolidou como língua comum do sertão.',
          type: HistoricalOverlayType.linguaGeralPaulista,
          polygonPoints: [
            WorldCoordinate(4500, 4800),
            WorldCoordinate(5000, 5000),
            WorldCoordinate(5400, 5100),
            WorldCoordinate(5200, 4700),
          ],
          baseColor: Color(0xFF00897B), // Deep teal
          epochId: 'epoch1554',
        ),
      ];

  /// Renders glowing alliance perimeter on canvas
  void render({
    required Canvas canvas,
    required CameraState camera,
    required Size size,
    required double animationTime,
  }) {
    if (polygonPoints.length < 3) return;

    final path = Path();
    for (int i = 0; i < polygonPoints.length; i++) {
      final screenPt = polygonPoints[i].toScreen(
        cameraX: camera.x,
        cameraY: camera.y,
        zoom: camera.zoom,
        screenSize: size,
      );
      if (i == 0) {
        path.moveTo(screenPt.dx, screenPt.dy);
      } else {
        path.lineTo(screenPt.dx, screenPt.dy);
      }
    }
    path.close();

    // 1. Semi-transparent territory wash
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = baseColor.withValues(alpha: 0.12);
    canvas.drawPath(path, fillPaint);

    // 2. Glowing animated border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (2.5 * camera.zoom).clamp(1.5, 5.0)
      ..strokeCap = StrokeCap.round
      ..color = baseColor.withValues(alpha: 0.75);

    canvas.drawPath(path, borderPaint);
  }
}
