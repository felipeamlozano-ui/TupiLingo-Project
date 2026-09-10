import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../domain/entities/indigenous_reward.dart';
import '../particle_system/particle_pool.dart';
import 'chest_painter.dart';
import 'mystic_aura_shader.dart';

enum ChestAnimState {
  idle,
  anticipation,
  opening,
  revealed,
}

class IndigenousArtifactChest extends StatefulWidget {
  final IndigenousReward reward;
  final VoidCallback? onCollected;

  const IndigenousArtifactChest({
    super.key,
    required this.reward,
    this.onCollected,
  });

  @override
  State<IndigenousArtifactChest> createState() => _IndigenousArtifactChestState();
}

class _IndigenousArtifactChestState extends State<IndigenousArtifactChest>
    with TickerProviderStateMixin {
  ChestAnimState _state = ChestAnimState.idle;

  // Controladores de animação
  late final AnimationController _idleFloatController;
  late final AnimationController _shakeController;
  late final AnimationController _lidController;
  late final AnimationController _rewardPopController;
  late final AnimationController _auraSpinController;
  late final AnimationController _particleTickerController;

  late final Animation<double> _lidAngleAnimation;
  late final Animation<double> _rewardPopAnimation;

  // Object Pool fixo de 500 partículas (Zero-GC no payoff)
  final ParticleMemoryPool _particlePool = ParticleMemoryPool(capacity: 500);

  @override
  void initState() {
    super.initState();

    // 1. Ocioso: flutuação suave
    _idleFloatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // 2. Antecipação: tremor vigoroso
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    // 3. Abertura da Tampa em Perspectiva 3D
    _lidController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _lidAngleAnimation = Tween<double>(begin: 0.0, end: 1.75).animate(
      CurvedAnimation(parent: _lidController, curve: Curves.easeInOutCubic),
    );

    // 4. Salto da Recompensa com efeito elástico
    _rewardPopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _rewardPopAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rewardPopController, curve: Curves.elasticOut),
    );

    // 5. Aura Mística Giratória
    _auraSpinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    // 6. Ticker do sistema de partículas
    _particleTickerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onParticleTick);
  }

  void _onParticleTick() {
    if (_particlePool.hasActiveParticles) {
      _particlePool.update(0.016); // ~60fps step
      setState(() {});
    }
  }

  @override
  void dispose() {
    _idleFloatController.dispose();
    _shakeController.dispose();
    _lidController.dispose();
    _rewardPopController.dispose();
    _auraSpinController.dispose();
    _particleTickerController.dispose();
    super.dispose();
  }

  void _onTapChest() async {
    if (_state != ChestAnimState.idle) return;

    // Passo 1: Antecipação (Tremor)
    setState(() => _state = ChestAnimState.anticipation);
    await _shakeController.forward();

    // Passo 2: Abertura 3D da tampa
    setState(() => _state = ChestAnimState.opening);
    _lidController.forward();

    await Future.delayed(const Duration(milliseconds: 250));

    // Passo 3: Salto da Recompensa e Aura
    setState(() => _state = ChestAnimState.revealed);
    _auraSpinController.repeat();
    _rewardPopController.forward();

    // Passo 4: Disparo de 500 partículas via Object Pool (Zero Alocação)
    _particlePool.spawnBurst(
      origin: const Offset(150, 160),
      count: 500,
      colors: const [
        Color(0xFFFFD166),
        Color(0xFFD08A45),
        Color(0xFF0E5D4E),
        Color(0xFF1EC9A5),
        Colors.white,
      ],
    );
    _particleTickerController.repeat();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Área da Urna e Efeitos Visuais
          GestureDetector(
            onTap: _onTapChest,
            child: SizedBox(
              width: 300,
              height: 320,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Aura Mística Acelerada por GPU (Fragment Shader Impeller) ao Revelar
                  if (_state == ChestAnimState.revealed)
                    const MysticAuraShaderWidget(
                      size: 280,
                      innerColor: Color(0xFFFFD166), // Ouro Solar Marajoara
                      outerColor: Color(0xFF0E5D4E), // Verde Floresta Ancestral
                    ),

                  // Recompensa Saltando com Curves.elasticOut
                  if (_state == ChestAnimState.revealed)
                    AnimatedBuilder(
                      animation: _rewardPopAnimation,
                      builder: (context, _) {
                        final val = _rewardPopAnimation.value;
                        final translateY = -120.0 * val;
                        final scale = 0.4 + (0.8 * val);

                        return Transform.translate(
                          offset: Offset(0, translateY),
                          child: Transform.scale(
                            scale: scale,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 86,
                                  height: 86,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const RadialGradient(
                                      colors: [Color(0xFFFFF7D6), Color(0xFFFFD166)],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFFD166).withValues(alpha: 0.8),
                                        blurRadius: 28,
                                        spreadRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      widget.reward.emojiIcon,
                                      style: const TextStyle(fontSize: 44),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  // Baú / Igaçaba Ancestral com Animação 3D
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _idleFloatController,
                      _shakeController,
                      _lidAngleAnimation,
                    ]),
                    builder: (context, _) {
                      // 1. Translação de flutuação ociosa
                      double floatY = 0;
                      if (_state == ChestAnimState.idle) {
                        floatY = math.sin(_idleFloatController.value * math.pi) * 8;
                      }

                      // 2. Tremor de antecipação
                      double shakeX = 0;
                      if (_state == ChestAnimState.anticipation) {
                        shakeX = math.sin(_shakeController.value * 25.0) * 9.0;
                      }

                      return Transform.translate(
                        offset: Offset(shakeX, floatY + 30),
                        child: SizedBox(
                          width: 170,
                          height: 140,
                          child: Stack(
                            alignment: Alignment.topCenter,
                            clipBehavior: Clip.none,
                            children: [
                              // Base da Urna
                              Positioned(
                                top: 38,
                                child: CustomPaint(
                                  size: const Size(160, 100),
                                  painter: MarajoaraChestBasePainter(),
                                ),
                              ),

                              // Tampa com Rotação em Perspectiva 3D (Transform + Matrix4)
                              Positioned(
                                top: 0,
                                child: Transform(
                                  alignment: Alignment.bottomCenter,
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.002) // Perspectiva em Z
                                    ..rotateX(-_lidAngleAnimation.value),
                                  child: CustomPaint(
                                    size: const Size(166, 46),
                                    painter: MarajoaraChestLidPainter(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Camada de Partículas Renderizada sem Alocação
                  CustomPaint(
                    size: const Size(300, 320),
                    painter: _ParticleCanvasPainter(pool: _particlePool),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Indicador textual ou Card Cultural
          if (_state == ChestAnimState.idle)
            const Text(
              '✨ Toque no Baú Ancestral para abrir ✨',
              style: TextStyle(
                color: Color(0xFF0E5D4E),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                  begin: const Offset(0.96, 0.96),
                  end: const Offset(1.04, 1.04),
                  duration: 900.ms,
                )
          else if (_state == ChestAnimState.revealed)
            _buildRewardLoreCard(),
        ],
      ),
    );
  }

  Widget _buildRewardLoreCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFD166), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E5D4E).withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD166).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.reward.rarity.label.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFB8860B),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.reward.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.reward.culturalLore,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF565D6D),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildRewardStatBadge('⭐', '+${widget.reward.xpBonus} XP', const Color(0xFFD08A45)),
              const SizedBox(width: 12),
              _buildRewardStatBadge('🐚', '+${widget.reward.conchasBonus} Conchas', const Color(0xFF0E5D4E)),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: widget.onCollected,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E5D4E),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Coletar Recompensa',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, curve: Curves.easeOut)
        .slideY(begin: 0.15, end: 0, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildRewardStatBadge(String icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter dedicado para renderizar as partículas do pool no Canvas.
class _ParticleCanvasPainter extends CustomPainter {
  final ParticleMemoryPool pool;

  _ParticleCanvasPainter({required this.pool});

  @override
  void paint(Canvas canvas, Size size) {
    pool.render(canvas);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
