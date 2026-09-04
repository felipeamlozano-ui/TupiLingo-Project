import 'dart:math' as math;
import 'package:flutter/material.dart';

class NivelGauge extends StatelessWidget {
  final int nivel; // 1 a 10
  final VoidCallback? onTap;

  const NivelGauge({
    super.key,
    required this.nivel,
    this.onTap,
  });

  String get tierTitle {
    if (nivel <= 2) return 'Semente 🌱';
    if (nivel <= 4) return 'Folha 🍃';
    if (nivel <= 6) return 'Arco 🏹';
    if (nivel <= 8) return 'Guerreiro 🪓';
    if (nivel == 9) return 'Pajé 🦅';
    return 'Guardião da Terra 👑';
  }

  String get tierDescription {
    if (nivel <= 2) return 'Iniciando os primeiros passos no vocabulário ancestral.';
    if (nivel <= 4) return 'Consolidando expressões cotidianas e termos fundamentais.';
    if (nivel <= 6) return 'Construindo frases e compreendendo a estrutura tupi.';
    if (nivel <= 8) return 'Grande domínio lexical e agilidade nos desafios.';
    if (nivel == 9) return 'Sabedoria avançada nas variantes e narrativas históricas.';
    return 'Mestre supremo na preservação e proficiência da língua!';
  }

  @override
  Widget build(BuildContext context) {
    final clampedNivel = nivel.clamp(1, 10);
    final targetPercent = clampedNivel / 10.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD0D0D0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🎯', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text(
                    'Calibração de Aprendizado',
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E5D4E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Tempo Real (TRI)',
                  style: TextStyle(
                    color: Color(0xFF0E5D4E),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Gauge circular animado
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: targetPercent),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return SizedBox(
                width: 170,
                height: 170,
                child: CustomPaint(
                  painter: _GaugePainter(progress: value),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'NÍVEL',
                          style: TextStyle(
                            color: Color(0xFF565D6D),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          '$clampedNivel',
                          style: const TextStyle(
                            color: Color(0xFF1F2937),
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          'de 10',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),
          // Badge do Tier
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD08A45), Color(0xFFA56627)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD08A45).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              tierTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tierDescription,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF565D6D),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress; // 0.0 a 1.0

  _GaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 14;
    const strokeWidth = 14.0;

    // Arco de fundo
    final bgPaint = Paint()
      ..color = const Color(0xFFEAE7DC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Ângulo: 240 graus aberto embaixo
    const startAngle = 135 * (math.pi / 180);
    const sweepAngle = 270 * (math.pi / 180);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Arco de progresso com gradiente
    final progressSweep = sweepAngle * progress;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = const SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: [
        Color(0xFF0E5D4E),
        Color(0xFFD08A45),
        Color(0xFFE05638),
      ],
      tileMode: TileMode.clamp,
    );

    final progressPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      startAngle,
      progressSweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
