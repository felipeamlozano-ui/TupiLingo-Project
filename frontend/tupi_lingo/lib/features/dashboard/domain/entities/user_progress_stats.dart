import 'package:flutter/foundation.dart';

@immutable
class DailyXpData {
  final String dayName;
  final int dayIndex; // 0: Seg ... 6: Dom
  final int xp;
  final int lessonsCompleted;
  final int studyTimeMin;

  const DailyXpData({
    required this.dayName,
    required this.dayIndex,
    required this.xp,
    required this.lessonsCompleted,
    this.studyTimeMin = 0,
  });
}

@immutable
class CategoryMastery {
  final String category;
  final String icon;
  final int masteredWords;
  final int totalWords;

  const CategoryMastery({
    required this.category,
    required this.icon,
    required this.masteredWords,
    required this.totalWords,
  });

  double get percentage => totalWords > 0 ? (masteredWords / totalWords).clamp(0.0, 1.0) : 0.0;
}

@immutable
class UserProgressStats {
  final int totalXp;
  final int streakDays;
  final int maiorStreak;
  final int completedLessons;
  final int totalLessons;
  final int totalWords;
  final double accuracyGeral;
  final int tempoTotalMinutos;
  final bool isEmptyState;
  final List<DailyXpData> weeklyActivity;
  final List<CategoryMastery> categoryMasteries;

  const UserProgressStats({
    required this.totalXp,
    required this.streakDays,
    this.maiorStreak = 0,
    required this.completedLessons,
    required this.totalLessons,
    required this.totalWords,
    this.accuracyGeral = 0.0,
    this.tempoTotalMinutos = 0,
    this.isEmptyState = false,
    required this.weeklyActivity,
    required this.categoryMasteries,
  });

  double get overallProgressPercentage =>
      totalLessons > 0 ? (completedLessons / totalLessons).clamp(0.0, 1.0) : 0.0;
}
