import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../shared/floating_toolbar.dart';

/// Canvas visual interativo para edição de mundo com pan & zoom infinito (RFC-013 Capítulo 19).
class WorldBuilderCanvas extends StatefulWidget {
  final TransformationController transformationController;
  final WorldBuilderTool activeTool;
  final bool showFogPreview;
  final double fogOpacity;
  final Color fogColor;
  final List<Map<String, dynamic>> territories;
  final List<Map<String, dynamic>> villages;
  final List<Map<String, dynamic>> rivers;
  final List<Map<String, dynamic>> trails;
  final List<Map<String, dynamic>> quests;
  final Map<String, dynamic>? selectedEntity;
  final Map<String, dynamic>? connectionStartEntity;
  final String connectionStartType;
  final bool layerTerritories;
  final bool layerVillages;
  final bool layerRivers;
  final bool layerTrails;
  final bool layerQuests;
  final bool layerGrid;
  final bool layerLabels;
  final void Function(Map<String, dynamic> entity, String type) onSelectEntity;
  final void Function(Offset worldPosition) onCanvasTap;
  final void Function(Map<String, dynamic> entity, String type) onEntityTapForConnection;
  final void Function(Map<String, dynamic> entity, Offset delta)? onEntityDrag;

  const WorldBuilderCanvas({
    super.key,
    required this.transformationController,
    required this.activeTool,
    required this.showFogPreview,
    this.fogOpacity = 0.85,
    this.fogColor = const Color(0xFF060B15),
    required this.territories,
    required this.villages,
    required this.rivers,
    required this.trails,
    this.quests = const [],
    required this.selectedEntity,
    this.connectionStartEntity,
    this.connectionStartType = '',
    this.layerTerritories = true,
    this.layerVillages = true,
    this.layerRivers = true,
    this.layerTrails = true,
    this.layerQuests = true,
    this.layerGrid = true,
    this.layerLabels = true,
    required this.onSelectEntity,
    required this.onCanvasTap,
    required this.onEntityTapForConnection,
    this.onEntityDrag,
  });

  @override
  State<WorldBuilderCanvas> createState() => _WorldBuilderCanvasState();
}

class _WorldBuilderCanvasState extends State<WorldBuilderCanvas> {
  Offset? _getSelectedEntityCenter() {
    if (widget.selectedEntity == null) return null;
    final ent = widget.selectedEntity!;

    // 1. Aldeias e Quests
    if (ent.containsKey('x') && ent.containsKey('y')) {
      final x = (ent['x'] as num?)?.toDouble() ?? 0.0;
      final y = (ent['y'] as num?)?.toDouble() ?? 0.0;
      return Offset(x, y);
    }
    // 2. Territórios
    if (ent.containsKey('center_x') && ent.containsKey('center_y')) {
      final cx = (ent['center_x'] as num?)?.toDouble() ?? 2000.0;
      final cy = (ent['center_y'] as num?)?.toDouble() ?? 2000.0;
      return Offset(cx, cy);
    }
    // 3. Rios
    if (ent.containsKey('bezier_points') && ent['bezier_points'] is List) {
      final pts = ent['bezier_points'] as List;
      if (pts.isNotEmpty) {
        final mid = pts[pts.length ~/ 2] as List;
        return Offset((mid[0] as num).toDouble(), (mid[1] as num).toDouble());
      }
    }
    // 4. Trilhas
    if (ent.containsKey('waypoints') && ent['waypoints'] is List) {
      final wps = ent['waypoints'] as List;
      if (wps.isNotEmpty) {
        final mid = wps[wps.length ~/ 2] as List;
        return Offset((mid[0] as num).toDouble(), (mid[1] as num).toDouble());
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const worldSize = Size(4000, 4000);
    final entityCenter = widget.activeTool == WorldBuilderTool.select ? _getSelectedEntityCenter() : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        return InteractiveViewer(
          transformationController: widget.transformationController,
          boundaryMargin: const EdgeInsets.all(2000),
          minScale: 0.3,
          maxScale: 2.8,
          panEnabled: true,
          interactionEndFrictionCoefficient: 0.00004,
          constrained: false,
          child: SizedBox(
            width: worldSize.width,
            height: worldSize.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Camada do mapa principal: responde a toque para seleção e permite pan/zoom sem restrição
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final localPos = details.localPosition;
                    _handleCanvasTap(localPos);
                  },
                  child: CustomPaint(
                    size: worldSize,
                    painter: WorldBuilderPainter(
                      territories: widget.territories,
                      villages: widget.villages,
                      rivers: widget.rivers,
                      trails: widget.trails,
                      quests: widget.quests,
                      selectedEntity: widget.selectedEntity,
                      connectionStartEntity: widget.connectionStartEntity,
                      connectionStartType: widget.connectionStartType,
                      showFogPreview: widget.showFogPreview,
                      fogOpacity: widget.fogOpacity,
                      fogColor: widget.fogColor,
                      activeTool: widget.activeTool,
                      layerTerritories: widget.layerTerritories,
                      layerVillages: widget.layerVillages,
                      layerRivers: widget.layerRivers,
                      layerTrails: widget.layerTrails,
                      layerQuests: widget.layerQuests,
                      layerGrid: widget.layerGrid,
                      layerLabels: widget.layerLabels,
                    ),
                  ),
                ),

                // Handle de arraste interativo exclusivo posicionado sobre o elemento selecionado
                if (entityCenter != null && widget.onEntityDrag != null && widget.selectedEntity != null)
                  Positioned(
                    left: entityCenter.dx - 22,
                    top: entityCenter.dy - 22,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) {
                        if (widget.selectedEntity != null && widget.onEntityDrag != null) {
                          widget.onEntityDrag!(widget.selectedEntity!, details.delta);
                        }
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFD08A45).withValues(alpha: 0.3),
                          border: Border.all(color: const Color(0xFFD08A45), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD08A45).withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.open_with_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSq == 0) return (p - a).distance;
    final t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lengthSq;
    final clampedT = t.clamp(0.0, 1.0);
    final projection = Offset(a.dx + clampedT * ab.dx, a.dy + clampedT * ab.dy);
    return (p - projection).distance;
  }

  void _handleCanvasTap(Offset pos) {
    // 1. MODO CONEXÃO UNIVERSAL (Ligar Aldeias, Rios, Territórios ou Quests)
    if (widget.activeTool == WorldBuilderTool.trail) {
      // (a) Checa Aldeias
      for (final village in widget.villages) {
        final vx = (village['x'] as num?)?.toDouble() ?? 0.0;
        final vy = (village['y'] as num?)?.toDouble() ?? 0.0;
        if ((Offset(vx, vy) - pos).distance <= 34.0) {
          widget.onEntityTapForConnection(village, 'Aldeia');
          return;
        }
      }

      // (b) Checa Quests / POIs
      for (final quest in widget.quests) {
        final qx = (quest['x'] as num?)?.toDouble() ?? 0.0;
        final qy = (quest['y'] as num?)?.toDouble() ?? 0.0;
        if ((Offset(qx, qy) - pos).distance <= 34.0) {
          widget.onEntityTapForConnection(quest, 'Ponto de Interesse / Quest');
          return;
        }
      }

      // (c) Checa Rios
      for (final river in widget.rivers) {
        final pts = (river['bezier_points'] as List?) ?? [];
        for (var i = 0; i < pts.length - 1; i++) {
          final p1 = Offset((pts[i][0] as num).toDouble(), (pts[i][1] as num).toDouble());
          final p2 = Offset((pts[i + 1][0] as num).toDouble(), (pts[i + 1][1] as num).toDouble());
          if (_distanceToSegment(pos, p1, p2) <= 30.0) {
            widget.onEntityTapForConnection(river, 'Rio');
            return;
          }
        }
      }

      // (d) Checa Territórios
      for (final territory in widget.territories) {
        final cx = (territory['center_x'] as num?)?.toDouble() ?? 2000.0;
        final cy = (territory['center_y'] as num?)?.toDouble() ?? 2000.0;
        if ((Offset(cx, cy) - pos).distance <= 220.0) {
          widget.onEntityTapForConnection(territory, 'Território');
          return;
        }
      }

      // Se clicou no vazio, passa o tap para o canvas (para instruções ou cancelar)
      widget.onCanvasTap(pos);
      return;
    }

    // 2. MODOS DE ADIÇÃO (Aldeia, Rio, Território, Quest):
    if (widget.activeTool != WorldBuilderTool.select) {
      widget.onCanvasTap(pos);
      return;
    }

    // 3. MODO DE SELEÇÃO & INSPEÇÃO:
    // (a) Hit-test em aldeias (raio 26px)
    for (final village in widget.villages) {
      final vx = (village['x'] as num?)?.toDouble() ?? 0.0;
      final vy = (village['y'] as num?)?.toDouble() ?? 0.0;
      if ((Offset(vx, vy) - pos).distance <= 26.0) {
        widget.onSelectEntity(village, 'Aldeia');
        return;
      }
    }

    // (b) Hit-test em Quests / POIs (raio 26px)
    for (final quest in widget.quests) {
      final qx = (quest['x'] as num?)?.toDouble() ?? 0.0;
      final qy = (quest['y'] as num?)?.toDouble() ?? 0.0;
      if ((Offset(qx, qy) - pos).distance <= 26.0) {
        widget.onSelectEntity(quest, 'Ponto de Interesse / Quest');
        return;
      }
    }

    // (c) Hit-test em Trilhas / Conexões (distância <= 22px)
    for (final trail in widget.trails) {
      final wps = (trail['waypoints'] as List?) ?? [];
      for (var i = 0; i < wps.length - 1; i++) {
        final p1 = Offset((wps[i][0] as num).toDouble(), (wps[i][1] as num).toDouble());
        final p2 = Offset((wps[i + 1][0] as num).toDouble(), (wps[i + 1][1] as num).toDouble());
        if (_distanceToSegment(pos, p1, p2) <= 22.0) {
          widget.onSelectEntity(trail, 'Trilha Histórica');
          return;
        }
      }
    }

    // (d) Hit-test em Rios (distância <= 26px)
    for (final river in widget.rivers) {
      final pts = (river['bezier_points'] as List?) ?? [];
      for (var i = 0; i < pts.length - 1; i++) {
        final p1 = Offset((pts[i][0] as num).toDouble(), (pts[i][1] as num).toDouble());
        final p2 = Offset((pts[i + 1][0] as num).toDouble(), (pts[i + 1][1] as num).toDouble());
        if (_distanceToSegment(pos, p1, p2) <= 26.0) {
          widget.onSelectEntity(river, 'Rio');
          return;
        }
      }
    }

    // (e) Hit-test em Territórios (raio <= 220px)
    for (final territory in widget.territories) {
      final poly = (territory['polygon_coordinates'] as List?) ?? [];
      if (poly.isNotEmpty) {
        final cx = (territory['center_x'] as num?)?.toDouble() ?? 2000.0;
        final cy = (territory['center_y'] as num?)?.toDouble() ?? 2000.0;
        if ((Offset(cx, cy) - pos).distance <= 220.0) {
          widget.onSelectEntity(territory, 'Território');
          return;
        }
      }
    }

    // (f) Clicou em área vazia: limpa seleção e fecha painel
    widget.onCanvasTap(pos);
  }
}

/// Painter gráfico de alta fidelidade para o World Builder Canvas com personalização irrestrita
class WorldBuilderPainter extends CustomPainter {
  final List<Map<String, dynamic>> territories;
  final List<Map<String, dynamic>> villages;
  final List<Map<String, dynamic>> rivers;
  final List<Map<String, dynamic>> trails;
  final List<Map<String, dynamic>> quests;
  final Map<String, dynamic>? selectedEntity;
  final Map<String, dynamic>? connectionStartEntity;
  final String connectionStartType;
  final bool showFogPreview;
  final double fogOpacity;
  final Color fogColor;
  final WorldBuilderTool activeTool;
  final bool layerTerritories;
  final bool layerVillages;
  final bool layerRivers;
  final bool layerTrails;
  final bool layerQuests;
  final bool layerGrid;
  final bool layerLabels;

  WorldBuilderPainter({
    required this.territories,
    required this.villages,
    required this.rivers,
    required this.trails,
    this.quests = const [],
    required this.selectedEntity,
    this.connectionStartEntity,
    this.connectionStartType = '',
    required this.showFogPreview,
    this.fogOpacity = 0.85,
    this.fogColor = const Color(0xFF060B15),
    required this.activeTool,
    this.layerTerritories = true,
    this.layerVillages = true,
    this.layerRivers = true,
    this.layerTrails = true,
    this.layerQuests = true,
    this.layerGrid = true,
    this.layerLabels = true,
  });

  Color _parseHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final val = int.tryParse('FF$clean', radix: 16);
      if (val != null) return Color(val);
    } else if (clean.length == 8) {
      final val = int.tryParse(clean, radix: 16);
      if (val != null) return Color(val);
    }
    return fallback;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fundo do Mapa Antigo
    final bgPaint = Paint()..color = const Color(0xFF060B15);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 2. Grid Cartográfico
    if (layerGrid) {
      _drawGrid(canvas, size);
    }

    // 3. Territórios com Polígonos
    if (layerTerritories) {
      _drawTerritories(canvas);
    }

    // 4. Rios Bézier com Vazão e Estilo Personalizados
    if (layerRivers) {
      _drawRivers(canvas);
    }

    // 5. Trilhas e Conexões Universais
    if (layerTrails) {
      _drawTrails(canvas);
    }

    // 6. Missões / Quests com Ícones Temáticos
    if (layerQuests) {
      _drawQuests(canvas);
    }

    // 7. Aldeias com Arquiteturas Étnicas Customizadas
    if (layerVillages) {
      _drawVillages(canvas);
    }

    // 8. Destaque do Nó de Origem (Conexão Universal)
    if (connectionStartEntity != null) {
      _drawConnectionOriginHighlight(canvas);
    }

    // 9. Simulação de Fog of War Personalizada
    if (showFogPreview) {
      _drawFogPreview(canvas, size);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.35)
      ..strokeWidth = 1.0;

    final majorGridPaint = Paint()
      ..color = const Color(0xFF334155).withValues(alpha: 0.5)
      ..strokeWidth = 1.5;

    const step = 100.0;
    const majorStep = 500.0;

    for (var x = 0.0; x < size.width; x += step) {
      final isMajor = (x % majorStep) == 0;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), isMajor ? majorGridPaint : gridPaint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      final isMajor = (y % majorStep) == 0;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), isMajor ? majorGridPaint : gridPaint);
    }
  }

  void _drawTerritories(Canvas canvas) {
    for (final territory in territories) {
      final isSelected = selectedEntity != null && selectedEntity!['id'] == territory['id'];
      final polyData = (territory['polygon_coordinates'] as List?) ?? [];
      final biomeColor = _getBiomeColor(territory['biome'] as String? ?? 'Mata Atlântica');

      if (polyData.length >= 3) {
        final path = Path();
        final first = polyData.first as List;
        path.moveTo((first[0] as num).toDouble(), (first[1] as num).toDouble());

        for (var i = 1; i < polyData.length; i++) {
          final pt = polyData[i] as List;
          path.lineTo((pt[0] as num).toDouble(), (pt[1] as num).toDouble());
        }
        path.close();

        final fillOpacity = ((territory['fill_opacity'] as num?)?.toDouble() ?? 0.2).clamp(0.05, 0.7);
        final borderWidth = ((territory['border_width'] as num?)?.toDouble() ?? 1.8).clamp(1.0, 8.0);

        final fillPaint = Paint()
          ..color = biomeColor.withValues(alpha: isSelected ? (fillOpacity + 0.15).clamp(0.1, 0.85) : fillOpacity)
          ..style = PaintingStyle.fill;
        canvas.drawPath(path, fillPaint);

        final strokePaint = Paint()
          ..color = isSelected ? const Color(0xFF10B981) : biomeColor.withValues(alpha: 0.75)
          ..strokeWidth = isSelected ? borderWidth + 1.5 : borderWidth
          ..style = PaintingStyle.stroke;
        canvas.drawPath(path, strokePaint);

        if (layerLabels) {
          final cx = (territory['center_x'] as num?)?.toDouble() ?? 2000.0;
          final cy = (territory['center_y'] as num?)?.toDouble() ?? 2000.0;
          final name = territory['name_tupi'] ?? territory['name'] ?? '';
          if (name.isNotEmpty) {
            final span = TextSpan(
              text: name.toUpperCase(),
              style: TextStyle(
                color: biomeColor.withValues(alpha: 0.65),
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 3.0,
              ),
            );
            final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
            tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
          }
        }
      }
    }
  }

  void _drawRivers(Canvas canvas) {
    for (final river in rivers) {
      final isSelected = selectedEntity != null && selectedEntity!['id'] == river['id'];
      final pts = (river['bezier_points'] as List?) ?? [];
      final isClosed = (river['is_closed'] == true) || (river['shape_preset'] == 'circle');
      if (pts.length >= 2) {
        final path = Path();
        final start = pts.first as List;
        path.moveTo((start[0] as num).toDouble(), (start[1] as num).toDouble());

        if (pts.length > 2) {
          for (var i = 0; i < pts.length - 1; i++) {
            final p0 = pts[i];
            final p1 = pts[i + 1];
            final midX = ((p0[0] as num).toDouble() + (p1[0] as num).toDouble()) / 2;
            final midY = ((p0[1] as num).toDouble() + (p1[1] as num).toDouble()) / 2;
            path.quadraticBezierTo((p0[0] as num).toDouble(), (p0[1] as num).toDouble(), midX, midY);
          }
          final last = pts.last as List;
          path.lineTo((last[0] as num).toDouble(), (last[1] as num).toDouble());
        } else {
          for (var i = 1; i < pts.length; i++) {
            final pt = pts[i] as List;
            path.lineTo((pt[0] as num).toDouble(), (pt[1] as num).toDouble());
          }
        }

        if (isClosed) {
          path.close();
        }

        final riverWidth = ((river['river_width'] as num?)?.toDouble() ?? 4.0).clamp(2.0, 24.0);
        final baseColor = _parseHex(river['water_color'] as String?, const Color(0xFF38BDF8));
        final opacity = ((river['water_opacity'] as num?)?.toDouble() ?? 0.85).clamp(0.2, 1.0);
        final flowStyle = (river['flow_style'] as String?) ?? 'solid';

        // Preenchimento de Lago / Corpo D'água Fechado
        if (isClosed) {
          final fillPaint = Paint()
            ..color = baseColor.withValues(alpha: (opacity * 0.35).clamp(0.1, 0.9))
            ..style = PaintingStyle.fill;
          canvas.drawPath(path, fillPaint);
        }

        // Glow de seleção
        if (isSelected) {
          final glowPaint = Paint()
            ..color = baseColor.withValues(alpha: 0.45)
            ..strokeWidth = riverWidth + 8.0
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;
          canvas.drawPath(path, glowPaint);
        }

        // Estilos de Linha do Rio
        if (flowStyle == 'dashed') {
          final riverPaint = Paint()
            ..color = (isSelected ? baseColor : baseColor.withValues(alpha: opacity))
            ..strokeWidth = riverWidth
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;

          for (var i = 0; i < pts.length - 1; i++) {
            final p1 = Offset((pts[i][0] as num).toDouble(), (pts[i][1] as num).toDouble());
            final p2 = Offset((pts[i + 1][0] as num).toDouble(), (pts[i + 1][1] as num).toDouble());
            final delta = p2 - p1;
            final dist = delta.distance;
            final dashCount = (dist / 14).floor().clamp(1, 40);
            for (var d = 0; d < dashCount; d += 2) {
              final t1 = d / dashCount;
              final t2 = ((d + 1) / dashCount).clamp(0.0, 1.0);
              canvas.drawLine(p1 + delta * t1, p1 + delta * t2, riverPaint);
            }
          }
        } else if (flowStyle == 'currents' || flowStyle == 'wave_particles') {
          final outerPaint = Paint()
            ..color = baseColor.withValues(alpha: opacity * 0.7)
            ..strokeWidth = riverWidth + 3.0
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;
          canvas.drawPath(path, outerPaint);

          final innerPaint = Paint()
            ..color = Colors.white.withValues(alpha: flowStyle == 'wave_particles' ? 0.95 : 0.8)
            ..strokeWidth = (riverWidth * 0.4).clamp(1.5, 5.0)
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;
          canvas.drawPath(path, innerPaint);
        } else {
          final riverPaint = Paint()
            ..color = (isSelected ? baseColor : baseColor.withValues(alpha: opacity))
            ..strokeWidth = riverWidth
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;
          canvas.drawPath(path, riverPaint);
        }

        // 3D-like Vector Handles: Vértices de controle quando o rio estiver selecionado
        if (isSelected) {
          final controlLinePaint = Paint()
            ..color = Colors.white.withValues(alpha: 0.35)
            ..strokeWidth = 1.0
            ..style = PaintingStyle.stroke;

          for (var i = 0; i < pts.length - 1; i++) {
            final p1 = Offset((pts[i][0] as num).toDouble(), (pts[i][1] as num).toDouble());
            final p2 = Offset((pts[i + 1][0] as num).toDouble(), (pts[i + 1][1] as num).toDouble());
            canvas.drawLine(p1, p2, controlLinePaint);
          }

          for (var i = 0; i < pts.length; i++) {
            final pt = Offset((pts[i][0] as num).toDouble(), (pts[i][1] as num).toDouble());
            canvas.drawCircle(pt, 7.0, Paint()..color = Colors.white);
            canvas.drawCircle(pt, 7.0, Paint()..color = baseColor..style = PaintingStyle.stroke..strokeWidth = 2.0);

            final tp = TextPainter(
              text: TextSpan(
                text: '${i + 1}',
                style: TextStyle(color: baseColor, fontSize: 8, fontWeight: FontWeight.bold),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            tp.paint(canvas, Offset(pt.dx - tp.width / 2, pt.dy - tp.height / 2));
          }
        }

        if (layerLabels && pts.isNotEmpty) {
          final mid = pts[pts.length ~/ 2] as List;
          final name = river['name_tupi'] ?? river['name'] ?? '';
          if (name.isNotEmpty) {
            final span = TextSpan(
              text: '≈ $name',
              style: TextStyle(
                color: baseColor,
                fontSize: 11,
                fontStyle: FontStyle.italic,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            );
            final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
            tp.paint(canvas, Offset((mid[0] as num).toDouble() + 6, (mid[1] as num).toDouble() - 14));
          }
        }
      }
    }
  }

  void _drawTrails(Canvas canvas) {
    for (final trail in trails) {
      final isSelected = selectedEntity != null && selectedEntity!['id'] == trail['id'];
      final wps = (trail['waypoints'] as List?) ?? [];
      if (wps.length >= 2) {
        final trailColor = _parseHex(trail['trail_color'] as String?, const Color(0xFFF59E0B));
        final trailWidth = ((trail['trail_width'] as num?)?.toDouble() ?? 2.5).clamp(1.5, 6.0);
        final trailStyle = (trail['trail_style'] as String?) ?? 'dotted';

        // Glow se selecionado
        if (isSelected) {
          final glowPaint = Paint()
            ..color = trailColor.withValues(alpha: 0.35)
            ..strokeWidth = trailWidth + 6.0
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;

          for (var i = 0; i < wps.length - 1; i++) {
            final p1 = Offset((wps[i][0] as num).toDouble(), (wps[i][1] as num).toDouble());
            final p2 = Offset((wps[i + 1][0] as num).toDouble(), (wps[i + 1][1] as num).toDouble());
            canvas.drawLine(p1, p2, glowPaint);
          }
        }

        final trailPaint = Paint()
          ..color = isSelected ? Colors.white : trailColor.withValues(alpha: 0.85)
          ..strokeWidth = trailWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        for (var i = 0; i < wps.length - 1; i++) {
          final o1 = Offset((wps[i][0] as num).toDouble(), (wps[i][1] as num).toDouble());
          final o2 = Offset((wps[i + 1][0] as num).toDouble(), (wps[i + 1][1] as num).toDouble());

          if (trailStyle == 'solid') {
            canvas.drawLine(o1, o2, trailPaint);
          } else if (trailStyle == 'dashed') {
            final delta = o2 - o1;
            final dist = delta.distance;
            final dashCount = (dist / 12).floor().clamp(1, 30);
            for (var d = 0; d < dashCount; d += 2) {
              final t1 = d / dashCount;
              final t2 = ((d + 1) / dashCount).clamp(0.0, 1.0);
              canvas.drawLine(o1 + delta * t1, o1 + delta * t2, trailPaint);
            }
          } else {
            // Pontilhado (Dotted)
            canvas.drawLine(o1, o2, trailPaint);
            final delta = o2 - o1;
            final count = (delta.distance / 16).floor().clamp(1, 25);
            for (var d = 0; d <= count; d++) {
              final pt = o1 + delta * (d / count);
              canvas.drawCircle(pt, trailWidth * 0.8, Paint()..color = trailColor);
            }
          }

          // Nós decorativos nas extremidades
          canvas.drawCircle(o1, trailWidth * 1.2, Paint()..color = trailColor);
          if (i == wps.length - 2) {
            canvas.drawCircle(o2, trailWidth * 1.2, Paint()..color = trailColor);
          }
        }

        if (layerLabels && wps.length >= 2) {
          final mid = wps[wps.length ~/ 2] as List;
          final name = trail['name_tupi'] ?? trail['name'] ?? '';
          if (name.isNotEmpty) {
            final span = TextSpan(
              text: '• $name',
              style: TextStyle(
                color: trailColor,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            );
            final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
            tp.paint(canvas, Offset((mid[0] as num).toDouble() + 6, (mid[1] as num).toDouble() - 10));
          }
        }
      }
    }
  }

  void _drawQuests(Canvas canvas) {
    for (final quest in quests) {
      final isSelected = selectedEntity != null && selectedEntity!['id'] == quest['id'];
      final x = (quest['x'] as num?)?.toDouble() ?? 2000.0;
      final y = (quest['y'] as num?)?.toDouble() ?? 2000.0;
      final pos = Offset(x, y);

      final markerColor = _parseHex(quest['marker_color'] as String?, const Color(0xFFEAB308));
      final iconKey = (quest['quest_icon'] as String?) ?? 'star';

      // Glow de Seleção
      if (isSelected) {
        canvas.drawCircle(
          pos,
          26,
          Paint()..color = markerColor.withValues(alpha: 0.4),
        );
      }

      // Losango Dourado Base do Marcador de Quest
      final questPath = Path()
        ..moveTo(pos.dx, pos.dy - 15)
        ..lineTo(pos.dx + 13, pos.dy)
        ..lineTo(pos.dx, pos.dy + 15)
        ..lineTo(pos.dx - 13, pos.dy)
        ..close();

      final questPaint = Paint()
        ..color = isSelected ? Colors.white : markerColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(questPath, questPaint);

      final borderPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.6)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawPath(questPath, borderPaint);

      // Ícone/Glifo interno personalizado
      _drawQuestIconGlyph(canvas, pos, iconKey, isSelected ? markerColor : Colors.black87);

      // Label do Nome
      if (layerLabels) {
        final name = quest['name_tupi'] ?? quest['name'] ?? 'Missão';
        final textSpan = TextSpan(
          text: '$name',
          style: TextStyle(
            color: markerColor,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(canvas, Offset(pos.dx - textPainter.width / 2, pos.dy + 18));
      }
    }
  }

  void _drawQuestIconGlyph(Canvas canvas, Offset pos, String iconKey, Color color) {
    final p = Paint()..color = color..style = PaintingStyle.fill;

    switch (iconKey) {
      case 'star':
        // Estrela de 4 pontas
        final star = Path()
          ..moveTo(pos.dx, pos.dy - 7)
          ..lineTo(pos.dx + 2, pos.dy - 2)
          ..lineTo(pos.dx + 7, pos.dy)
          ..lineTo(pos.dx + 2, pos.dy + 2)
          ..lineTo(pos.dx, pos.dy + 7)
          ..lineTo(pos.dx - 2, pos.dy + 2)
          ..lineTo(pos.dx - 7, pos.dy)
          ..lineTo(pos.dx - 2, pos.dy - 2)
          ..close();
        canvas.drawPath(star, p);
        break;

      case 'explore':
        // Bússola cruzada
        final strokeP = Paint()..color = color..strokeWidth = 2.0..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(pos.dx - 6, pos.dy), Offset(pos.dx + 6, pos.dy), strokeP);
        canvas.drawLine(Offset(pos.dx, pos.dy - 6), Offset(pos.dx, pos.dy + 6), strokeP);
        canvas.drawCircle(pos, 2, p);
        break;

      case 'relic':
        // Vaso / Urna Funerária / Relíquia
        final relic = Path()
          ..moveTo(pos.dx - 4, pos.dy - 5)
          ..lineTo(pos.dx + 4, pos.dy - 5)
          ..lineTo(pos.dx + 5, pos.dy + 1)
          ..lineTo(pos.dx + 3, pos.dy + 5)
          ..lineTo(pos.dx - 3, pos.dy + 5)
          ..lineTo(pos.dx - 5, pos.dy + 1)
          ..close();
        canvas.drawPath(relic, p);
        break;

      case 'fire':
        // Fogueira / Chama
        final flame = Path()
          ..moveTo(pos.dx, pos.dy - 6)
          ..quadraticBezierTo(pos.dx + 5, pos.dy - 1, pos.dx + 3, pos.dy + 4)
          ..quadraticBezierTo(pos.dx, pos.dy + 6, pos.dx - 3, pos.dy + 4)
          ..quadraticBezierTo(pos.dx - 5, pos.dy - 1, pos.dx, pos.dy - 6)
          ..close();
        canvas.drawPath(flame, p);
        break;

      case 'fish':
        // Peixe
        final fish = Path()
          ..moveTo(pos.dx - 5, pos.dy)
          ..quadraticBezierTo(pos.dx, pos.dy - 4, pos.dx + 4, pos.dy)
          ..quadraticBezierTo(pos.dx, pos.dy + 4, pos.dx - 5, pos.dy)
          ..lineTo(pos.dx - 7, pos.dy - 3)
          ..lineTo(pos.dx - 7, pos.dy + 3)
          ..close();
        canvas.drawPath(fish, p);
        break;

      case 'hunt':
        // Arco e Flecha
        final strokeP = Paint()..color = color..strokeWidth = 1.8..style = PaintingStyle.stroke;
        canvas.drawArc(Rect.fromCircle(center: pos, radius: 5), -math.pi / 2, math.pi, false, strokeP);
        canvas.drawLine(Offset(pos.dx - 4, pos.dy), Offset(pos.dx + 5, pos.dy), strokeP);
        break;

      case 'nature':
      default:
        // Ponto / Folha Sagrada
        canvas.drawCircle(pos, 3.5, p);
        break;
    }
  }

  void _drawVillages(Canvas canvas) {
    for (final village in villages) {
      final isSelected = selectedEntity != null && selectedEntity!['id'] == village['id'];
      final x = (village['x'] as num?)?.toDouble() ?? 2000.0;
      final y = (village['y'] as num?)?.toDouble() ?? 2000.0;
      final pos = Offset(x, y);

      final villageColor = _parseHex(village['village_color'] as String?, const Color(0xFFF59E0B));
      final villageStyle = (village['village_style'] as String?) ?? 'oca';
      final radius = ((village['village_radius'] as num?)?.toDouble() ?? 14.0).clamp(8.0, 50.0);
      final fireGlow = ((village['fire_glow_radius'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 60.0);
      final hasPalisade = village['has_palisade'] == true;

      // Brilho da Fogueira Sagrada
      if (fireGlow > 0) {
        final glowPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFF59E0B).withValues(alpha: 0.55),
              const Color(0xFFDC2626).withValues(alpha: 0.2),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: pos, radius: radius + fireGlow));
        canvas.drawCircle(pos, radius + fireGlow, glowPaint);
      }

      // Paliçada Defensiva Tribal
      if (hasPalisade) {
        final palisadeRadius = radius + 8.0;
        final postPaint = Paint()..color = const Color(0xFFD97706)..strokeWidth = 2.0;
        for (var i = 0; i < 12; i++) {
          final angle = (i * math.pi / 6);
          final p1 = pos + Offset(math.cos(angle) * (palisadeRadius - 2), math.sin(angle) * (palisadeRadius - 2));
          final p2 = pos + Offset(math.cos(angle) * (palisadeRadius + 4), math.sin(angle) * (palisadeRadius + 4));
          canvas.drawLine(p1, p2, postPaint);
        }
        canvas.drawCircle(pos, palisadeRadius, Paint()..color = const Color(0xFFB45309)..style = PaintingStyle.stroke..strokeWidth = 1.5);
      }

      // Glow de Seleção
      if (isSelected) {
        canvas.drawCircle(
          pos,
          radius + 12,
          Paint()..color = const Color(0xFF10B981).withValues(alpha: 0.4),
        );
      }

      // Desenho da Oca / Aldeia conforme o Estilo Arquitetônico Selecionado
      _drawVillageArchitecture(canvas, pos, villageStyle, villageColor, isSelected, radius);

      // Label do Nome
      if (layerLabels) {
        final name = village['name_tupi'] ?? village['name'] ?? 'Aldeia';
        final textSpan = TextSpan(
          text: name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(canvas, Offset(pos.dx - textPainter.width / 2, pos.dy + radius + 5));
      }
    }
  }

  void _drawVillageArchitecture(Canvas canvas, Offset pos, String style, Color color, bool isSelected, double radius) {
    final fillPaint = Paint()..color = color..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    switch (style) {
      case 'maloca':
        // Maloca alongada com teto curvo
        final rRect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: pos, width: radius * 2.2, height: radius * 1.1),
          Radius.circular(radius * 0.45),
        );
        canvas.drawRRect(rRect, fillPaint);
        canvas.drawRRect(rRect, strokePaint);
        canvas.drawLine(Offset(pos.dx - radius * 0.7, pos.dy), Offset(pos.dx + radius * 0.7, pos.dy), Paint()..color = Colors.white70..strokeWidth = 1.5);
        break;

      case 'taba_fort':
        // Taba cercada por paliçada fortificada (estacas radiais)
        canvas.drawCircle(pos, radius * 0.9, fillPaint);
        canvas.drawCircle(pos, radius * 0.9, strokePaint);
        final postPaint = Paint()..color = Colors.white..strokeWidth = 2.0;
        for (var i = 0; i < 8; i++) {
          final angle = (i * math.pi / 4);
          final p1 = pos + Offset(math.cos(angle) * (radius * 0.95), math.sin(angle) * (radius * 0.95));
          final p2 = pos + Offset(math.cos(angle) * (radius * 1.3), math.sin(angle) * (radius * 1.3));
          canvas.drawLine(p1, p2, postPaint);
        }
        break;

      case 'canoas':
        // Aldeia Portuária com canoa na base
        canvas.drawCircle(pos, radius * 0.85, fillPaint);
        canvas.drawCircle(pos, radius * 0.85, strokePaint);
        final canoePath = Path()
          ..moveTo(pos.dx - radius * 1.2, pos.dy + radius * 0.6)
          ..quadraticBezierTo(pos.dx, pos.dy + radius * 1.2, pos.dx + radius * 1.2, pos.dy + radius * 0.6)
          ..quadraticBezierTo(pos.dx, pos.dy + radius * 0.9, pos.dx - radius * 1.2, pos.dy + radius * 0.6)
          ..close();
        canvas.drawPath(canoePath, Paint()..color = const Color(0xFF38BDF8));
        canvas.drawPath(canoePath, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
        break;

      case 'acampamento':
        // Tenda triangular de caça
        final tentPath = Path()
          ..moveTo(pos.dx, pos.dy - radius)
          ..lineTo(pos.dx + radius * 0.9, pos.dy + radius * 0.75)
          ..lineTo(pos.dx - radius * 0.9, pos.dy + radius * 0.75)
          ..close();
        canvas.drawPath(tentPath, fillPaint);
        canvas.drawPath(tentPath, strokePaint);
        canvas.drawLine(Offset(pos.dx, pos.dy - radius), Offset(pos.dx, pos.dy + radius * 0.75), Paint()..color = Colors.white70..strokeWidth = 1.5);
        break;

      case 'sagrado':
        // Centro cerimonial com disco solar
        canvas.drawCircle(pos, radius * 0.85, fillPaint);
        canvas.drawCircle(pos, radius * 0.85, strokePaint);
        final rayPaint = Paint()..color = const Color(0xFFFDE047)..strokeWidth = 2.0;
        for (var i = 0; i < 6; i++) {
          final angle = (i * math.pi / 3);
          final p1 = pos + Offset(math.cos(angle) * (radius * 0.9), math.sin(angle) * (radius * 0.9));
          final p2 = pos + Offset(math.cos(angle) * (radius * 1.35), math.sin(angle) * (radius * 1.35));
          canvas.drawLine(p1, p2, rayPaint);
        }
        break;

      case 'oca':
      default:
        // Oca circular com círculo concêntrico
        canvas.drawCircle(pos, radius, fillPaint);
        canvas.drawCircle(pos, radius, strokePaint);
        canvas.drawCircle(pos, radius * 0.35, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
        break;
    }
  }

  void _drawConnectionOriginHighlight(Canvas canvas) {
    Offset startPos = const Offset(2000, 2000);
    final ent = connectionStartEntity!;

    if (ent.containsKey('x') && ent.containsKey('y')) {
      startPos = Offset((ent['x'] as num).toDouble(), (ent['y'] as num).toDouble());
    } else if (ent.containsKey('center_x') && ent.containsKey('center_y')) {
      startPos = Offset((ent['center_x'] as num).toDouble(), (ent['center_y'] as num).toDouble());
    } else if (ent.containsKey('bezier_points')) {
      final pts = (ent['bezier_points'] as List?) ?? [];
      if (pts.isNotEmpty) {
        final mid = pts[pts.length ~/ 2] as List;
        startPos = Offset((mid[0] as num).toDouble(), (mid[1] as num).toDouble());
      }
    }

    // Anéis de pulso de conexão
    canvas.drawCircle(
      startPos,
      34,
      Paint()
        ..color = const Color(0xFFF59E0B).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );
    canvas.drawCircle(
      startPos,
      46,
      Paint()
        ..color = const Color(0xFFF59E0B).withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  void _drawFogPreview(Canvas canvas, Size size) {
    final fogPaint = Paint()
      ..color = fogColor.withValues(alpha: fogOpacity.clamp(0.1, 0.98))
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, fogPaint);

    final clearPaint = Paint()..blendMode = BlendMode.clear;

    // Revela aldeias com raio customizado
    for (final village in villages) {
      if (village['is_unlocked_default'] == true) {
        final x = (village['x'] as num?)?.toDouble() ?? 2000.0;
        final y = (village['y'] as num?)?.toDouble() ?? 2000.0;
        final radius = ((village['fog_reveal_radius'] as num?)?.toDouble() ?? 180.0).clamp(50.0, 400.0);
        canvas.drawCircle(Offset(x, y), radius, clearPaint);
      }
    }

    // Revela quests com raio customizado
    for (final quest in quests) {
      if (quest['is_unlocked_default'] == true) {
        final x = (quest['x'] as num?)?.toDouble() ?? 2000.0;
        final y = (quest['y'] as num?)?.toDouble() ?? 2000.0;
        final radius = ((quest['fog_reveal_radius'] as num?)?.toDouble() ?? 120.0).clamp(40.0, 300.0);
        canvas.drawCircle(Offset(x, y), radius, clearPaint);
      }
    }

    // Revela territórios desbloqueados
    for (final territory in territories) {
      if (territory['is_unlocked_default'] == true) {
        final cx = (territory['center_x'] as num?)?.toDouble() ?? 2000.0;
        final cy = (territory['center_y'] as num?)?.toDouble() ?? 2000.0;
        final radius = ((territory['fog_reveal_radius'] as num?)?.toDouble() ?? 240.0).clamp(100.0, 500.0);
        canvas.drawCircle(Offset(cx, cy), radius, clearPaint);
      }
    }
  }

  Color _getBiomeColor(String biome) {
    switch (biome) {
      case 'Amazônia':
        return const Color(0xFF059669);
      case 'Cerrado':
        return const Color(0xFFD97706);
      case 'Caatinga':
        return const Color(0xFFB45309);
      case 'Pantanal':
        return const Color(0xFF0284C7);
      case 'Pampa':
        return const Color(0xFF65A30D);
      case 'Mata Atlântica':
      default:
        return const Color(0xFF10B981);
    }
  }

  @override
  bool shouldRepaint(covariant WorldBuilderPainter oldDelegate) => true;
}
