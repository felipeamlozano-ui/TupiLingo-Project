import 'package:tupi_lingo/features/linguistic_morphology/domain/entities/morphological_analysis.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/services/morphology_parser.dart';

/// Generates clear, pedagogical linguistic explanations for learners.
class MorphologyExplanationEngine {
  final MorphologyParser _parser;

  MorphologyExplanationEngine({MorphologyParser? parser})
      : _parser = parser ?? MorphologyParser();

  /// Produces a rich pedagogical explanation of a Tupi word's morphology.
  String explain(String word, {int? variantId}) {
    final analysis = _parser.parse(word, variantId: variantId);
    return formatAnalysis(analysis);
  }

  /// Formats an existing analysis into an educational string.
  String formatAnalysis(MorphologicalAnalysis analysis) {
    if (analysis.morphemes.isEmpty) {
      return 'Termo simples: "${analysis.wordLabel}"';
    }

    final buffer = StringBuffer();
    buffer.writeln('Composição de "${analysis.wordLabel}":');

    for (final m in analysis.morphemes) {
      buffer.writeln('  • ${m.surface}: ${m.type.displayName} ("${m.meaning}")');
    }

    if (analysis.morphemes.length > 1) {
      final parts = analysis.morphemes.map((m) => '${m.surface} [${m.meaning}]').join(' + ');
      buffer.writeln('Fusão: $parts');
    }

    return buffer.toString().trim();
  }
}
