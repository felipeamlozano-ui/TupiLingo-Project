import 'package:tupi_lingo/features/linguistic_morphology/domain/services/morphology_parser.dart';

/// Validation result emitted by MorphologyValidator.
class MorphologyValidationResult {
  final bool isValid;
  final String? reason;
  final double confidence;

  const MorphologyValidationResult({
    required this.isValid,
    this.reason,
    this.confidence = 1.0,
  });

  static const valid = MorphologyValidationResult(isValid: true, confidence: 1.0);

  static MorphologyValidationResult invalid(String reason, [double confidence = 0.95]) {
    return MorphologyValidationResult(isValid: false, reason: reason, confidence: confidence);
  }
}

/// Validates whether a word structure is morphologically permissible in Tupi.
class MorphologyValidator {
  final MorphologyParser _parser;

  MorphologyValidator({MorphologyParser? parser})
      : _parser = parser ?? MorphologyParser();

  /// Validates [word] against structural constraints.
  MorphologyValidationResult isValidStructure(String word, {int? variantId}) {
    final clean = word.trim().toLowerCase();
    if (clean.isEmpty) {
      return MorphologyValidationResult.invalid('Palavra vazia.');
    }

    // 1. Minimum phonetic constraints in Tupi
    if (clean.length < 2) {
      // Single letter words only valid if root is 'y' (water) or 'i'
      if (clean == 'y' || clean == 'i') {
        return MorphologyValidationResult.valid;
      }
      return MorphologyValidationResult.invalid('Palavras de uma única letra em Tupi são restritas a radicais vocálicos específicos (ex: y).');
    }

    // 2. Prohibited consecutive identical consonants (rare in Tupian phonotactics)
    final doubleConsonants = RegExp(r'[bcdfghjklmnpqrstvwxyz]{3,}');
    if (doubleConsonants.hasMatch(clean)) {
      return MorphologyValidationResult.invalid('Agrupamento consonantal triplo proibido na fonotática Tupi.');
    }

    // 3. Structural decomposition check
    final analysis = _parser.parse(clean, variantId: variantId);

    // Root must not be empty
    if (analysis.rootSurface.isEmpty) {
      return MorphologyValidationResult.invalid('Não foi possível identificar um radical válido.');
    }

    // Check affix stacking: more than 2 prefixes or 3 suffixes is highly atypical in Old Tupi
    if (analysis.prefixes.length > 2) {
      return MorphologyValidationResult.invalid('Empilhamento excessivo de prefixos (${analysis.prefixes.length}).');
    }
    if (analysis.suffixes.length > 3) {
      return MorphologyValidationResult.invalid('Empilhamento excessivo de sufixos (${analysis.suffixes.length}).');
    }

    return MorphologyValidationResult.valid;
  }
}
