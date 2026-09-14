import 'package:flutter/foundation.dart';

enum CurriculumNodeType {
  territory,
  chapter,
  lesson,
  concept,
}

/// Node in the hierarchical pedagogical DAG (RFC-012A Chapter 12).
@immutable
class CurriculumNode {
  final String id;
  final String title;
  final String description;
  final CurriculumNodeType type;
  final int order;
  final List<String> prerequisiteIds;
  final double requiredMasteryThreshold; // e.g. 0.70 required on prerequisites
  final bool isUnlocked;
  final bool isCompleted;
  final int? xpReward;

  const CurriculumNode({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.order = 0,
    this.prerequisiteIds = const [],
    this.requiredMasteryThreshold = 0.65,
    this.isUnlocked = false,
    this.isCompleted = false,
    this.xpReward = 50,
  });

  CurriculumNode copyWith({
    String? id,
    String? title,
    String? description,
    CurriculumNodeType? type,
    int? order,
    List<String>? prerequisiteIds,
    double? requiredMasteryThreshold,
    bool? isUnlocked,
    bool? isCompleted,
    int? xpReward,
  }) {
    return CurriculumNode(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      order: order ?? this.order,
      prerequisiteIds: prerequisiteIds ?? this.prerequisiteIds,
      requiredMasteryThreshold: requiredMasteryThreshold ?? this.requiredMasteryThreshold,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isCompleted: isCompleted ?? this.isCompleted,
      xpReward: xpReward ?? this.xpReward,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type.name,
    'order': order,
    'prerequisite_ids': prerequisiteIds,
    'required_mastery_threshold': requiredMasteryThreshold,
    'is_unlocked': isUnlocked,
    'is_completed': isCompleted,
    'xp_reward': xpReward,
  };

  factory CurriculumNode.fromJson(Map<String, dynamic> json) {
    return CurriculumNode(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      type: CurriculumNodeType.values.firstWhere(
        (e) => e.name == (json['type'] as String?),
        orElse: () => CurriculumNodeType.lesson,
      ),
      order: (json['order'] as num?)?.toInt() ?? 0,
      prerequisiteIds: (json['prerequisite_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      requiredMasteryThreshold: (json['required_mastery_threshold'] as num?)?.toDouble() ?? 0.65,
      isUnlocked: json['is_unlocked'] as bool? ?? false,
      isCompleted: json['is_completed'] as bool? ?? false,
      xpReward: (json['xp_reward'] as num?)?.toInt() ?? 50,
    );
  }
}
