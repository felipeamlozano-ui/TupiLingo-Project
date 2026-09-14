import 'package:flutter_test/flutter_test.dart';
import 'package:tupi_lingo/core/render_engine/adaptive_rendering_engine.dart';
import 'package:tupi_lingo/features/historical_map/domain/ecs/entity_world.dart';
import 'package:tupi_lingo/features/historical_map/domain/ecs/components.dart';
import 'package:tupi_lingo/features/historical_map/domain/ecs/map_systems.dart';
import 'package:tupi_lingo/features/analytics/analytics_service.dart';

void main() {
  group('Phase P2 Architecture Engines', () {
    // ── 1. Adaptive Rendering Engine (Ch. 33) ─────────────────────────────────
    test('AdaptiveRenderingEngine downscales tier when frame times exceed budget', () {
      final engine = AdaptiveRenderingEngine(currentTier: DevicePerformanceTier.high);

      // Simulate 65 consecutive heavy frames (> 12ms)
      for (int i = 0; i < 65; i++) {
        engine.recordFrame(20.0);
      }

      expect(engine.currentTier, equals(DevicePerformanceTier.medium));
    });

    // ── 2. ECS V2 Engine & Systems (Ch. 32) ──────────────────────────────────
    test('EntityWorld manages entities, components, and queries', () {
      final world = EntityWorld();
      final e1 = world.createEntity();
      world.addComponent(e1, PositionComponent());
      world.addComponent(e1, FogComponent());

      final e2 = world.createEntity();
      world.addComponent(e2, PositionComponent());

      final withFog = world.queryEntities([PositionComponent, FogComponent]);
      expect(withFog.length, equals(1));
      expect(withFog.first, equals(e1));
    });

    test('FogSystem updates opacity and QuestSystem marks complete', () {
      final world = EntityWorld();
      final scheduler = SystemScheduler(world: world);
      scheduler.addSystem(FogSystem());
      scheduler.addSystem(QuestSystem());

      final e = world.createEntity();
      final fog = FogComponent(isDiscovered: true, opacity: 1.0);
      final quest = QuestComponent(questId: 'q1', title: 'Test Quest', progressPercent: 100);

      world.addComponent(e, fog);
      world.addComponent(e, quest);

      // Tick 0.25 seconds
      scheduler.tick(0.25);

      expect(fog.opacity, lessThan(1.0));
      expect(quest.isCompleted, isTrue);
    });

    test('CommandBuffer plays back deferred mutations without concurrent modification', () {
      final world = EntityWorld();
      final e = world.createEntity();

      world.commandBuffer.record(() {
        world.addComponent(e, PositionComponent(scale: 2.5));
      });

      expect(world.hasComponent<PositionComponent>(e), isFalse);
      world.commandBuffer.playback();
      expect(world.hasComponent<PositionComponent>(e), isTrue);
      expect(world.getComponent<PositionComponent>(e)?.scale, equals(2.5));
    });

    // ── 3. Analytics & A/B Engine (Ch. 46) ────────────────────────────────────
    test('ABExperimentEngine assigns variants deterministically', () {
      final engine = ABExperimentEngine();
      final v1 = engine.assignVariant(experimentId: 'map_v2', userId: 'user_101');
      final v2 = engine.assignVariant(experimentId: 'map_v2', userId: 'user_101');

      expect(v1, equals(v2));
    });

    test('AnalyticsService records events cleanly', () {
      final analytics = AnalyticsService.instance..clear();
      analytics.logEvent('lesson_started', parameters: {'lesson_id': 'licao_1'});

      expect(analytics.loggedEvents.length, equals(1));
      expect(analytics.loggedEvents.first['event_name'], equals('lesson_started'));
    });
  });
}
