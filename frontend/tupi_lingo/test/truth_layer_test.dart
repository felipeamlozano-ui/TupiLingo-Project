import 'package:flutter_test/flutter_test.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/truth_question_candidate.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/truth_layer_orchestrator.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/truth_layer/truth_repository_impl.dart';

void main() {
  group('Truth Layer (RFC-012B Ch.40 - Zero Hallucination Platform)', () {
    late TruthRepositoryImpl truthRepository;
    late TruthLayerOrchestrator orchestrator;

    setUp(() {
      truthRepository = TruthRepositoryImpl();
      orchestrator = TruthLayerOrchestrator(repository: truthRepository);
    });

    test('valid candidate passes all 6 sequential gates', () async {
      const validCandidate = TruthQuestionCandidate(
        id: 'q_001',
        questionText: 'Como se diz "casa" ou "aldeia" em Tupi Antigo?',
        answerKey: 'oka',
        distractors: ['y', 'pira', 'tatá'],
        explanation: 'Oka é o termo primordial para casa ou aldeia tradicional.',
        variantId: 1,
        groundingSourceType: 'kg_node',
        groundingSourceId: 'node_oka',
        questionHash: 'hash_q001',
      );

      final summary = await orchestrator.validateQuestion(validCandidate);
      expect(summary.isPass, isTrue);
      expect(summary.failedGate, isNull);
      expect(summary.passedGates.length, equals(6));
      expect(truthRepository.inMemoryLogs.last['validation_result'], equals('pass'));
    });

    test('Gate 1 (LexicalValidator) rejects non-attested/hallucinated vocabulary', () async {
      const hallucinatedCandidate = TruthQuestionCandidate(
        id: 'q_002',
        questionText: 'Qual é o termo para árvore?',
        answerKey: 'xuripikando_inventado',
        distractors: ['oka', 'y', 'pira'],
        explanation: 'Termo inventado sem respaldo.',
        variantId: 1,
        questionHash: 'hash_q002',
      );

      final summary = await orchestrator.validateQuestion(hallucinatedCandidate);
      expect(summary.isPass, isFalse);
      expect(summary.failedGate, equals('gate_1_lexical'));
      expect(truthRepository.inMemoryLogs.last['validation_result'], equals('fail'));
      expect(truthRepository.inMemoryLogs.last['failed_gate'], equals('gate_1_lexical'));
    });

    test('Gate 2 (GrammarGuard) rejects phonotactically prohibited structures', () async {
      const illegalPhonotacticsCandidate = TruthQuestionCandidate(
        id: 'q_003',
        questionText: 'Qual é a forma?',
        answerKey: 'oka',
        distractors: ['ptrka', 'y', 'pira'], // 'ptrka' has illegal 3-consonant cluster
        explanation: 'Estrutura ilegal.',
        variantId: 1,
        questionHash: 'hash_q003',
      );

      final summary = await orchestrator.validateQuestion(illegalPhonotacticsCandidate);
      expect(summary.isPass, isFalse);
      expect(summary.failedGate, equals('gate_2_grammar'));
    });

    test('Gate 4 (VariantGuard) rejects cross-variant dialect contamination', () async {
      const crossVariantCandidate = TruthQuestionCandidate(
        id: 'q_004',
        questionText: 'Como se expressa?',
        answerKey: 'oka',
        distractors: ['puranga', 'y', 'pira'], // 'puranga' is Nheengatu dialect, not Old Tupi
        explanation: 'Contaminação de variante.',
        variantId: 1,
        questionHash: 'hash_q004',
      );

      final summary = await orchestrator.validateQuestion(crossVariantCandidate);
      expect(summary.isPass, isFalse);
      expect(summary.failedGate, equals('gate_4_variant'));
      expect(summary.failureReason, contains('Contaminação entre variantes detectada'));
    });

    test('Gate 6 (SemanticValidator) rejects duplicate or identical distractors', () async {
      const duplicateDistractorCandidate = TruthQuestionCandidate(
        id: 'q_005',
        questionText: 'Como se diz casa?',
        answerKey: 'oka',
        distractors: ['oka', 'y', 'pira'], // 'oka' is identical to answer
        explanation: 'Distrator idêntico à resposta.',
        variantId: 1,
        questionHash: 'hash_q005',
      );

      final summary = await orchestrator.validateQuestion(duplicateDistractorCandidate);
      expect(summary.isPass, isFalse);
      expect(summary.failedGate, equals('gate_6_semantic'));
      expect(summary.failureReason, contains('Distrator idêntico'));
    });
  });
}
