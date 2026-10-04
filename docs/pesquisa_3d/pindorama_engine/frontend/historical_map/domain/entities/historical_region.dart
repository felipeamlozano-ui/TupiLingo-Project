import 'package:flutter/foundation.dart';

@immutable
class HistoricalRegion {
  final int id;
  final String name;
  final String indigenousNation;
  final String historicalPeriod;
  final double relativeX; // Normalizado 0.0 - 1.0
  final double relativeY; // Normalizado 0.0 - 1.0
  final double radius;
  final String culturalSummary;
  final List<String> vocabularyHighlights;
  final bool isUnlocked;
  final int requiredLevel;
  final int lessonsCount;
  final int completedLessonsCount;

  const HistoricalRegion({
    required this.id,
    required this.name,
    required this.indigenousNation,
    required this.historicalPeriod,
    required this.relativeX,
    required this.relativeY,
    this.radius = 24.0,
    required this.culturalSummary,
    required this.vocabularyHighlights,
    required this.isUnlocked,
    required this.requiredLevel,
    this.lessonsCount = 5,
    this.completedLessonsCount = 0,
  });

  HistoricalRegion copyWith({
    int? id,
    String? name,
    String? indigenousNation,
    String? historicalPeriod,
    double? relativeX,
    double? relativeY,
    double? radius,
    String? culturalSummary,
    List<String>? vocabularyHighlights,
    bool? isUnlocked,
    int? requiredLevel,
    int? lessonsCount,
    int? completedLessonsCount,
  }) {
    return HistoricalRegion(
      id: id ?? this.id,
      name: name ?? this.name,
      indigenousNation: indigenousNation ?? this.indigenousNation,
      historicalPeriod: historicalPeriod ?? this.historicalPeriod,
      relativeX: relativeX ?? this.relativeX,
      relativeY: relativeY ?? this.relativeY,
      radius: radius ?? this.radius,
      culturalSummary: culturalSummary ?? this.culturalSummary,
      vocabularyHighlights: vocabularyHighlights ?? this.vocabularyHighlights,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      requiredLevel: requiredLevel ?? this.requiredLevel,
      lessonsCount: lessonsCount ?? this.lessonsCount,
      completedLessonsCount: completedLessonsCount ?? this.completedLessonsCount,
    );
  }
}
