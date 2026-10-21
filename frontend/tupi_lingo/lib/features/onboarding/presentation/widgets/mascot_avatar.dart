import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Humores e estados emocionais do Mascote Tupi
enum MascotMood {
  idle,
  talking,
  happy,
  celebrating,
  thinking,
}

/// Widget visual animado do mascote "Tupi", o simpático sagui ancestral.
/// Renderizado via desenho vetorial em Stack/Container, garantindo peso zero de download,
/// 60/120 FPS cravados e adaptação fluida aos modos claro e escuro.
class MascotAvatar extends StatefulWidget {
  final MascotMood mood;
  final double size;
  final bool animate;

  const MascotAvatar({
    super.key,
    this.mood = MascotMood.idle,
    this.size = 140,
    this.animate = true,
  });

  @override
  State<MascotAvatar> createState() => _MascotAvatarState();
}

class _MascotAvatarState extends State<MascotAvatar> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.animate) {
      _animController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant MascotAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_animController.isAnimating) {
      _animController.repeat(reverse: true);
    } else if (!widget.animate && _animController.isAnimating) {
      _animController.stop();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mascote Tupi: ${widget.mood.name}',
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          double dy = 0.0;
          double rotation = 0.0;

          if (widget.animate) {
            final t = _animController.value;
            switch (widget.mood) {
              case MascotMood.celebrating:
                dy = -10.0 * math.sin(t * math.pi);
                rotation = 0.05 * math.sin(t * math.pi * 2);
                break;
              case MascotMood.talking:
                dy = -3.0 * math.sin(t * math.pi);
                break;
              case MascotMood.happy:
                dy = -5.0 * math.sin(t * math.pi);
                rotation = 0.03 * math.sin(t * math.pi);
                break;
              case MascotMood.thinking:
                rotation = 0.04;
                dy = -2.0 * math.sin(t * math.pi);
                break;
              case MascotMood.idle:
                dy = -2.5 * math.sin(t * math.pi);
                break;
            }
          }

          return Transform.translate(
            offset: Offset(0, dy),
            child: Transform.rotate(
              angle: rotation,
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: 150,
                    height: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Orelhas
                        Positioned(
                          top: 10,
                          left: 12,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              color: Color(0xFF7A4A22),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 12,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              color: Color(0xFF7A4A22),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),

                        // Corpo / Cabeça arredondada
                        Positioned(
                          top: 22,
                          child: Container(
                            width: 116,
                            height: 112,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97900),
                              borderRadius: BorderRadius.circular(38),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Olhos
                        Positioned(
                          top: 52,
                          left: 36,
                          child: _buildEye(widget.mood),
                        ),
                        Positioned(
                          top: 52,
                          right: 36,
                          child: _buildEye(widget.mood),
                        ),

                        // Bochechas rosadas
                        Positioned(
                          top: 76,
                          left: 28,
                          child: Container(
                            width: 14,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFA4A4).withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 76,
                          right: 28,
                          child: Container(
                            width: 14,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFA4A4).withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),

                        // Focinho
                        Positioned(
                          top: 78,
                          child: Container(
                            width: 52,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6B3B1F),
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),

                        // Nariz
                        Positioned(
                          top: 84,
                          child: Container(
                            width: 14,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),

                        // Boca / Expressão
                        Positioned(
                          top: 94,
                          child: _buildMouth(widget.mood),
                        ),

                        // Faixa de pena indígena sutil na testa (adereço ancestral sagrado)
                        Positioned(
                          top: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E5D4E),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.eco_rounded, size: 10, color: Color(0xFFFFD166)),
                                SizedBox(width: 2),
                                Text(
                                  'TUPI',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEye(MascotMood mood) {
    if (mood == MascotMood.happy || mood == MascotMood.celebrating) {
      // Olhos sorridentes em arco
      return Container(
        width: 20,
        height: 12,
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.black, width: 3.5),
          ),
        ),
      );
    }

    return SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        children: [
          const CircleAvatar(
            radius: 11,
            backgroundColor: Colors.black,
          ),
          Positioned(
            top: 3,
            left: 4,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 3,
            right: 4,
            child: Container(
              width: 3,
              height: 3,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMouth(MascotMood mood) {
    if (mood == MascotMood.celebrating || mood == MascotMood.happy) {
      // Sorriso aberto com dente branco
      return Container(
        width: 14,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(6)),
        ),
      );
    } else if (mood == MascotMood.talking) {
      // Boca aberta falando
      return Container(
        width: 10,
        height: 8,
        decoration: BoxDecoration(
          color: const Color(0xFF3E1D0A),
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    // Sorriso sutil fechado
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(4)),
      ),
    );
  }
}
