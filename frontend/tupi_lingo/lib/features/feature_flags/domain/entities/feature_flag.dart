import 'package:flutter/foundation.dart';

/// RFC-012B Chapter 47: Domain representation of an enterprise Feature Flag.
@immutable
class FeatureFlag {
  final String id;
  final bool isEnabled;
  final int rolloutPercent;
  final String? experimentId;
  final String? description;
  final String pillar;
  final DateTime? updatedAt;

  const FeatureFlag({
    required this.id,
    this.isEnabled = false,
    this.rolloutPercent = 0,
    this.experimentId,
    this.description,
    this.pillar = 'P1',
    this.updatedAt,
  });

  /// Evaluates whether this flag is active for a given client/user ID.
  /// If [isEnabled] is false, always returns false.
  /// If [rolloutPercent] >= 100, always returns true.
  /// If [rolloutPercent] <= 0, returns [isEnabled].
  /// Otherwise computes deterministic percentage hash on [userId].
  bool isActiveFor(String? userId) {
    if (!isEnabled) return false;
    if (rolloutPercent >= 100) return true;
    if (rolloutPercent <= 0) return true;
    if (userId == null || userId.isEmpty) return false;

    // Deterministic hash mod 100 based on flagId + userId
    final hashKey = '$id:$userId';
    int hash = 0;
    for (int i = 0; i < hashKey.length; i++) {
      hash = (31 * hash + hashKey.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return (hash % 100) < rolloutPercent;
  }

  factory FeatureFlag.fromJson(Map<String, dynamic> json) {
    return FeatureFlag(
      id: json['flag_id'] as String? ?? json['id'] as String,
      isEnabled: json['is_enabled'] as bool? ?? false,
      rolloutPercent: (json['rollout_percent'] as num?)?.toInt() ?? 0,
      experimentId: json['experiment_id'] as String?,
      description: json['description'] as String?,
      pillar: json['pillar'] as String? ?? 'P1',
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'flag_id': id,
      'is_enabled': isEnabled,
      'rollout_percent': rolloutPercent,
      'experiment_id': experimentId,
      'description': description,
      'pillar': pillar,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  FeatureFlag copyWith({
    String? id,
    bool? isEnabled,
    int? rolloutPercent,
    String? experimentId,
    String? description,
    String? pillar,
    DateTime? updatedAt,
  }) {
    return FeatureFlag(
      id: id ?? this.id,
      isEnabled: isEnabled ?? this.isEnabled,
      rolloutPercent: rolloutPercent ?? this.rolloutPercent,
      experimentId: experimentId ?? this.experimentId,
      description: description ?? this.description,
      pillar: pillar ?? this.pillar,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeatureFlag &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          isEnabled == other.isEnabled &&
          rolloutPercent == other.rolloutPercent;

  @override
  int get hashCode => id.hashCode ^ isEnabled.hashCode ^ rolloutPercent.hashCode;

  @override
  String toString() =>
      'FeatureFlag(id: $id, enabled: $isEnabled, rollout: $rolloutPercent%)';
}
