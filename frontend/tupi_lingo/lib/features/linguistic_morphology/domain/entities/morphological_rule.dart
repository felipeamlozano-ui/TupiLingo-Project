import 'package:flutter/foundation.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/value_objects/morpheme_type.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/value_objects/morphological_function.dart';

/// Rule defining valid affixation, derivation, or compounding in Tupi.
@immutable
class MorphologicalRule {
  final String id;
  final String morphemeSurface;
  final MorphemeType morphemeType;
  final MorphologicalFunction morphologicalFunction;
  final String meaningPt;
  final List<String> allomorphs;
  final String? sourceReference;
  final double confidence;
  final int? variantId;

  const MorphologicalRule({
    required this.id,
    required this.morphemeSurface,
    required this.morphemeType,
    required this.morphologicalFunction,
    required this.meaningPt,
    this.allomorphs = const [],
    this.sourceReference,
    this.confidence = 1.0,
    this.variantId,
  });

  factory MorphologicalRule.fromJson(Map<String, dynamic> json) {
    return MorphologicalRule(
      id: json['id'] as String? ?? json['morpheme_surface'] as String? ?? '',
      morphemeSurface: json['morpheme_surface'] as String? ?? '',
      morphemeType: MorphemeType.fromString(json['morpheme_type'] as String? ?? 'suffix'),
      morphologicalFunction: MorphologicalFunction.fromString(
        json['morphological_function'] as String? ?? 'other',
      ),
      meaningPt: json['meaning_pt'] as String? ?? '',
      allomorphs: (json['allomorphs'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      sourceReference: json['source_reference'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      variantId: (json['variante_id'] as num?)?.toInt() ?? (json['variant_id'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'morpheme_surface': morphemeSurface,
      'morpheme_type': morphemeType.name,
      'morphological_function': morphologicalFunction.name,
      'meaning_pt': meaningPt,
      'allomorphs': allomorphs,
      'source_reference': sourceReference,
      'confidence': confidence,
      'variante_id': variantId,
    };
  }

  @override
  String toString() => 'MorphologicalRule($morphemeSurface [$morphemeType] -> $meaningPt)';
}
