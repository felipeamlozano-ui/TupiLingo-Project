import 'package:tupi_lingo/features/linguistic_morphology/domain/entities/morphological_rule.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/value_objects/morpheme_type.dart';

/// Derives new word surfaces by attaching affixes to a Tupi root.
class MorphologyGenerator {
  /// Combines [root] with an affix according to [rule].
  String derive(String root, MorphologicalRule rule) {
    final cleanRoot = root.trim().toLowerCase();
    final surface = rule.morphemeSurface.replaceAll('-', '').trim().toLowerCase();

    if (rule.morphemeType == MorphemeType.prefix) {
      return '$surface$cleanRoot';
    } else if (rule.morphemeType == MorphemeType.suffix) {
      // Handle glottal stop / apostrophe
      if (surface.startsWith("'")) {
        return '$cleanRoot$surface';
      }
      return '$cleanRoot-$surface';
    }
    return '$cleanRoot$surface';
  }
}
