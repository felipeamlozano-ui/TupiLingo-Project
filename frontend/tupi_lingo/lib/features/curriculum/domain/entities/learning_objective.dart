import 'package:flutter/foundation.dart';

/// Specific pedagogical learning objective associated with a lesson or concept.
@immutable
class LearningObjective {
  final String id;
  final String curriculumNodeId;
  final String description;
  final String targetConceptNodeId;
  final double targetMastery; // e.g. 0.80
  final bool isAchieved;

  const LearningObjective({
    required this.id,
    required this.curriculumNodeId,
    required this.description,
    required this.targetConceptNodeId,
    this.targetMastery = 0.80,
    this.isAchieved = false,
  });

  LearningObjective copyWith({
    String? id,
    String? curriculumNodeId,
    String? description,
    String? targetConceptNodeId,
    double? targetMastery,
    bool? isAchieved,
  }) {
    return LearningObjective(
      id: id ?? this.id,
      curriculumNodeId: curriculumNodeId ?? this.curriculumNodeId,
      description: description ?? this.description,
      targetConceptNodeId: targetConceptNodeId ?? this.targetConceptNodeId,
      targetMastery: targetMastery ?? this.targetMastery,
      isAchieved: isAchieved ?? this.isAchieved,
    );
  }
}
