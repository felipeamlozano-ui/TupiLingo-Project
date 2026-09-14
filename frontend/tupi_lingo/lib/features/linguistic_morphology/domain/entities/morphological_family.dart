import 'package:flutter/foundation.dart';

/// All words sharing a common Tupi root (e.g., 'y' -> ygara, paranã, igarapé).
@immutable
class MorphologicalFamily {
  final String rootSurface;
  final String sharedMeaningPt;
  final int? variantId;
  final List<String> memberWords;

  const MorphologicalFamily({
    required this.rootSurface,
    required this.sharedMeaningPt,
    this.variantId,
    required this.memberWords,
  });

  factory MorphologicalFamily.fromJson(Map<String, dynamic> json) {
    return MorphologicalFamily(
      rootSurface: json['root_surface'] as String? ?? '',
      sharedMeaningPt: json['shared_meaning_pt'] as String? ?? '',
      variantId: (json['variante_id'] as num?)?.toInt() ?? (json['variant_id'] as num?)?.toInt(),
      memberWords: (json['member_words'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'root_surface': rootSurface,
      'shared_meaning_pt': sharedMeaningPt,
      'variante_id': variantId,
      'member_words': memberWords,
    };
  }

  @override
  String toString() => 'MorphologicalFamily($rootSurface ("$sharedMeaningPt"): $memberWords)';
}
