import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../camera/camera_state.dart';
import '../coordinates/world_coordinate.dart';
import '../villages/village_node.dart';

/// Supported atmospheric particle types in Pindorama (RFC-012C Patch 1 Chapter 12).
enum WorldParticleType {
  bonfireEmber,  // Golden-orange embers rising from active village bonfires
  sacredMist,    // Soft white-cyan mist drifting over riverbeds
  forestLeaf,    // Emerald leaves swirling in the Atlantic rainforest canopy
  masteryOrb,    // Golden knowledge sparkles near mastered villages
  ritualDust,    // Luminous purple/cyan dust for sacred and boss sites
}

/// A single pre-allocated particle in the static pool (zero runtime allocations).
class WorldParticle {
  WorldParticleType type;
  double x;
  double y;
  double vx;
  double vy;
  double age;
  double lifespan;
  double size;
  double alpha;
  double baseAlpha;
  Color color;
  double rotation;
  double rotationSpeed;
  bool isAlive;

  WorldParticle({
    required this.type,
    this.x = 0.0,
    this.y = 0.0,
    this.vx = 0.0,
    this.vy = 0.0,
    this.age = 0.0,
    this.lifespan = 3.0,
    this.size = 3.0,
    this.alpha = 1.0,
    this.baseAlpha = 0.8,
    this.color = const Color(0xFFFF9800),
    this.rotation = 0.0,
    this.rotationSpeed = 0.0,
    this.isAlive = false,
  });

  void reset({
    required WorldParticleType newType,
    required double newX,
    required double newY,
    required double newVx,
    required double newVy,
    required double newLifespan,
    required double newSize,
    required double newBaseAlpha,
    required Color newColor,
    double newRotation = 0.0,
    double newRotationSpeed = 0.0,
  }) {
    type = newType;
    x = newX;
    y = newY;
    vx = newVx;
    vy = newVy;
    lifespan = newLifespan;
    age = 0.0;
    size = newSize;
    baseAlpha = newBaseAlpha;
    alpha = baseAlpha;
    color = newColor;
    rotation = newRotation;
    rotationSpeed = newRotationSpeed;
    isAlive = true;
  }
}

/// Zero-allocation, contextual static particle pool for Pindorama (RFC-012C Patch 1 Chapter 12).
class WorldParticlePool {
  static const int poolCapacity = 300;
  final List<WorldParticle> _pool;
  final math.Random _rng = math.Random();

  WorldParticlePool()
      : _pool = List.generate(
          poolCapacity,
          (index) => WorldParticle(type: WorldParticleType.forestLeaf),
          growable: false,
        );

  int get capacity => poolCapacity;

  /// Initializes particles distributed across authentic biome coordinates.
  void initializeDefaults({List<VillageNode>? villages}) {
    final activeVillages = (villages ?? VillageNode.canonicalVillages)
        .where((v) => v.stage.index >= VillageEvolutionStage.explorada.index)
        .toList();

    for (int i = 0; i < poolCapacity; i++) {
      final p = _pool[i];
      if (i < 80) {
        // Bonfire embers spawned strictly around active villages
        final v = activeVillages.isNotEmpty ? activeVillages[i % activeVillages.length] : null;
        final cx = v != null ? v.position.x : 5000.0;
        final cy = v != null ? v.position.y : 5000.0;

        p.reset(
          newType: WorldParticleType.bonfireEmber,
          newX: cx + (_rng.nextDouble() * 80.0 - 40.0),
          newY: cy + (_rng.nextDouble() * 40.0),
          newVx: (_rng.nextDouble() * 12.0 - 6.0),
          newVy: -(_rng.nextDouble() * 32.0 + 16.0),
          newLifespan: 2.0 + _rng.nextDouble() * 2.0,
          newSize: 2.5 + _rng.nextDouble() * 2.5,
          newBaseAlpha: 0.85,
          newColor: const Color(0xFFFF7043),
        );
      } else if (i < 160) {
        // Sacred mist along Tietê and Paraíba rivers
        p.reset(
          newType: WorldParticleType.sacredMist,
          newX: 4500.0 + _rng.nextDouble() * 1800.0,
          newY: 4850.0 + _rng.nextDouble() * 850.0,
          newVx: _rng.nextDouble() * 8.0 + 2.0,
          newVy: (_rng.nextDouble() * 6.0 - 3.0),
          newLifespan: 4.5 + _rng.nextDouble() * 3.0,
          newSize: 8.0 + _rng.nextDouble() * 12.0,
          newBaseAlpha: 0.25,
          newColor: const Color(0xFFE0F7FA),
        );
      } else if (i < 240) {
        // Forest leaves across Serra do Mar / Mata Atlântica canopy
        p.reset(
          newType: WorldParticleType.forestLeaf,
          newX: 5100.0 + (_rng.nextDouble() * 1600.0 - 800.0),
          newY: 5200.0 + (_rng.nextDouble() * 1600.0 - 800.0),
          newVx: _rng.nextDouble() * 14.0 - 7.0,
          newVy: _rng.nextDouble() * 18.0 + 8.0,
          newLifespan: 3.5 + _rng.nextDouble() * 2.5,
          newSize: 3.5 + _rng.nextDouble() * 2.0,
          newBaseAlpha: 0.65,
          newColor: const Color(0xFF81C784),
          newRotation: _rng.nextDouble() * math.pi * 2,
          newRotationSpeed: (_rng.nextDouble() - 0.5) * 3.0,
        );
      } else {
        // Golden spirit sparkles near mastered / sacred territories
        p.reset(
          newType: WorldParticleType.masteryOrb,
          newX: 5000.0 + (_rng.nextDouble() * 200.0 - 100.0),
          newY: 5000.0 + (_rng.nextDouble() * 200.0 - 100.0),
          newVx: _rng.nextDouble() * 8.0 - 4.0,
          newVy: _rng.nextDouble() * 8.0 - 4.0,
          newLifespan: 2.2 + _rng.nextDouble() * 1.8,
          newSize: 3.5 + _rng.nextDouble() * 2.5,
          newBaseAlpha: 0.85,
          newColor: const Color(0xFFFFD54F),
        );
      }
    }
  }

  /// Zero-allocation frame tick. Advances all particles and recycles expired ones.
  void tick(double dt) {
    for (int i = 0; i < poolCapacity; i++) {
      final p = _pool[i];
      if (!p.isAlive) continue;

      p.age += dt;
      if (p.age >= p.lifespan) {
        _recycleParticle(p);
        continue;
      }

      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.rotation += p.rotationSpeed * dt;

      switch (p.type) {
        case WorldParticleType.bonfireEmber:
          p.vx += (math.sin(p.age * 5.0) * 6.0) * dt;
          break;
        case WorldParticleType.forestLeaf:
          p.vx += (math.cos(p.age * 3.5) * 10.0) * dt;
          break;
        case WorldParticleType.sacredMist:
          p.size += dt * 1.2;
          break;
        case WorldParticleType.masteryOrb:
        case WorldParticleType.ritualDust:
          p.vy += (math.sin(p.age * 6.0) * 4.0) * dt;
          break;
      }

      // Smooth in-out alpha curve
      final progress = p.age / p.lifespan;
      if (progress < 0.2) {
        p.alpha = (progress / 0.2) * p.baseAlpha;
      } else if (progress > 0.75) {
        p.alpha = (1.0 - (progress - 0.75) / 0.25) * p.baseAlpha;
      } else {
        p.alpha = p.baseAlpha;
      }
    }
  }

  void _recycleParticle(WorldParticle p) {
    p.age = 0.0;
    switch (p.type) {
      case WorldParticleType.bonfireEmber:
        p.x = 5000.0 + (_rng.nextDouble() * 80.0 - 40.0);
        p.y = 5000.0 + (_rng.nextDouble() * 30.0);
        p.vx = (_rng.nextDouble() * 12.0 - 6.0);
        p.vy = -(_rng.nextDouble() * 32.0 + 16.0);
        break;
      case WorldParticleType.sacredMist:
        p.x = 4500.0 + _rng.nextDouble() * 1800.0;
        p.y = 4850.0 + _rng.nextDouble() * 850.0;
        p.size = 8.0 + _rng.nextDouble() * 10.0;
        break;
      case WorldParticleType.forestLeaf:
        p.x = 5100.0 + (_rng.nextDouble() * 1600.0 - 800.0);
        p.y = 5050.0 - (_rng.nextDouble() * 400.0);
        break;
      case WorldParticleType.masteryOrb:
      case WorldParticleType.ritualDust:
        p.x = 5000.0 + (_rng.nextDouble() * 200.0 - 100.0);
        p.y = 5000.0 + (_rng.nextDouble() * 200.0 - 100.0);
        break;
    }
  }

  /// Renders all visible particles with zoom-based macro culling to prevent clutter.
  void render({
    required Canvas canvas,
    required CameraState camera,
    required Size size,
  }) {
    // Macro zoom culling (Chapter 12)
    if (camera.zoom < 0.50) return;
    final zoomAlphaMultiplier = ((camera.zoom - 0.50) / 0.35).clamp(0.0, 1.0);

    final visibleBounds = camera.getVisibleBounds(size);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < poolCapacity; i++) {
      final p = _pool[i];
      if (!p.isAlive || p.alpha <= 0.01) continue;

      if (p.x < visibleBounds.minX - 50 ||
          p.x > visibleBounds.maxX + 50 ||
          p.y < visibleBounds.minY - 50 ||
          p.y > visibleBounds.maxY + 50) {
        continue;
      }

      final screenPt = WorldCoordinate(p.x, p.y).toScreen(
        cameraX: camera.x,
        cameraY: camera.y,
        zoom: camera.zoom,
        screenSize: size,
      );

      final screenRadius = (p.size * camera.zoom).clamp(1.0, 36.0);
      final effectiveAlpha = (p.alpha * zoomAlphaMultiplier).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: effectiveAlpha);

      if (p.type == WorldParticleType.forestLeaf && p.rotation != 0.0) {
        // Draw rotating leaf oval
        canvas.save();
        canvas.translate(screenPt.dx, screenPt.dy);
        canvas.rotate(p.rotation);
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: screenRadius * 1.6, height: screenRadius * 0.8),
          paint,
        );
        canvas.restore();
      } else {
        canvas.drawCircle(screenPt, screenRadius, paint);
      }
    }
  }
}
