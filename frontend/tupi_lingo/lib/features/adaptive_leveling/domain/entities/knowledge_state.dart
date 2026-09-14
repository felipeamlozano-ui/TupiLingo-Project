import 'package:flutter/foundation.dart';

/// Discrete finite mastery states for knowledge units (RFC-012A Chapter 6).
enum KnowledgeStateType {
  unknown,
  exposed,
  recognized,
  learning,
  retained,
  mastered,
  decaying,
  forgotten,
}

/// Represents the learner's dynamic mastery state for a specific knowledge node.
@immutable
class KnowledgeState {
  final String nodeId;
  final KnowledgeStateType state;
  final double pMastery; // Probability of mastery [0.0, 1.0] from BKT
  final int totalExposures;
  final int correctResponses;
  final int consecutiveStreak;
  final DateTime lastReviewedAt;
  final double halfLifeDays; // Memory stability in days

  const KnowledgeState({
    required this.nodeId,
    this.state = KnowledgeStateType.unknown,
    this.pMastery = 0.15,
    this.totalExposures = 0,
    this.correctResponses = 0,
    this.consecutiveStreak = 0,
    required this.lastReviewedAt,
    this.halfLifeDays = 1.0,
  });

  KnowledgeState copyWith({
    String? nodeId,
    KnowledgeStateType? state,
    double? pMastery,
    int? totalExposures,
    int? correctResponses,
    int? consecutiveStreak,
    DateTime? lastReviewedAt,
    double? halfLifeDays,
  }) {
    return KnowledgeState(
      nodeId: nodeId ?? this.nodeId,
      state: state ?? this.state,
      pMastery: (pMastery ?? this.pMastery).clamp(0.0, 1.0),
      totalExposures: totalExposures ?? this.totalExposures,
      correctResponses: correctResponses ?? this.correctResponses,
      consecutiveStreak: consecutiveStreak ?? this.consecutiveStreak,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      halfLifeDays: halfLifeDays ?? this.halfLifeDays,
    );
  }

  Map<String, dynamic> toJson() => {
    'node_id': nodeId,
    'state': state.name,
    'p_mastery': pMastery,
    'total_exposures': totalExposures,
    'correct_responses': correctResponses,
    'consecutive_streak': consecutiveStreak,
    'last_reviewed_at': lastReviewedAt.toIso8601String(),
    'half_life_days': halfLifeDays,
  };

  factory KnowledgeState.fromJson(Map<String, dynamic> json) {
    return KnowledgeState(
      nodeId: json['node_id'] as String? ?? '',
      state: KnowledgeStateType.values.firstWhere(
        (e) => e.name == (json['state'] as String?),
        orElse: () => KnowledgeStateType.unknown,
      ),
      pMastery: (json['p_mastery'] as num?)?.toDouble() ?? 0.15,
      totalExposures: (json['total_exposures'] as num?)?.toInt() ?? 0,
      correctResponses: (json['correct_responses'] as num?)?.toInt() ?? 0,
      consecutiveStreak: (json['consecutive_streak'] as num?)?.toInt() ?? 0,
      lastReviewedAt: json['last_reviewed_at'] != null
          ? DateTime.parse(json['last_reviewed_at'] as String)
          : DateTime.now(),
      halfLifeDays: (json['half_life_days'] as num?)?.toDouble() ?? 1.0,
    );
  }
}
