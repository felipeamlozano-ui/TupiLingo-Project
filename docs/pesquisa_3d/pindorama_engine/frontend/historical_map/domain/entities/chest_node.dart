import 'package:flutter/foundation.dart';

/// Cultural Chest entity rewarded upon completing territory milestones (RFC-012C Patch 1 Chapter 1).
@immutable
class ChestNode {
  final String id;
  final String title;
  final String artifactName;
  final String tupiLore;
  final bool isUnlocked;
  final int xpBonus;

  const ChestNode({
    required this.id,
    required this.title,
    required this.artifactName,
    required this.tupiLore,
    this.isUnlocked = false,
    this.xpBonus = 100,
  });

  ChestNode copyWith({
    String? id,
    String? title,
    String? artifactName,
    String? tupiLore,
    bool? isUnlocked,
    int? xpBonus,
  }) {
    return ChestNode(
      id: id ?? this.id,
      title: title ?? this.title,
      artifactName: artifactName ?? this.artifactName,
      tupiLore: tupiLore ?? this.tupiLore,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      xpBonus: xpBonus ?? this.xpBonus,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artifact_name': artifactName,
        'tupi_lore': tupiLore,
        'is_unlocked': isUnlocked,
        'xp_bonus': xpBonus,
      };
}
