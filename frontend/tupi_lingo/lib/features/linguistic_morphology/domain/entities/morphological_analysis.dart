import 'package:flutter/foundation.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/entities/morpheme.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/value_objects/morpheme_type.dart';

/// The result of decomposing and validating a Tupi word's morphological structure.
@immutable
class MorphologicalAnalysis {
  final String wordLabel;
  final String rootSurface;
  final List<Morpheme> morphemes;
  final double confidence;
  final String explanationPt;
  final int? variantId;

  const MorphologicalAnalysis({
    required this.wordLabel,
    required this.rootSurface,
    required this.morphemes,
    this.confidence = 1.0,
    required this.explanationPt,
    this.variantId,
  });

  List<Morpheme> get prefixes =>
      morphemes.where((m) => m.type == MorphemeType.prefix).toList();

  List<Morpheme> get suffixes =>
      morphemes.where((m) => m.type == MorphemeType.suffix).toList();

  List<Morpheme> get roots =>
      morphemes.where((m) => m.type == MorphemeType.root).toList();

  factory MorphologicalAnalysis.fromJson(Map<String, dynamic> json) {
    final morphemesList = (json['morphemes'] as List<dynamic>?)
            ?.map((e) => Morpheme.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    return MorphologicalAnalysis(
      wordLabel: json['word_label'] as String? ?? '',
      rootSurface: json['root_surface'] as String? ?? '',
      morphemes: morphemesList,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      explanationPt: json['explanation_pt'] as String? ?? '',
      variantId: (json['variante_id'] as num?)?.toInt() ?? (json['variant_id'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'word_label': wordLabel,
      'root_surface': rootSurface,
      'morphemes': morphemes.map((m) => m.toJson()).toList(),
      'confidence': confidence,
      'explanation_pt': explanationPt,
      'variante_id': variantId,
    };
  }

  @override
  String toString() =>
      'MorphologicalAnalysis($wordLabel: ${morphemes.map((m) => m.surface).join(" + ")} -> "$explanationPt")';
}
