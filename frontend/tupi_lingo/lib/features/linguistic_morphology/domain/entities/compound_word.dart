import 'package:flutter/foundation.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/entities/morpheme.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/value_objects/compound_type.dart';

/// Compound word formed by the fusion of two or more distinct morphemes.
@immutable
class CompoundWord {
  final String id;
  final String surface;
  final List<Morpheme> components;
  final String combinedMeaning;
  final CompoundType type;

  const CompoundWord({
    required this.id,
    required this.surface,
    required this.components,
    required this.combinedMeaning,
    this.type = CompoundType.subordinate,
  });

  @override
  String toString() => 'CompoundWord($surface: ${components.map((c) => c.surface).join(" + ")} -> $combinedMeaning)';
}
