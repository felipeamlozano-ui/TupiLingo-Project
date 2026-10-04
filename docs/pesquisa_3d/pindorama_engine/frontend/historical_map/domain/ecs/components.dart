import 'package:flutter/material.dart';

/// Base class for all ECS V2 components (RFC-012B Chapter 32).
abstract class ECSComponent {}

/// Position and scale component for entities on the world map.
class PositionComponent extends ECSComponent {
  Offset position;
  double scale;

  PositionComponent({
    this.position = Offset.zero,
    this.scale = 1.0,
  });
}

/// Fog of war component tracking visibility and exploration state.
class FogComponent extends ECSComponent {
  bool isDiscovered;
  double opacity;

  FogComponent({
    this.isDiscovered = false,
    this.opacity = 1.0,
  });
}

/// Territory metadata component linking an entity to a historical tribe/region.
class TerritoryComponent extends ECSComponent {
  final String territoryId;
  final String name;
  final int variantId;
  bool isUnlocked;

  TerritoryComponent({
    required this.territoryId,
    required this.name,
    required this.variantId,
    this.isUnlocked = false,
  });
}

/// Quest / Mission component linked to historical map nodes.
class QuestComponent extends ECSComponent {
  final String questId;
  final String title;
  bool isCompleted;
  int progressPercent;

  QuestComponent({
    required this.questId,
    required this.title,
    this.isCompleted = false,
    this.progressPercent = 0,
  });
}
