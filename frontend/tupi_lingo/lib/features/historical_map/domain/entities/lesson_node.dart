import 'package:flutter/foundation.dart';

/// Difficulty level for curriculum lessons
enum LessonDifficulty {
  iniciante('Iniciante'),
  intermediario('Intermediário'),
  avancado('Avançado'),
  mestre('Mestre');

  final String label;
  const LessonDifficulty(this.label);
}

/// Category/format of the lesson
enum LessonType {
  vocabulario('Vocabulário'),
  gramatica('Gramática'),
  escuta('Escuta & Fala'),
  historia('Narrativa Histórica'),
  bossChallenge('Desafio do Pajé');

  final String label;
  const LessonType(this.label);
}

/// Status of the lesson in the user's learning path
enum LessonStatus {
  locked,
  available,
  inProgress,
  completed,
  mastered;

  bool get isActionable => this == available || this == inProgress;
}

/// Represents an individual Lesson (Oca) within a Village Chapter (RFC-012C Patch 1 Chapter 1).
@immutable
class LessonNode {
  final String id;
  final int? licaoId; // Optional backend lesson ID
  final String title;
  final String tupiTitle;
  final String description;
  final LessonDifficulty difficulty;
  final LessonType type;
  final LessonStatus status;
  final int xpReward;
  final int durationMinutes;
  final double progressPercentage;
  final String? practiceTheme; // Theme to launch in ThematicPracticeScreen
  final List<String> prerequisiteIds;

  const LessonNode({
    required this.id,
    this.licaoId,
    required this.title,
    required this.tupiTitle,
    required this.description,
    this.difficulty = LessonDifficulty.iniciante,
    this.type = LessonType.vocabulario,
    this.status = LessonStatus.locked,
    this.xpReward = 40,
    this.durationMinutes = 5,
    this.progressPercentage = 0.0,
    this.practiceTheme,
    this.prerequisiteIds = const [],
  });

  LessonNode copyWith({
    String? id,
    int? licaoId,
    String? title,
    String? tupiTitle,
    String? description,
    LessonDifficulty? difficulty,
    LessonType? type,
    LessonStatus? status,
    int? xpReward,
    int? durationMinutes,
    double? progressPercentage,
    String? practiceTheme,
    List<String>? prerequisiteIds,
  }) {
    return LessonNode(
      id: id ?? this.id,
      licaoId: licaoId ?? this.licaoId,
      title: title ?? this.title,
      tupiTitle: tupiTitle ?? this.tupiTitle,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      type: type ?? this.type,
      status: status ?? this.status,
      xpReward: xpReward ?? this.xpReward,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      practiceTheme: practiceTheme ?? this.practiceTheme,
      prerequisiteIds: prerequisiteIds ?? this.prerequisiteIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'licao_id': licaoId,
        'title': title,
        'tupi_title': tupiTitle,
        'description': description,
        'difficulty': difficulty.name,
        'type': type.name,
        'status': status.name,
        'xp_reward': xpReward,
        'duration_minutes': durationMinutes,
        'progress_percentage': progressPercentage,
        'practice_theme': practiceTheme,
        'prerequisite_ids': prerequisiteIds,
      };
}
