import 'dart:math';
import 'package:tupi_lingo/features/adaptive_leveling/domain/entities/knowledge_state.dart';
import 'package:tupi_lingo/features/adaptive_srs/domain/entities/contextual_review_session.dart';

/// Contextual Spaced Repetition Scheduler grouping decaying items by cluster (RFC-012A Chapter 9).
class AdaptiveReviewScheduler {
  static const double targetRecallProbability = 0.85;

  /// Calculates estimated retrievability: $R = 2^{-\frac{\Delta t}{S}}$
  double computeRetrievability({
    required DateTime lastReviewedAt,
    required double halfLifeDays,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    final elapsedDays = max(0.01, now.difference(lastReviewedAt).inHours / 24.0);
    final stability = max(0.1, halfLifeDays);
    return pow(2.0, -elapsedDays / stability).toDouble().clamp(0.0, 1.0);
  }

  /// Identifies items whose retrievability has fallen below the target threshold (R < 0.85).
  List<KnowledgeState> findItemsDueForReview(
    List<KnowledgeState> allStates, {
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    return allStates.where((state) {
      if (state.state == KnowledgeStateType.unknown) return false;
      final retrievability = computeRetrievability(
        lastReviewedAt: state.lastReviewedAt,
        halfLifeDays: state.halfLifeDays,
        currentTime: now,
      );
      return retrievability <= targetRecallProbability ||
          state.state == KnowledgeStateType.decaying ||
          state.state == KnowledgeStateType.forgotten;
    }).toList();
  }

  /// Organizes due items into coherent thematic contextual review sessions.
  List<ContextualReviewSession> planThematicSessions({
    required List<KnowledgeState> dueItems,
    required Map<String, String> nodeToClusterMap,
    int maxItemsPerSession = 5,
  }) {
    if (dueItems.isEmpty) return const [];

    // Group items by cluster
    final grouped = <String, List<String>>{};
    for (final item in dueItems) {
      final cluster = nodeToClusterMap[item.nodeId] ?? 'geral';
      grouped.putIfAbsent(cluster, () => []).add(item.nodeId);
    }

    final sessions = <ContextualReviewSession>[];
    int sessionCounter = 1;

    for (final entry in grouped.entries) {
      final clusterId = entry.key;
      final items = entry.value;

      // Chunk items into sessions of max size
      for (int i = 0; i < items.length; i += maxItemsPerSession) {
        final chunk = items.sublist(i, min(i + maxItemsPerSession, items.length));
        sessions.add(
          ContextualReviewSession(
            id: 'rev_session_${sessionCounter++}',
            clusterId: clusterId,
            clusterTheme: 'Revisão Temática: $clusterId',
            targetNodeIds: chunk,
            scheduledFor: DateTime.now(),
          ),
        );
      }
    }

    return sessions;
  }
}
