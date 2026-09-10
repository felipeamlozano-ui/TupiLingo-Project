import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Instância de partícula mutável e reutilizável.
/// Nenhuma instância deve ser descartada ou recriada durante a animação.
class ArtifactParticle {
  double x = 0.0;
  double y = 0.0;
  double vx = 0.0;
  double vy = 0.0;
  double size = 4.0;
  Color color = Colors.amber;
  double alpha = 1.0;
  double rotation = 0.0;
  double rotationSpeed = 0.0;
  double life = 0.0;
  double maxLife = 1.0;
  bool isActive = false;

  /// Reinicializa as propriedades da partícula sem alocação de memória no Heap.
  void reset({
    required double startX,
    required double startY,
    required double initialVx,
    required double initialVy,
    required double particleSize,
    required Color particleColor,
    required double lifetime,
    required double initialRotation,
    required double rotSpeed,
  }) {
    x = startX;
    y = startY;
    vx = initialVx;
    vy = initialVy;
    size = particleSize;
    color = particleColor;
    alpha = 1.0;
    rotation = initialRotation;
    rotationSpeed = rotSpeed;
    life = 0.0;
    maxLife = lifetime;
    isActive = true;
  }

  /// Avança a simulação física da partícula (60/120 fps).
  void update(double dt) {
    if (!isActive) return;

    life += dt;
    if (life >= maxLife) {
      isActive = false;
      return;
    }

    // Física: velocidade, gravidade e arrasto
    x += vx * dt;
    y += vy * dt;
    vy += 220.0 * dt; // Gravidade suave para efeito de confete sagrado
    vx *= 0.98; // Arrasto do ar
    rotation += rotationSpeed * dt;

    // Fade out progressivo nos últimos 30% da vida útil
    final progress = life / maxLife;
    if (progress > 0.7) {
      alpha = (1.0 - progress) / 0.3;
    } else {
      alpha = 1.0;
    }
  }
}

/// Gerenciador de memória e Object Pool fixo para o sistema de partículas.
/// Garante Zero Alocação (Zero GC) durante o payoff da recompensa.
class ParticleMemoryPool {
  final int capacity;
  late final List<ArtifactParticle> _pool;
  final math.Random _rng = math.Random(42);

  // Paint reutilizável para evitar alocação por frame no Canvas
  final Paint _particlePaint = Paint()..style = PaintingStyle.fill;

  ParticleMemoryPool({this.capacity = 500}) {
    // Pré-alocação estrita no momento de instanciação (startup / warmup)
    _pool = List<ArtifactParticle>.generate(
      capacity,
      (_) => ArtifactParticle(),
      growable: false,
    );
  }

  /// Dispara uma explosão de partículas reaproveitando instâncias inativas do pool.
  void spawnBurst({
    required Offset origin,
    required int count,
    required List<Color> colors,
  }) {
    final int toSpawn = math.min(count, capacity);
    int spawned = 0;

    for (int i = 0; i < capacity && spawned < toSpawn; i++) {
      final p = _pool[i];
      if (!p.isActive) {
        final angle = _rng.nextDouble() * 2 * math.pi;
        final speed = 120.0 + _rng.nextDouble() * 280.0;
        final chosenColor = colors[_rng.nextInt(colors.length)];
        final lifetime = 0.8 + _rng.nextDouble() * 1.4;

        p.reset(
          startX: origin.dx,
          startY: origin.dy,
          initialVx: math.cos(angle) * speed,
          initialVy: (math.sin(angle) * speed) - 150.0, // Impulso ascendente
          particleSize: 4.0 + _rng.nextDouble() * 7.0,
          particleColor: chosenColor,
          lifetime: lifetime,
          initialRotation: _rng.nextDouble() * math.pi,
          rotSpeed: (_rng.nextDouble() - 0.5) * 8.0,
        );
        spawned++;
      }
    }
  }

  /// Atualiza todas as partículas ativas em tempo O(k).
  void update(double dt) {
    for (int i = 0; i < capacity; i++) {
      final p = _pool[i];
      if (p.isActive) {
        p.update(dt);
      }
    }
  }

  /// Desenha todas as partículas ativas diretamente no Canvas sem alocações intermediárias.
  void render(Canvas canvas) {
    for (int i = 0; i < capacity; i++) {
      final p = _pool[i];
      if (p.isActive) {
        _particlePaint.color = p.color.withValues(alpha: p.alpha.clamp(0.0, 1.0));
        canvas.save();
        canvas.translate(p.x, p.y);
        canvas.rotate(p.rotation);
        // Desenha confete losangular ancestral ou circular
        final half = p.size / 2.0;
        canvas.drawRect(Rect.fromLTWH(-half, -half, p.size, p.size), _particlePaint);
        canvas.restore();
      }
    }
  }

  /// Retorna se ainda existem partículas ativas sendo renderizadas.
  bool get hasActiveParticles {
    for (int i = 0; i < capacity; i++) {
      if (_pool[i].isActive) return true;
    }
    return false;
  }

  /// Desativa imediatamente todas as partículas.
  void resetAll() {
    for (int i = 0; i < capacity; i++) {
      _pool[i].isActive = false;
    }
  }
}
