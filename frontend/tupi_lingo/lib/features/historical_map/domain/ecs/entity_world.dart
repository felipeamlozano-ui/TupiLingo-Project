import 'package:tupi_lingo/features/historical_map/domain/ecs/components.dart';
import 'package:tupi_lingo/features/historical_map/domain/ecs/command_buffer.dart';

/// Entity in ECS V2 represented as a unique integer identifier.
typedef EntityId = int;

/// Central registry of entities and component storage in ECS V2.
class EntityWorld {
  int _nextEntityId = 1;
  final Set<EntityId> _aliveEntities = {};
  final Map<EntityId, Map<Type, ECSComponent>> _components = {};
  final CommandBuffer commandBuffer = CommandBuffer();

  EntityId createEntity() {
    final id = _nextEntityId++;
    _aliveEntities.add(id);
    _components[id] = {};
    return id;
  }

  void destroyEntity(EntityId id) {
    _aliveEntities.remove(id);
    _components.remove(id);
  }

  void addComponent<T extends ECSComponent>(EntityId id, T component) {
    if (_aliveEntities.contains(id)) {
      _components[id]?[T] = component;
    }
  }

  T? getComponent<T extends ECSComponent>(EntityId id) {
    return _components[id]?[T] as T?;
  }

  bool hasComponent<T extends ECSComponent>(EntityId id) {
    return _components[id]?.containsKey(T) ?? false;
  }

  /// Returns all entities that have all requested component types.
  List<EntityId> queryEntities(List<Type> requiredTypes) {
    final List<EntityId> matching = [];
    for (final id in _aliveEntities) {
      final compMap = _components[id];
      if (compMap == null) continue;

      bool match = true;
      for (final type in requiredTypes) {
        if (!compMap.containsKey(type)) {
          match = false;
          break;
        }
      }
      if (match) matching.add(id);
    }
    return matching;
  }

  int get entityCount => _aliveEntities.length;
}

/// Abstract base class for all ECS V2 systems.
abstract class ECSSystem {
  void update(EntityWorld world, double deltaTime);
}

/// SystemScheduler coordinating sequential execution of ECS systems and command buffers.
class SystemScheduler {
  final EntityWorld world;
  final List<ECSSystem> _systems = [];

  SystemScheduler({EntityWorld? world}) : world = world ?? EntityWorld();

  void addSystem(ECSSystem system) {
    _systems.add(system);
  }

  /// Ticks all systems and flushes the command buffer.
  void tick(double deltaTime) {
    for (final system in _systems) {
      system.update(world, deltaTime);
    }
    world.commandBuffer.playback();
  }
}
