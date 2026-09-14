import 'package:flutter/foundation.dart';
import '../../../../core/world_engine/coordinates/world_coordinate.dart';

/// Quest objective entity mapped to geographical milestones (RFC-012C Patch 1 Chapter 1 & 9).
@immutable
class QuestNode {
  final String id;
  final String title;
  final String description;
  final bool isMain;
  final String targetVillageId;
  final WorldCoordinate targetCoordinate;
  final bool isCompleted;
  final int rewardXp;

  const QuestNode({
    required this.id,
    required this.title,
    required this.description,
    this.isMain = true,
    required this.targetVillageId,
    required this.targetCoordinate,
    this.isCompleted = false,
    this.rewardXp = 150,
  });

  QuestNode copyWith({
    String? id,
    String? title,
    String? description,
    bool? isMain,
    String? targetVillageId,
    WorldCoordinate? targetCoordinate,
    bool? isCompleted,
    int? rewardXp,
  }) {
    return QuestNode(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isMain: isMain ?? this.isMain,
      targetVillageId: targetVillageId ?? this.targetVillageId,
      targetCoordinate: targetCoordinate ?? this.targetCoordinate,
      isCompleted: isCompleted ?? this.isCompleted,
      rewardXp: rewardXp ?? this.rewardXp,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'is_main': isMain,
        'target_village_id': targetVillageId,
        'tx': targetCoordinate.x,
        'ty': targetCoordinate.y,
        'is_completed': isCompleted,
        'reward_xp': rewardXp,
      };
}
