import 'package:tupi_lingo/features/curriculum/domain/entities/curriculum_node.dart';
import 'package:tupi_lingo/features/curriculum/domain/repositories/curriculum_repository.dart';

/// In-memory implementation with pre-seeded canonical curriculum milestones.
class CurriculumRepositoryImpl implements CurriculumRepository {
  final Map<String, CurriculumNode> _nodes = {};
  final Map<String, Set<String>> _completedNodesByUser = {};

  CurriculumRepositoryImpl() {
    _seedDefaultCurriculum();
  }

  void _seedDefaultCurriculum() {
    final seed = [
      const CurriculumNode(
        id: 'node_saudacao',
        title: 'Saudações Tradicionais',
        description: 'Primeiros cumprimentos: Kauê, Karai e convivência na aldeia.',
        type: CurriculumNodeType.lesson,
        order: 1,
        isUnlocked: true,
        xpReward: 30,
      ),
      const CurriculumNode(
        id: 'node_natureza',
        title: 'Águas e Florestas',
        description: 'Vocabulário essencial do bioma: Y, Paranã, Ka’a.',
        type: CurriculumNodeType.lesson,
        order: 2,
        prerequisiteIds: ['node_saudacao'],
        requiredMasteryThreshold: 0.60,
        xpReward: 40,
      ),
      const CurriculumNode(
        id: 'node_familia',
        title: 'A Taba e a Família',
        description: 'Relações de parentesco e estrutura social Tupi.',
        type: CurriculumNodeType.lesson,
        order: 3,
        prerequisiteIds: ['node_saudacao'],
        requiredMasteryThreshold: 0.60,
        xpReward: 45,
      ),
      const CurriculumNode(
        id: 'node_boss_piratininga',
        title: 'Desafio do Pajé: Aldeia de Piratininga',
        description: 'Boss challenge integrando vocabulário de acolhimento e natureza.',
        type: CurriculumNodeType.concept,
        order: 4,
        prerequisiteIds: ['node_natureza', 'node_familia'],
        requiredMasteryThreshold: 0.75,
        xpReward: 100,
      ),
    ];

    for (final n in seed) {
      _nodes[n.id] = n;
    }
  }

  @override
  Future<List<CurriculumNode>> getNodesByTerritory(String territoryId) async {
    return _nodes.values.toList()..sort((a, b) => a.order.compareTo(b.order));
  }

  @override
  Future<CurriculumNode?> getNodeById(String nodeId) async {
    return _nodes[nodeId];
  }

  @override
  Future<void> markNodeCompleted(String userId, String nodeId) async {
    final set = _completedNodesByUser.putIfAbsent(userId, () => <String>{});
    set.add(nodeId);
  }

  @override
  Future<Set<String>> getCompletedNodeIds(String userId) async {
    return _completedNodesByUser[userId] ?? const <String>{};
  }
}
