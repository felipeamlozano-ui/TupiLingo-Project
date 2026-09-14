import 'package:tupi_lingo/features/historical_map/domain/ecs/entity_world.dart';
import 'package:tupi_lingo/features/historical_map/domain/ecs/components.dart';

/// FogSystem updates fog of war opacity transitions as territories are discovered.
class FogSystem extends ECSSystem {
  @override
  void update(EntityWorld world, double deltaTime) {
    final entities = world.queryEntities([FogComponent]);
    for (final id in entities) {
      final fog = world.getComponent<FogComponent>(id);
      if (fog == null) continue;

      if (fog.isDiscovered && fog.opacity > 0.0) {
        // Fade out fog
        fog.opacity = (fog.opacity - deltaTime * 2.0).clamp(0.0, 1.0);
      }
    }
  }
}

/// QuestSystem updates completion states for territory missions.
class QuestSystem extends ECSSystem {
  @override
  void update(EntityWorld world, double deltaTime) {
    final entities = world.queryEntities([QuestComponent]);
    for (final id in entities) {
      final quest = world.getComponent<QuestComponent>(id);
      if (quest == null) continue;

      if (quest.progressPercent >= 100 && !quest.isCompleted) {
        quest.isCompleted = true;
      }
    }
  }
}
