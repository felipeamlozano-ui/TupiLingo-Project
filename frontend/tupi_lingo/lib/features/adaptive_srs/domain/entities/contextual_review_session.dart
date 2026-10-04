import 'package:flutter/foundation.dart';

/// Sessão de revisão temática que agrupa termos e vocábulos por afinidade semântica.
@immutable
class ContextualReviewSession {
  final String id;
  final String clusterId;
  final String clusterTheme;
  final List<String> targetNodeIds;
  final DateTime scheduledFor;
  final bool isCompleted;

  const ContextualReviewSession({
    required this.id,
    required this.clusterId,
    required this.clusterTheme,
    required this.targetNodeIds,
    required this.scheduledFor,
    this.isCompleted = false,
  });

  ContextualReviewSession copyWith({
    String? id,
    String? clusterId,
    String? clusterTheme,
    List<String>? targetNodeIds,
    DateTime? scheduledFor,
    bool? isCompleted,
  }) {
    return ContextualReviewSession(
      id: id ?? this.id,
      clusterId: clusterId ?? this.clusterId,
      clusterTheme: clusterTheme ?? this.clusterTheme,
      targetNodeIds: targetNodeIds ?? this.targetNodeIds,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
