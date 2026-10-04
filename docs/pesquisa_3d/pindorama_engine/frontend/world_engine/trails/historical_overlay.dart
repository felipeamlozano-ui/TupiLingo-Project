import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../camera/camera_state.dart';
import '../coordinates/world_coordinate.dart';

/// Supported historical alliance or territory overlay types (RFC-012C Patch 1 Chapter 8).
enum HistoricalOverlayType {
  confederacaoTamoios, // Military alliance between Ubatuba, Guanabara and Cabo Frio
  caminhoPeabiru,      // Transcontinental sacred road with Andean solar symbols
  linguaGeralPaulista, // Trade expansion corridor along the Tietê basin
  missoesJesuiticas,   // Missionary network along Piratininga and São Vicente
  territorioXingu,     // Alto Xingu ancestral sanctuary
  resistenciaPotiguara,// Potiguara territory and 1645 letters
  corredorRioNegro,    // Rio Negro and Nheengatu corridor
  francaAntartica,     // French-Tupinambá alliance
  alliance,            // General alliance
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
        HistoricalOverlay(
          id: 'overlay_franca_antartica',
          title: 'Baía de Guanabara & França Antártica',
          description: 'Enclave marítimo e diplomático onde Tupinambás e franceses ergueram aliança.',
          type: HistoricalOverlayType.francaAntartica,
          polygonPoints: [
            WorldCoordinate(6500, 4750),
            WorldCoordinate(6800, 4750),
            WorldCoordinate(6850, 5050),
            WorldCoordinate(6550, 5050),
          ],
          baseColor: Color(0xFF1E88E5), // Maritime blue
          epochId: 'epoch1555',
        ),
        HistoricalOverlay(
          id: 'overlay_alto_xingu',
          title: 'Território Sagrado do Alto Xingu',
          description: 'Santuário cultural milenar Kamaiurá de Morená e lago Ipavu.',
          type: HistoricalOverlayType.territorioXingu,
          polygonPoints: [
            WorldCoordinate(4800, 4400),
            WorldCoordinate(5500, 4400),
            WorldCoordinate(5500, 5100),
            WorldCoordinate(4800, 5100),
          ],
          baseColor: Color(0xFF43A047), // Emerald green
          epochId: 'pre1500',
        ),
        HistoricalOverlay(
          id: 'overlay_potiguara',
          title: 'Território de Resistência Potiguara',
          description: 'Bastião dos Potiguaras na Baía da Traição e berço das Cartas de 1645.',
          type: HistoricalOverlayType.resistenciaPotiguara,
          polygonPoints: [
            WorldCoordinate(8500, 2700),
            WorldCoordinate(9100, 2700),
            WorldCoordinate(9100, 3400),
            WorldCoordinate(8500, 3400),
          ],
          baseColor: Color(0xFFFB8C00), // Sunset orange
          epochId: 'epoch1567',
        ),
        HistoricalOverlay(
          id: 'overlay_rio_negro',
          title: 'Bacia Cultural do Rio Negro & Nheengatu',
          description: 'Capital viva da Língua Geral Amazônica em São Gabriel da Cachoeira.',
          type: HistoricalOverlayType.corredorRioNegro,
          polygonPoints: [
            WorldCoordinate(2600, 1800),
            WorldCoordinate(3600, 1800),
            WorldCoordinate(3700, 2600),
            WorldCoordinate(2700, 2600),
          ],
          baseColor: Color(0xFF8E24AA), // Royal purple
          epochId: 'atual',
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

    // 1. Semi-transparent subtle territory wash
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = baseColor.withValues(alpha: 0.06);
    canvas.drawPath(path, fillPaint);

    // 2. Vintage cartographic dashed boundary
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (1.5 * camera.zoom).clamp(1.0, 3.0)
      ..strokeCap = StrokeCap.round
      ..color = baseColor.withValues(alpha: 0.35);

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      const dashWidth = 8.0;
      const dashSpace = 6.0;
      while (distance < metric.length) {
        final len = math.min(dashWidth, metric.length - distance);
        final extract = metric.extractPath(distance, distance + len);
        canvas.drawPath(extract, borderPaint);
        distance += dashWidth + dashSpace;
      }
    }
  }
}
