import 'package:flutter_test/flutter_test.dart';
import 'package:tupi_lingo/features/phonology/domain/services/ipa_converter.dart';
import 'package:tupi_lingo/features/linguistic_evolution/language_tree_engine.dart';
import 'package:tupi_lingo/features/cultural_narrative/cultural_narrative_engine.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/ai_evaluation/prompt_builder_v3.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/ai_evaluation/semantic_diversity_engine.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/ai_evaluation/ai_evaluation_orchestrator.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/truth_question_candidate.dart';

void main() {
  group('Phase P3 Architecture Engines', () {
    // ── 1. Phonology & IPA Conversion (Ch. 27) ───────────────────────────────
    test('IPAConverter converts Tupi orthography into canonical IPA', () {
      final converter = IPAConverter();
      final ipaY = converter.convertToIPA('y');
      expect(ipaY, equals('/ɨ/'));

      final ipaYgara = converter.convertToIPA('ygara');
      expect(ipaYgara, contains('ɨ'));
      expect(ipaYgara, contains('ɡ'));

      final ipaGuasu = converter.convertToIPA('gûasu');
      expect(ipaGuasu, contains('ɡʷ'));
    });

    test('PhoneticSimilarityEngine computes phonological closeness', () {
      final similarity = PhoneticSimilarityEngine();
      final simExact = similarity.calculatePhoneticSimilarity('oka', 'oka');
      expect(simExact, equals(1.0));

      final simClose = similarity.calculatePhoneticSimilarity('ygara', 'igara');
      expect(simClose, greaterThan(0.70));
    });

    // ── 2. Linguistic Evolution Tree (Ch. 28) ────────────────────────────────
    test('LanguageTreeEngine traces phylogenetic ancestry', () {
      final engine = LanguageTreeEngine();
      final ancestry = engine.traceAncestry('nheengatu');

      expect(ancestry.isNotEmpty, isTrue);
      expect(ancestry.first.id, equals('proto_tupi'));
      expect(ancestry.last.id, equals('nheengatu'));
      expect(ancestry.any((n) => n.id == 'tupi_antigo'), isTrue);
    });

    // ── 3. Cultural Narrative Engine (Ch. 38) ────────────────────────────────
    test('CulturalNarrativeEngine matches trigger events to historical episodes', () {
      final engine = CulturalNarrativeEngine();
      final episode = engine.checkTrigger(
        type: NarrativeTriggerType.territoryUnlock,
        referenceId: 'terr_guanabara',
      );

      expect(episode, isNotNull);
      expect(episode?.characterName, equals('Cunhambebe'));
      expect(episode?.historicalYear, equals(1554));
    });

    // ── 4. Prompt Builder V3 (Ch. 42) ────────────────────────────────────────
    test('PromptBuilderV3 generates hash-addressed prompt with feedback injection', () {
      final builder = PromptBuilderV3();
      final prompt = builder.buildPrompt(
        theme: 'Navegação e Rios',
        variantId: 1,
        targetTheta: 0.5,
        kgContext: 'ygara (canoa)',
        failedGateFeedback: 'Distrator duplicado',
      );

      expect(prompt, contains('v3.2.0-entropy'));
      expect(prompt, contains('ygara (canoa)'));
      expect(prompt, contains('Distrator duplicado'));

      final hash = builder.computePromptHash(prompt);
      expect(hash.length, equals(64));
    });

    // ── 5. Semantic Diversity & Entropy (Ch. 43) ─────────────────────────────
    test('SemanticDiversityEngine enforces maximum 40% cluster concentration', () {
      final engine = SemanticDiversityEngine();
      // 3 items in 'flora', 1 in 'fauna' (total 4) -> adding 'flora' would be 4/5 = 80% > 40%
      final clusters = ['flora', 'flora', 'flora', 'fauna'];
      expect(engine.canIncludeCluster(clusters, 'flora'), isFalse);
      expect(engine.canIncludeCluster(clusters, 'mitologia'), isTrue);

      final entropy = engine.computeEntropy(clusters);
      expect(entropy, greaterThan(0.0));
    });

    // ── 6. AI Evaluation Orchestrator (Ch. 41) ───────────────────────────────
    test('AIEvaluationOrchestrator computes composite quality score', () {
      final orchestrator = AIEvaluationOrchestrator();
      const candidate = TruthQuestionCandidate(
        id: 'q10',
        questionText: 'O que significa ygara?',
        answerKey: 'ygara',
        distractors: ['oka', 'pira', 'tatá'],
        explanation: 'Ygara é a tradicional canoa dos povos Tupi, esculpida a partir de um único tronco.',
        variantId: 1,
        groundingSourceId: 'kg_node_ygara',
        questionHash: 'hash_10',
      );

      final report = orchestrator.evaluate(candidate);
      expect(report.overallScore, greaterThanOrEqualTo(0.75));
      expect(report.isApproved, isTrue);
    });
  });
}
