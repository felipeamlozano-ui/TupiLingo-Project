import 'package:flutter/material.dart';
import '../shared/floating_toolbar.dart';

/// Canvas visual interativo para edição de mundo com pan & zoom infinito (RFC-013 Capítulo 19).
class WorldBuilderCanvas extends StatefulWidget {
  final TransformationController transformationController;
  final WorldBuilderTool activeTool;
  final bool showFogPreview;
  final List<Map<String, dynamic>> territories;
  final List<Map<String, dynamic>> villages;
  final List<Map<String, dynamic>> rivers;
  final List<Map<String, dynamic>> trails;
  final Map<String, dynamic>? selectedEntity;
  final void Function(Map<String, dynamic> entity, String type) onSelectEntity;
  final void Function(Offset worldPosition) onCanvasTap;

  const WorldBuilderCanvas({
    super.key,
    required this.transformationController,
    required this.activeTool,
    required this.showFogPreview,
    required this.territories,
    required this.villages,
    required this.rivers,
    required this.trails,
    required this.selectedEntity,
    required this.onSelectEntity,
    required this.onCanvasTap,
  });

  @override
  State<WorldBuilderCanvas> createState() => _WorldBuilderCanvasState();
}

class _WorldBuilderCanvasState extends State<WorldBuilderCanvas> {
  @override
  Widget build(BuildContext context) {
    const worldSize = Size(4000, 4000);

    return LayoutBuilder(
      builder: (context, constraints) {
        return InteractiveViewer(
          transformationController: widget.transformationController,
          boundaryMargin: const EdgeInsets.all(2000),
          minScale: 0.15,
          maxScale: 4.0,
          constrained: false,
          child: GestureDetector(
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
                selectedEntity: widget.selectedEntity,
                showFogPreview: widget.showFogPreview,
                activeTool: widget.activeTool,
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleCanvasTap(Offset pos) {
    // 1. Verifica hit-test em aldeias (raio de 25px)
    for (final village in widget.villages) {
      final vx = (village['x'] as num?)?.toDouble() ?? 0.0;
      final vy = (village['y'] as num?)?.toDouble() ?? 0.0;
      final dist = (Offset(vx, vy) - pos).distance;
      if (dist <= 25.0) {
        widget.onSelectEntity(village, 'Aldeia');
        return;
      }
    }

    // 2. Se a ferramenta ativa for de adição, cria no local clicado
    if (widget.activeTool != WorldBuilderTool.select) {
      widget.onCanvasTap(pos);
      return;
    }

    // 3. Fallback: hit-test em territórios
    for (final territory in widget.territories) {
      final poly = (territory['polygon_coordinates'] as List?) ?? [];
      if (poly.isNotEmpty) {
        final cx = (territory['center_x'] as num?)?.toDouble() ?? 2000.0;
        final cy = (territory['center_y'] as num?)?.toDouble() ?? 2000.0;
        if ((Offset(cx, cy) - pos).distance <= 200.0) {
          widget.onSelectEntity(territory, 'Território');
          return;
        }
      }
    }
  }
}

/// Painter gráfico de alta fidelidade para o World Builder Canvas
class WorldBuilderPainter extends CustomPainter {
  final List<Map<String, dynamic>> territories;
  final List<Map<String, dynamic>> villages;
  final List<Map<String, dynamic>> rivers;
  final List<Map<String, dynamic>> trails;
  final Map<String, dynamic>? selectedEntity;
  final bool showFogPreview;
  final WorldBuilderTool activeTool;

  WorldBuilderPainter({
    required this.territories,
    required this.villages,
    required this.rivers,
    required this.trails,
    required this.selectedEntity,
    required this.showFogPreview,
    required this.activeTool,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fundo e Grid Infinito
    final bgPaint = Paint()..color = const Color(0xFF060B15);
    canvas.drawRect(Offset.zero & size, bgPaint);

    _drawGrid(canvas, size);

    // 2. Territórios com Polígonos e Preenchimento Gradiente
    _drawTerritories(canvas);

    // 3. Rios Bézier Cúbicos
    _drawRivers(canvas);

    // 4. Trilhas Históricas Pontilhadas
    _drawTrails(canvas);

    // 5. Aldeias e Ocas com Labels
    _drawVillages(canvas);

    // 6. Simulação do Fog of War se ativada
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

        // Preenchimento
        final fillPaint = Paint()
          ..color = biomeColor.withValues(alpha: isSelected ? 0.35 : 0.2)
          ..style = PaintingStyle.fill;
        canvas.drawPath(path, fillPaint);

        // Borda
        final strokePaint = Paint()
          ..color = isSelected ? const Color(0xFF10B981) : biomeColor.withValues(alpha: 0.7)
          ..strokeWidth = isSelected ? 3.0 : 1.8
          ..style = PaintingStyle.stroke;
        canvas.drawPath(path, strokePaint);
      }
    }
  }

  void _drawRivers(Canvas canvas) {
    for (final river in rivers) {
      final isSelected = selectedEntity != null && selectedEntity!['id'] == river['id'];
      final pts = (river['bezier_points'] as List?) ?? [];
      if (pts.length >= 2) {
        final path = Path();
        final start = pts.first as List;
        path.moveTo((start[0] as num).toDouble(), (start[1] as num).toDouble());

        for (var i = 1; i < pts.length; i++) {
          final pt = pts[i] as List;
          path.lineTo((pt[0] as num).toDouble(), (pt[1] as num).toDouble());
        }

        final riverPaint = Paint()
          ..color = isSelected ? const Color(0xFF38BDF8) : const Color(0xFF0284C7).withValues(alpha: 0.8)
          ..strokeWidth = isSelected ? 5.0 : 3.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        canvas.drawPath(path, riverPaint);
      }
    }
  }

  void _drawTrails(Canvas canvas) {
    for (final trail in trails) {
      final isSelected = selectedEntity != null && selectedEntity!['id'] == trail['id'];
      final wps = (trail['waypoints'] as List?) ?? [];
      if (wps.length >= 2) {
        final trailPaint = Paint()
          ..color = isSelected ? const Color(0xFFF59E0B) : const Color(0xFFD97706).withValues(alpha: 0.7)
          ..strokeWidth = isSelected ? 3.5 : 2.0
          ..style = PaintingStyle.stroke;

        for (var i = 0; i < wps.length - 1; i++) {
          final p1 = wps[i] as List;
          final p2 = wps[i + 1] as List;
          canvas.drawLine(
            Offset((p1[0] as num).toDouble(), (p1[1] as num).toDouble()),
            Offset((p2[0] as num).toDouble(), (p2[1] as num).toDouble()),
            trailPaint,
          );
        }
      }
    }
  }

  void _drawVillages(Canvas canvas) {
    for (final village in villages) {
      final isSelected = selectedEntity != null && selectedEntity!['id'] == village['id'];
      final x = (village['x'] as num?)?.toDouble() ?? 2000.0;
      final y = (village['y'] as num?)?.toDouble() ?? 2000.0;
      final pos = Offset(x, y);

      // Glow de Seleção
      if (isSelected) {
        canvas.drawCircle(
          pos,
          26,
          Paint()..color = const Color(0xFF10B981).withValues(alpha: 0.35),
        );
      }

      // Nó da Aldeia (Círculo Oca)
      final villagePaint = Paint()
        ..color = isSelected ? const Color(0xFF10B981) : const Color(0xFFF59E0B)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 14, villagePaint);

      final borderPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(pos, 14, borderPaint);

      // Label do Nome
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

      textPainter.paint(canvas, Offset(pos.dx - textPainter.width / 2, pos.dy + 18));
    }
  }

  void _drawFogPreview(Canvas canvas, Size size) {
    final fogPaint = Paint()
      ..color = const Color(0xD9060B15)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, fogPaint);

    // Revela círculos nas aldeias desbloqueadas
    for (final village in villages) {
      final x = (village['x'] as num?)?.toDouble() ?? 2000.0;
      final y = (village['y'] as num?)?.toDouble() ?? 2000.0;
      final clearPaint = Paint()..blendMode = BlendMode.clear;
      canvas.drawCircle(Offset(x, y), 180, clearPaint);
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
