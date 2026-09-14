import 'package:flutter/foundation.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/value_objects/morpheme_type.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/value_objects/morphological_function.dart';

/// Smallest meaningful unit in the Tupi language.
@immutable
class Morpheme {
  final String id;
  final String surface;
  final MorphemeType type;
  final String meaning;
  final MorphologicalFunction function;
  final int? variantId;
  final List<String> allomorphs;

  const Morpheme({
    required this.id,
    required this.surface,
    required this.type,
    required this.meaning,
    required this.function,
    this.variantId,
    this.allomorphs = const [],
  });

  factory Morpheme.fromJson(Map<String, dynamic> json) {
    return Morpheme(
      id: json['id'] as String? ?? json['morpheme_surface'] as String? ?? '',
      surface: json['surface'] as String? ?? json['morpheme_surface'] as String? ?? '',
      type: MorphemeType.fromString(json['type'] as String? ?? json['morpheme_type'] as String? ?? 'root'),
      meaning: json['meaning'] as String? ?? json['meaning_pt'] as String? ?? '',
      function: MorphologicalFunction.fromString(
        json['function'] as String? ?? json['morphological_function'] as String? ?? 'other',
      ),
      variantId: (json['variant_id'] as num?)?.toInt() ?? (json['variante_id'] as num?)?.toInt(),
      allomorphs: (json['allomorphs'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'surface': surface,
      'type': type.name,
      'meaning': meaning,
      'function': function.name,
      'variant_id': variantId,
      'allomorphs': allomorphs,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Morpheme &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          surface == other.surface &&
          type == other.type;

  @override
  int get hashCode => id.hashCode ^ surface.hashCode ^ type.hashCode;

  @override
  String toString() => 'Morpheme($surface [$type] = "$meaning")';
}
