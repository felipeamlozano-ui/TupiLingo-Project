import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/render/shader_warmup_engine.dart';

/// Widget acelerado por GPU via Fragment Shaders do Impeller / SkSL.
/// Utiliza o [ShaderWarmupEngine] para exibir instantaneamente o shader sem jank de compilação.
/// Possui [RepaintBoundary] para isolar a renderização na Raster Thread da GPU.
class MysticAuraShaderWidget extends StatefulWidget {
  final double size;
  final Color innerColor;
  final Color outerColor;

  const MysticAuraShaderWidget({
    super.key,
    this.size = 280,
    this.innerColor = const Color(0xFFFFD166), // Ouro Solar Marajoara
    this.outerColor = const Color(0xFFD08A45), // Terracota Ancestral
  });

  @override
  State<MysticAuraShaderWidget> createState() => _MysticAuraShaderWidgetState();
}

class _MysticAuraShaderWidgetState extends State<MysticAuraShaderWidget>
    with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  late final AnimationController _timeController;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _timeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // 1. Tenta obter o shader imediatamente do motor pré-aquecido (Zero Latency)
    final warmup = ShaderWarmupEngine.instance;
    if (warmup.isWarmedUp && warmup.residentShader != null) {
      _shader = warmup.createShader() ?? warmup.residentShader;
    } else {
      // Se por algum motivo ainda não aqueceu, dispara o warmup
      _loadShaderAsync();
    }
  }

  Future<void> _loadShaderAsync() async {
    try {
      await ShaderWarmupEngine.instance.warmup();
      if (mounted) {
        setState(() {
          _shader = ShaderWarmupEngine.instance.createShader() ??
              ShaderWarmupEngine.instance.residentShader;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadFailed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadFailed || _shader == null) {
      // Fallback gracioso com gradiente radial suave
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                widget.innerColor.withValues(alpha: 0.6),
                widget.outerColor.withValues(alpha: 0.2),
                Colors.transparent,
              ],
              stops: const [0.2, 0.5, 1.0],
            ),
          ),
        ),
      );
    }

    // Renderização acelerada com RepaintBoundary isolando a GPU
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _timeController,
        builder: (context, _) {
          final elapsedSeconds = _timeController.value * 20.0;

          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _ShaderCanvasPainter(
              shader: _shader!,
              time: elapsedSeconds,
              innerColor: widget.innerColor,
              outerColor: widget.outerColor,
            ),
          );
        },
      ),
    );
  }
}

class _ShaderCanvasPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;
  final Color innerColor;
  final Color outerColor;
  static final Paint _reusablePaint = Paint();

  _ShaderCanvasPainter({
    required this.shader,
    required this.time,
    required this.innerColor,
    required this.outerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Injeção de Uniforms na GPU via shader.setFloat():
    // 0, 1: uResolution (largura, altura)
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);

    // 2: uTime
    shader.setFloat(2, time);

    // 3..6: uColorInner (RGBA normalizado 0.0 - 1.0)
    shader.setFloat(3, innerColor.r);
    shader.setFloat(4, innerColor.g);
    shader.setFloat(5, innerColor.b);
    shader.setFloat(6, innerColor.a);

    // 7..10: uColorOuter (RGBA normalizado 0.0 - 1.0)
    shader.setFloat(7, outerColor.r);
    shader.setFloat(8, outerColor.g);
    shader.setFloat(9, outerColor.b);
    shader.setFloat(10, outerColor.a);

    _reusablePaint.shader = shader;
    canvas.drawRect(Offset.zero & size, _reusablePaint);
  }

  @override
  bool shouldRepaint(covariant _ShaderCanvasPainter oldDelegate) {
    return oldDelegate.time != time;
  }
}
