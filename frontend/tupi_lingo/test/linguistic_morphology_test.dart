import 'package:flutter_test/flutter_test.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/services/morphology_parser.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/services/morphology_validator.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/services/morphology_explanation_engine.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/services/morphology_similarity_engine.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/services/morphological_difficulty_estimator.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/value_objects/morpheme_type.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/entities/morphological_rule.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/value_objects/morphological_function.dart';
import 'package:tupi_lingo/features/linguistic_morphology/domain/services/morphology_generator.dart';

void main() {
  group('Linguistic Morphology Engine (RFC-012B Ch.26)', () {
    late MorphologyParser parser;
    late MorphologyValidator validator;
    late MorphologyExplanationEngine explanationEngine;
    late MorphologySimilarityEngine similarityEngine;
    late MorphologicalDifficultyEstimator difficultyEstimator;
    late MorphologyGenerator generator;

    setUp(() {
      parser = MorphologyParser();
      validator = MorphologyValidator(parser: parser);
      explanationEngine = MorphologyExplanationEngine(parser: parser);
      similarityEngine = MorphologySimilarityEngine(parser: parser);
      difficultyEstimator = MorphologicalDifficultyEstimator();
      generator = MorphologyGenerator();
    });

    test('decomposes word with suffix (oka-gûasu)', () {
      final analysis = parser.parse('oka-gûasu');
      expect(analysis.rootSurface, equals('oka'));
      expect(analysis.suffixes.isNotEmpty, isTrue);
      expect(analysis.suffixes.first.surface, equals('gûasu'));
      expect(analysis.suffixes.first.type, equals(MorphemeType.suffix));
      expect(analysis.confidence, greaterThanOrEqualTo(0.90));
    });

    test('decomposes word with prefix (mo-puku)', () {
      final analysis = parser.parse('mo-puku');
      expect(analysis.prefixes.isNotEmpty, isTrue);
      expect(analysis.prefixes.first.surface, equals('mo-'));
      expect(analysis.rootSurface, equals('puku'));
    });

    test('validates permissible and impermissible morphological structures', () {
      final validWord = validator.isValidStructure('oka-gûasu');
      expect(validWord.isValid, isTrue);

      final singleVowelY = validator.isValidStructure('y');
      expect(singleVowelY.isValid, isTrue);

      // 3 consecutive consonants prohibited in Tupi
      final invalidTripleConsonant = validator.isValidStructure('ptrka');
      expect(invalidTripleConsonant.isValid, isFalse);
    });

    test('generates educational pedagogical explanations', () {
      final explanation = explanationEngine.explain('oka-gûasu');
      expect(explanation, contains('Composição de "oka-gûasu"'));
      expect(explanation, contains('oka'));
      expect(explanation, contains('gûasu'));
    });

    test('calculates morphological similarity between words with shared root', () {
      final simSameFamily = similarityEngine.calculateSimilarity('oka', 'oka-gûasu');
      expect(simSameFamily, greaterThanOrEqualTo(0.70));

      final simUnrelated = similarityEngine.calculateSimilarity('oka', 'pira');
      expect(simUnrelated, lessThan(0.50));
    });

    test('estimates difficulty based on affix depth', () {
      final simpleAnalysis = parser.parse('oka');
      final complexAnalysis = parser.parse('mo-oka-gûasu-pûer');

      final simpleDiff = difficultyEstimator.estimateDifficulty(simpleAnalysis);
      final complexDiff = difficultyEstimator.estimateDifficulty(complexAnalysis);

      expect(complexDiff, greaterThan(simpleDiff));
    });

    test('derives derived forms using MorphologyGenerator', () {
      const augRule = MorphologicalRule(
        id: 'aug',
        morphemeSurface: 'gûasu',
        morphemeType: MorphemeType.suffix,
        morphologicalFunction: MorphologicalFunction.augmentative,
        meaningPt: 'grande',
      );
      final derived = generator.derive('itá', augRule);
      expect(derived, equals('itá-gûasu'));
    });
  });
}
