import 'package:flutter_test/flutter_test.dart';
import 'package:tupi_lingo/features/adaptive_leveling/domain/entities/cognitive_profile.dart';
import 'package:tupi_lingo/features/adaptive_leveling/domain/entities/knowledge_state.dart';
import 'package:tupi_lingo/features/adaptive_leveling/domain/services/knowledge_tracing_engine.dart';
import 'package:tupi_lingo/features/adaptive_leveling/domain/services/difficulty_planner.dart';
import 'package:tupi_lingo/features/adaptive_leveling/domain/policies/mastery_transition_policy.dart';
import 'package:tupi_lingo/features/curriculum/domain/entities/curriculum_node.dart';
import 'package:tupi_lingo/features/curriculum/domain/services/prerequisite_engine.dart';
import 'package:tupi_lingo/features/adaptive_srs/domain/services/adaptive_review_scheduler.dart';
import 'package:tupi_lingo/features/thematic_practice/domain/services/semantic_deduplication_engine.dart';

void main() {
  group('Adaptive Leveling Engine (RFC-012A Ch. 6, 7, 8)', () {
    test('KnowledgeTracingEngine increases posterior on correct and decreases on incorrect', () {
      const bkt = KnowledgeTracingEngine();

      // Initial prior = 0.20
      final posteriorCorrect = bkt.updatePosterior(priorL: 0.20, isCorrect: true);
      expect(posteriorCorrect, greaterThan(0.20));

      final posteriorIncorrect = bkt.updatePosterior(priorL: 0.50, isCorrect: false);
      expect(posteriorIncorrect, lessThan(0.50));
    });

    test('KnowledgeTracingEngine evaluates discrete state promotions correctly', () {
      const bkt = KnowledgeTracingEngine();

      final stateInit = bkt.evaluateTransition(
        currentState: KnowledgeStateType.unknown,
        pMastery: 0.15,
        exposures: 0,
        consecutiveStreak: 0,
      );
      expect(stateInit, equals(KnowledgeStateType.unknown));

      final stateRec = bkt.evaluateTransition(
        currentState: KnowledgeStateType.unknown,
        pMastery: 0.25,
        exposures: 1,
        consecutiveStreak: 1,
      );
      expect(stateRec, equals(KnowledgeStateType.recognized));

      final stateMastered = bkt.evaluateTransition(
        currentState: KnowledgeStateType.retained,
        pMastery: 0.92,
        exposures: 4,
        consecutiveStreak: 3,
      );
      expect(stateMastered, equals(KnowledgeStateType.mastered));
    });

    test('DifficultyPlanner computes TRI 3PL and item suitability score', () {
      final planner = DifficultyPlanner();

      final pMatch = planner.computeProbability(theta: 0.0, difficultyB: 0.0);
      expect(pMatch, inInclusiveRange(0.50, 0.70));

      // Easy item for advanced student
      final pEasy = planner.computeProbability(theta: 2.0, difficultyB: -1.0);
      expect(pEasy, greaterThan(0.90));

      final suitability = planner.scoreItemSuitability(theta: 0.5, itemDifficultyB: 0.5);
      expect(suitability, greaterThan(0.70));
    });

    test('MasteryTransitionPolicy handles Ebbinghaus decay and half-life extension', () {
      final policy = MasteryTransitionPolicy();
      final now = DateTime.now();

      final freshState = KnowledgeState(
        nodeId: 'node_1',
        state: KnowledgeStateType.mastered,
        pMastery: 0.95,
        lastReviewedAt: now.subtract(const Duration(hours: 1)),
        halfLifeDays: 5.0,
      );

      final stateNotDecayed = policy.checkTemporalDecay(freshState, now);
      expect(stateNotDecayed.state, equals(KnowledgeStateType.mastered));

      // State reviewed 30 days ago with halfLife of 2 days
      final oldState = KnowledgeState(
        nodeId: 'node_2',
        state: KnowledgeStateType.mastered,
        pMastery: 0.90,
        lastReviewedAt: now.subtract(const Duration(days: 30)),
        halfLifeDays: 2.0,
      );

      final stateDecayed = policy.checkTemporalDecay(oldState, now);
      expect(stateDecayed.state, isIn([KnowledgeStateType.decaying, KnowledgeStateType.forgotten]));

      // Half-life grows on correct review
      final extendedHalfLife = policy.computeNewHalfLife(
        currentHalfLife: 3.0,
        isCorrect: true,
        pMastery: 0.85,
      );
      expect(extendedHalfLife, greaterThan(3.0));
    });

    test('CognitiveProfile computes overall mastery across 8 dimensions', () {
      final profile = CognitiveProfile(
        userId: 'user_test',
        variantId: 1,
        vocabulary: 0.8,
        grammar: 0.6,
        listening: 0.5,
        reading: 0.7,
        cultural: 0.9,
        mythology: 0.8,
        morphology: 0.6,
        speed: 0.7,
        updatedAt: DateTime.now(),
      );

      expect(profile.overallMastery, closeTo(0.70, 0.01));
    });
  });

  group('Curriculum Graph & Topological Prerequisite Engine (RFC-012A Ch. 12)', () {
    test('PrerequisiteEngine unlocks root nodes and locks dependent nodes until threshold met', () {
      final engine = PrerequisiteEngine();

      const rootNode = CurriculumNode(
        id: 'root',
        title: 'Raiz',
        description: 'Primeira lição',
        type: CurriculumNodeType.lesson,
      );

      const dependentNode = CurriculumNode(
        id: 'dep',
        title: 'Dependente',
        description: 'Segunda lição',
        type: CurriculumNodeType.lesson,
        prerequisiteIds: ['root'],
        requiredMasteryThreshold: 0.70,
      );

      expect(
        engine.canUnlockNode(node: rootNode, completedNodeIds: {}, masteryByNode: {}),
        isTrue,
      );

      // Dependent node with 0.50 mastery is locked
      expect(
        engine.canUnlockNode(
          node: dependentNode,
          completedNodeIds: {},
          masteryByNode: {'root': 0.50},
        ),
        isFalse,
      );

      // Dependent node with 0.80 mastery or completion is unlocked
      expect(
        engine.canUnlockNode(
          node: dependentNode,
          completedNodeIds: {},
          masteryByNode: {'root': 0.80},
        ),
        isTrue,
      );
    });

    test('PrerequisiteEngine performs topological sort preserving dependency DAG order', () {
      final engine = PrerequisiteEngine();

      const nodeA = CurriculumNode(id: 'A', title: 'A', description: '', type: CurriculumNodeType.lesson);
      const nodeB = CurriculumNode(id: 'B', title: 'B', description: '', type: CurriculumNodeType.lesson, prerequisiteIds: ['A']);
      const nodeC = CurriculumNode(id: 'C', title: 'C', description: '', type: CurriculumNodeType.lesson, prerequisiteIds: ['B']);

      final sorted = engine.topologicalSort([nodeC, nodeA, nodeB]);
      final ids = sorted.map((n) => n.id).toList();

      expect(ids.indexOf('A'), lessThan(ids.indexOf('B')));
      expect(ids.indexOf('B'), lessThan(ids.indexOf('C')));
    });
  });

  group('Adaptive Spaced Repetition (RFC-012A Ch. 9)', () {
    test('AdaptiveReviewScheduler finds due items and clusters into contextual sessions', () {
      final scheduler = AdaptiveReviewScheduler();
      final now = DateTime.now();

      final states = [
        KnowledgeState(
          nodeId: 'y',
          state: KnowledgeStateType.decaying,
          lastReviewedAt: now.subtract(const Duration(days: 10)),
          halfLifeDays: 2.0,
        ),
        KnowledgeState(
          nodeId: 'paranã',
          state: KnowledgeStateType.learning,
          lastReviewedAt: now.subtract(const Duration(days: 8)),
          halfLifeDays: 2.0,
        ),
        KnowledgeState(
          nodeId: 'oka',
          state: KnowledgeStateType.mastered,
          lastReviewedAt: now.subtract(const Duration(hours: 2)),
          halfLifeDays: 30.0,
        ),
      ];

      final dueItems = scheduler.findItemsDueForReview(states, currentTime: now);
      expect(dueItems.map((s) => s.nodeId), containsAll(['y', 'paranã']));
      expect(dueItems.map((s) => s.nodeId), isNot(contains('oka')));

      final sessions = scheduler.planThematicSessions(
        dueItems: dueItems,
        nodeToClusterMap: {
          'y': 'aguas',
          'paranã': 'aguas',
        },
      );

      expect(sessions, isNotEmpty);
      expect(sessions.first.clusterId, equals('aguas'));
      expect(sessions.first.targetNodeIds, containsAll(['y', 'paranã']));
    });
  });

  group('4D Multi-Level Semantic Deduplication (RFC-012A Ch. 10)', () {
    test('SemanticDeduplicationEngine4D generates deterministic hashes and catches duplicates', () {
      final engine = SemanticDeduplicationEngine4D();

      final hash1 = engine.computeComposite4DHash(
        targetTerm: 'ygara',
        canonicalTranslation: 'canoa',
        nodeId: 'node_ygara',
        category: 'substantivo',
        clusterId: 'embarcacoes',
        variantId: 1,
        territoryId: 'guanabara',
      );

      final hash2 = engine.computeComposite4DHash(
        targetTerm: 'ygara',
        canonicalTranslation: 'canoa',
        nodeId: 'node_ygara',
        category: 'substantivo',
        clusterId: 'embarcacoes',
        variantId: 1,
        territoryId: 'guanabara',
      );

      expect(hash1, equals(hash2));

      // Different category produces completely distinct hash
      final hash3 = engine.computeComposite4DHash(
        targetTerm: 'ygara',
        canonicalTranslation: 'canoa',
        nodeId: 'node_ygara',
        category: 'transporte',
        clusterId: 'embarcacoes',
        variantId: 1,
        territoryId: 'guanabara',
      );
      expect(hash1, isNot(equals(hash3)));

      expect(engine.isDuplicate(hash1), isFalse);
      engine.recordHash(hash1);
      expect(engine.isDuplicate(hash1), isTrue);

      // Catches duplicates in user history window
      expect(engine.isDuplicate(hash3, {hash3}), isTrue);
    });
  });
}
