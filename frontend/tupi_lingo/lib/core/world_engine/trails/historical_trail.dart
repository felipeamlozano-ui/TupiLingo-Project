import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../coordinates/world_bounds.dart';
import '../coordinates/world_coordinate.dart';

/// Represents a historical indigenous trail across Pindorama (e.g., Peabiru).
class HistoricalTrail {
  final String id;
  final String name;
  final String description;
  final List<WorldCoordinate> points;
  final Color color;
  final double strokeWidth;
  final bool isDiscovered;
  final List<String> linkedVillageIds;

  const HistoricalTrail({
    required this.id,
    required this.name,
    required this.description,
    required this.points,
    this.color = const Color(0xFFC8963E),
    this.strokeWidth = 3.5,
    this.isDiscovered = true,
    this.linkedVillageIds = const [],
  });

  /// Computes the AABB boundary box enclosing this trail.
  WorldBounds get bounds {
    if (points.isEmpty) {
      return const WorldBounds(
        minX: 0,
        minY: 0,
        maxX: 0,
        maxY: 0,
      );
    }

    double minX = points.first.x;
    double maxX = points.first.x;
    double minY = points.first.y;
    double maxY = points.first.y;

    for (final pt in points) {
      minX = math.min(minX, pt.x);
      maxX = math.max(maxX, pt.x);
      minY = math.min(minY, pt.y);
      maxY = math.max(maxY, pt.y);
    }

    return WorldBounds(
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
    );
  }

  /// Transforms the world coordinates of this trail into a screen-space [Path].
  Path toScreenPath({
    required double cameraX,
    required double cameraY,
    required double zoom,
    required Size screenSize,
  }) {
    final path = Path();
    if (points.isEmpty) return path;

    final firstScreen = points.first.toScreen(
      cameraX: cameraX,
      cameraY: cameraY,
      zoom: zoom,
      screenSize: screenSize,
    );
    path.moveTo(firstScreen.dx, firstScreen.dy);

    for (int i = 1; i < points.length; i++) {
      final screenPt = points[i].toScreen(
        cameraX: cameraX,
        cameraY: cameraY,
        zoom: zoom,
        screenSize: screenSize,
      );
      path.lineTo(screenPt.dx, screenPt.dy);
    }

    return path;
  }

  /// Canonical historical trails across Pindorama
  static List<HistoricalTrail> get canonicalTrails => [
        const HistoricalTrail(
          id: 'peabiru_principal',
          name: 'Caminho do Peabiru',
          description: 'Trilha transcontinental ancestral conectando o litoral atlântico aos Andes.',
          strokeWidth: 4.0,
          color: Color(0xFFE5A93C),
          linkedVillageIds: ['sao_vicente', 'piratininga', 'tietepo'],
          points: [
            WorldCoordinate(5350, 5550), // São Vicente
            WorldCoordinate(5200, 5300), // Serra do Mar
            WorldCoordinate(5000, 5000), // Piratininga
            WorldCoordinate(4600, 4800), // Médio Tietê
            WorldCoordinate(4100, 4700), // Paranapanema
            WorldCoordinate(3500, 4650), // Interior do Paraná
            WorldCoordinate(2800, 4600), // Rumo a Guaíra
            WorldCoordinate(2100, 4550), // Rumo ao Chaco
          ],
        ),
        const HistoricalTrail(
          id: 'caminho_tupinamba_litoral',
          name: 'Trilha Litorânea dos Tupinambás',
          description: 'Rota litorânea navegável e terrestre entre Ubatuba, Guanabara e Cabo Frio.',
          strokeWidth: 3.0,
          color: Color(0xFF64B5F6),
          linkedVillageIds: ['ubatuba', 'guanabara', 'cabo_frio'],
          points: [
            WorldCoordinate(5350, 5550), // São Vicente
            WorldCoordinate(5700, 5350), // Ilhabela / Ubatuba
            WorldCoordinate(6150, 5100), // Angra / Paraty
            WorldCoordinate(6600, 4850), // Guanabara (Karióka)
            WorldCoordinate(7100, 4600), // Cabo Frio
          ],
        ),
        const HistoricalTrail(
          id: 'caminho_dos_tamoios',
          name: 'Caminho da Confederação dos Tamoios',
          description: 'Rede de aliança entre aldeias Tupinambá para resistir à colonização.',
          strokeWidth: 3.5,
          color: Color(0xFFEF5350),
          linkedVillageIds: ['guanabara', 'ubatuba'],
          points: [
            WorldCoordinate(5700, 5350),
            WorldCoordinate(6000, 5200),
            WorldCoordinate(6300, 5050),
            WorldCoordinate(6600, 4850),
          ],
        ),
        const HistoricalTrail(
          id: 'caminho_missoes_sul',
          name: 'Caminho das Missões Guaranis',
          description: 'Conexão ancestral guarani das bacias do Uruguai e Paraná.',
          strokeWidth: 3.0,
          color: Color(0xFF81C784),
          linkedVillageIds: ['sete_povos', 'tape'],
          points: [
            WorldCoordinate(2800, 4600),
            WorldCoordinate(2900, 5600),
            WorldCoordinate(3100, 6500),
            WorldCoordinate(3200, 7400),
          ],
        ),
      ];
}
