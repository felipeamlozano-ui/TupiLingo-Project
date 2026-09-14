import 'package:flutter/foundation.dart';

/// 8-Dimensional Cognitive Mastery Profile for TupiLingo (RFC-012A Chapter 5).
@immutable
class CognitiveProfile {
  final String userId;
  final int variantId;
  final double vocabulary; // [0.0, 1.0]
  final double grammar;    // [0.0, 1.0]
  final double listening;  // [0.0, 1.0]
  final double reading;    // [0.0, 1.0]
  final double cultural;   // [0.0, 1.0]
  final double mythology;  // [0.0, 1.0]
  final double morphology; // [0.0, 1.0]
  final double speed;      // [0.0, 1.0]
  final DateTime updatedAt;

  const CognitiveProfile({
    required this.userId,
    required this.variantId,
    this.vocabulary = 0.15,
    this.grammar = 0.10,
    this.listening = 0.10,
    this.reading = 0.15,
    this.cultural = 0.20,
    this.mythology = 0.15,
    this.morphology = 0.10,
    this.speed = 0.50,
    required this.updatedAt,
  });

  /// Factory creating an initial baseline profile for new learners.
  factory CognitiveProfile.initial({required String userId, required int variantId}) {
    return CognitiveProfile(
      userId: userId,
      variantId: variantId,
      updatedAt: DateTime.now(),
    );
  }

  /// Average overall mastery across all 8 dimensions.
  double get overallMastery {
    return (vocabulary + grammar + listening + reading + cultural + mythology + morphology + speed) / 8.0;
  }

  CognitiveProfile copyWith({
    String? userId,
    int? variantId,
    double? vocabulary,
    double? grammar,
    double? listening,
    double? reading,
    double? cultural,
    double? mythology,
    double? morphology,
    double? speed,
    DateTime? updatedAt,
  }) {
    return CognitiveProfile(
      userId: userId ?? this.userId,
      variantId: variantId ?? this.variantId,
      vocabulary: (vocabulary ?? this.vocabulary).clamp(0.0, 1.0),
      grammar: (grammar ?? this.grammar).clamp(0.0, 1.0),
      listening: (listening ?? this.listening).clamp(0.0, 1.0),
      reading: (reading ?? this.reading).clamp(0.0, 1.0),
      cultural: (cultural ?? this.cultural).clamp(0.0, 1.0),
      mythology: (mythology ?? this.mythology).clamp(0.0, 1.0),
      morphology: (morphology ?? this.morphology).clamp(0.0, 1.0),
      speed: (speed ?? this.speed).clamp(0.0, 1.0),
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'variant_id': variantId,
    'vocabulary': vocabulary,
    'grammar': grammar,
    'listening': listening,
    'reading': reading,
    'cultural': cultural,
    'mythology': mythology,
    'morphology': morphology,
    'speed': speed,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory CognitiveProfile.fromJson(Map<String, dynamic> json) {
    return CognitiveProfile(
      userId: json['user_id'] as String? ?? '',
      variantId: (json['variant_id'] as num?)?.toInt() ?? 1,
      vocabulary: (json['vocabulary'] as num?)?.toDouble() ?? 0.15,
      grammar: (json['grammar'] as num?)?.toDouble() ?? 0.10,
      listening: (json['listening'] as num?)?.toDouble() ?? 0.10,
      reading: (json['reading'] as num?)?.toDouble() ?? 0.15,
      cultural: (json['cultural'] as num?)?.toDouble() ?? 0.20,
      mythology: (json['mythology'] as num?)?.toDouble() ?? 0.15,
      morphology: (json['morphology'] as num?)?.toDouble() ?? 0.10,
      speed: (json['speed'] as num?)?.toDouble() ?? 0.50,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
    );
  }
}
