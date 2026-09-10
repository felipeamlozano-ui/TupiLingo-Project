import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:tupi_lingo/core/algorithms/quad_tree.dart';
import '../../domain/entities/historical_region.dart';

typedef OnRegionTappedCallback = void Function(HistoricalRegion region);

/// Widget que contorna a árvore de widgets padrão criando um RenderBox puro.
/// Reduz o overhead de memória e renderiza o mapa e as aldeias diretamente no Canvas.
class BrazilTupiMapRenderWidget extends LeafRenderObjectWidget {
  final List<HistoricalRegion> regions;
  final double pulseValue;
  final OnRegionTappedCallback? onRegionTapped;

  const BrazilTupiMapRenderWidget({
    super.key,
    required this.regions,
    this.pulseValue = 0.0,
    this.onRegionTapped,
  });

  @override
  RenderBrazilTupiMap createRenderObject(BuildContext context) {
    return RenderBrazilTupiMap(
      initialRegions: regions,
      initialPulseValue: pulseValue,
      onRegionTapped: onRegionTapped,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderBrazilTupiMap renderObject) {
    renderObject
      ..regions = regions
      ..pulseValue = pulseValue
      ..onRegionTapped = onRegionTapped;
  }
}

/// RenderBox customizado de alta performance.
/// Utiliza uma QuadTree espacial para hit-testing em O(log n) a cada toque.
class RenderBrazilTupiMap extends RenderBox {
  List<HistoricalRegion> _regions;
  double _pulseValue;
  OnRegionTappedCallback? onRegionTapped;

  // QuadTree para indexação espacial 2D das regiões
  late SpatialQuadTree<HistoricalRegion> _quadTree;
  Size _lastSize = Size.zero;

  // Paints reutilizáveis (Zero Alocação no Paint Loop)
  final Paint _landPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = const Color(0xFFE8E5D8);

  final Paint _coastlinePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..color = const Color(0xFFC7C1AF);

  final Paint _riverPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..color = const Color(0xFF88B3A8);

  final Paint _regionPaint = Paint()..style = PaintingStyle.fill;
  final Paint _regionBorderPaint = Paint()..style = PaintingStyle.stroke;

  RenderBrazilTupiMap({
    required List<HistoricalRegion> initialRegions,
    double initialPulseValue = 0.0,
    this.onRegionTapped,
  })  : _regions = initialRegions,
        _pulseValue = initialPulseValue {
    _quadTree = SpatialQuadTree<HistoricalRegion>(
      boundary: const Rect.fromLTWH(0, 0, 400, 450),
      capacity: 3,
    );
  }

  set regions(List<HistoricalRegion> value) {
    if (_regions == value) return;
    _regions = value;
    _rebuildSpatialIndex();
    markNeedsPaint();
  }

  set pulseValue(double value) {
    if (_pulseValue == value) return;
    _pulseValue = value;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => false;

  @override
  void performLayout() {
    // Garante tamanho consistente de acordo com constraints
    final desiredWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 380.0;
    final desiredHeight = desiredWidth * 1.15;
    size = constraints.constrain(Size(desiredWidth, desiredHeight));

    if (size != _lastSize) {
      _lastSize = size;
      _rebuildSpatialIndex();
    }
  }

  /// Reconstrói a QuadTree espacial mapeando as coordenadas normalizadas para pixels.
  void _rebuildSpatialIndex() {
    if (size.width <= 0 || size.height <= 0) return;

    _quadTree = SpatialQuadTree<HistoricalRegion>(
      boundary: Rect.fromLTWH(0, 0, size.width, size.height),
      capacity: 4,
    );

    for (final r in _regions) {
      final cx = r.relativeX * size.width;
      final cy = r.relativeY * size.height;
      final radius = r.radius;
      final bounds = Rect.fromCircle(center: Offset(cx, cy), radius: radius + 8.0);
      _quadTree.insert(SpatialItem(bounds: bounds, data: r));
    }
  }

  // ── Hit-Testing O(log n) via QuadTree ──────────────────────────────────────

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) {
      return false;
    }

    // Consulta espacial O(log n) na QuadTree
    final candidates = _quadTree.queryPoint(position);
    for (final candidate in candidates) {
      final cx = candidate.relativeX * size.width;
      final cy = candidate.relativeY * size.height;
      final dist = (position - Offset(cx, cy)).distance;
      if (dist <= candidate.radius + 8.0) {
        // Encontrou o polígono/marcador tocado
        result.add(BoxHitTestEntry(this, position));
        _touchedRegion = candidate;
        return true;
      }
    }

    return false;
  }

  HistoricalRegion? _touchedRegion;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      // Dispara o callback para o ponto encontrado
      if (_touchedRegion != null && onRegionTapped != null) {
        onRegionTapped!(_touchedRegion!);
      }
    }
  }

  // ── Renderização Direta no Canvas ──────────────────────────────────────────

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    final w = size.width;
    final h = size.height;

    // 1. Desenho do Contorno Continental do Brasil (Vetor Suave)
    final brazilPath = Path();
    brazilPath.moveTo(w * 0.18, h * 0.12);
    // Costa Norte
    brazilPath.cubicTo(w * 0.35, h * 0.04, w * 0.55, h * 0.08, w * 0.85, h * 0.22);
    // Ponta Nordeste
    brazilPath.cubicTo(w * 0.98, h * 0.30, w * 0.95, h * 0.45, w * 0.88, h * 0.60);
    // Litoral Sudeste
    brazilPath.cubicTo(w * 0.82, h * 0.72, w * 0.72, h * 0.80, w * 0.60, h * 0.95);
    // Extremo Sul
    brazilPath.cubicTo(w * 0.52, h * 0.99, w * 0.44, h * 0.90, w * 0.46, h * 0.78);
    // Fronteira Centro-Oeste / Bacia do Prata
    brazilPath.cubicTo(w * 0.40, h * 0.68, w * 0.30, h * 0.60, w * 0.24, h * 0.52);
    // Fronteira Amazônica / Acre / Colômbia
    brazilPath.cubicTo(w * 0.08, h * 0.44, w * 0.06, h * 0.28, w * 0.18, h * 0.12);
    brazilPath.close();

    // Sombra do Continente
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(brazilPath, shadowPaint);

    // Terra
    canvas.drawPath(brazilPath, _landPaint);
    canvas.drawPath(brazilPath, _coastlinePaint);

    // 2. Rios Sagrados Ancestrais (Amazonas / Rio Negro, São Francisco, Paraná)
    final amazonRiver = Path()
      ..moveTo(w * 0.12, h * 0.25)
      ..cubicTo(w * 0.35, h * 0.22, w * 0.60, h * 0.20, w * 0.80, h * 0.18);
    canvas.drawPath(amazonRiver, _riverPaint);

    final paranaRiver = Path()
      ..moveTo(w * 0.56, h * 0.52)
      ..cubicTo(w * 0.54, h * 0.68, w * 0.52, h * 0.82, w * 0.50, h * 0.94);
    canvas.drawPath(paranaRiver, _riverPaint);

    // 3. Demarcação das Aldeias e Regiões Históricas
    for (final r in _regions) {
      final cx = r.relativeX * w;
      final cy = r.relativeY * h;
      final rad = r.radius;

      if (r.isUnlocked) {
        // Pulso radial brilhante
        final pulseRadius = rad + (_pulseValue * 12.0);
        final pulseAlpha = (1.0 - _pulseValue) * 0.4;
        final pulsePaint = Paint()
          ..color = const Color(0xFFD08A45).withValues(alpha: pulseAlpha.clamp(0.0, 1.0))
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(cx, cy), pulseRadius, pulsePaint);

        // Preenchimento de Região Desbloqueada (Terracota Ancestral e Ouro)
        _regionPaint.shader = RadialGradient(
          colors: [
            const Color(0xFFFFD166),
            const Color(0xFFD08A45),
            const Color(0xFF8C4A19),
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: rad));

        canvas.drawCircle(Offset(cx, cy), rad, _regionPaint);

        // Borda Esmeralda
        _regionBorderPaint
          ..color = const Color(0xFF0E5D4E)
          ..strokeWidth = 3.0;
        canvas.drawCircle(Offset(cx, cy), rad, _regionBorderPaint);

        // Marcador interno de Oca/Aldeia
        final innerCenterPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(cx, cy), 5.5, innerCenterPaint);
      } else {
        // Região Bloqueada (Pedra e Cadeado Sagrado)
        _regionPaint.shader = null;
        _regionPaint.color = const Color(0xFFCBC6B8);
        canvas.drawCircle(Offset(cx, cy), rad * 0.82, _regionPaint);

        _regionBorderPaint
          ..color = const Color(0xFFA8A396)
          ..strokeWidth = 2.0;
        canvas.drawCircle(Offset(cx, cy), rad * 0.82, _regionBorderPaint);

        // Ponto central de trava
        final lockDot = Paint()..color = const Color(0xFF6B7280);
        canvas.drawCircle(Offset(cx, cy), 3.5, lockDot);
      }
    }

    canvas.restore();
  }
}
