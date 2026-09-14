import 'package:flutter_test/flutter_test.dart';
import 'package:tupi_lingo/core/world_engine/villages/village_node.dart';
import 'package:tupi_lingo/features/historical_map/domain/entities/lesson_node.dart';
import 'package:tupi_lingo/features/historical_map/domain/services/curriculum_world_graph.dart';
import 'package:tupi_lingo/features/historical_map/presentation/widgets/historical_timeline_slider.dart';

void main() {
  group('Curriculum World Graph (RFC-012C Patch 1 Chapter 1 & 15)', () {
    late CurriculumWorldGraph graph;

    setUp(() {
      graph = CurriculumWorldGraph();
    });

    test('Initializes with canonical territories and villages', () {
      expect(graph.allTerritories.length, greaterThanOrEqualTo(5));
      expect(graph.allVillages.length, greaterThanOrEqualTo(5));

      final piratininga = graph.getVillageById('piratininga');
      expect(piratininga, isNotNull);
      expect(piratininga!.tupiName, equals('Piratininga'));
      expect(piratininga.lessons.length, greaterThanOrEqualTo(4));
      expect(piratininga.hasBossChallenge, isTrue);

      final territory = graph.getTerritoryForVillage('piratininga');
      expect(territory, isNotNull);
      expect(territory!.primaryDialect, equals('Tupi Paulista'));
    });

    test('Filters villages and territories by historical epoch', () {
      // Pre-1500
      final preVillages = graph.getVillagesForEpoch(HistoricalEpoch.pre1500.id);
      expect(preVillages.any((v) => v.id == 'piratininga'), isTrue);
      expect(preVillages.any((v) => v.id == 'sao_vicente'), isTrue);

      // 1555 (França Antártica - Guanabara active)
      final guanabaraEpochVillages = graph.getVillagesForEpoch(HistoricalEpoch.epoch1555.id);
      expect(guanabaraEpochVillages.any((v) => v.id == 'guanabara'), isTrue);

      // 1567 (Confederação dos Tamoios - Ubatuba active)
      final tamoiosEpochVillages = graph.getVillagesForEpoch(HistoricalEpoch.epoch1567.id);
      expect(tamoiosEpochVillages.any((v) => v.id == 'ubatuba'), isTrue);
    });

    test('Progresses lessons and unlocks downstream prerequisites within village', () {
      final piratininga = graph.getVillageById('piratininga')!;
      final l02 = piratininga.lessons.firstWhere((l) => l.id == 'piratininga_02');
      expect(l02.status, equals(LessonStatus.inProgress));

      // Mark piratininga_02 as completed
      final updatedGraph = graph.updateLessonStatus(
        villageId: 'piratininga',
        lessonId: 'piratininga_02',
        newStatus: LessonStatus.completed,
      );

      final updatedPiratininga = updatedGraph.getVillageById('piratininga')!;
      final updatedL02 = updatedPiratininga.lessons.firstWhere((l) => l.id == 'piratininga_02');
      expect(updatedL02.status, equals(LessonStatus.completed));
      expect(updatedL02.progressPercentage, equals(1.0));

      // Check that dependent lesson piratininga_03 is now unlocked (available)
      final updatedL03 = updatedPiratininga.lessons.firstWhere((l) => l.id == 'piratininga_03');
      expect(updatedL03.status, equals(LessonStatus.available));
    });

    test('Transitions village to historical mastery when all lessons are completed', () {
      var currentGraph = graph;
      final piratininga = currentGraph.getVillageById('piratininga')!;

      // Complete all lessons in piratininga
      for (final l in piratininga.lessons) {
        currentGraph = currentGraph.updateLessonStatus(
          villageId: 'piratininga',
          lessonId: l.id,
          newStatus: LessonStatus.completed,
        );
      }

      final masteredVillage = currentGraph.getVillageById('piratininga')!;
      expect(masteredVillage.isMastered, isTrue);
      expect(masteredVillage.stage, equals(VillageEvolutionStage.historica));
      expect(masteredVillage.completionPercentage, equals(1.0));
    });

    test('Finds active main quest correctly', () {
      final activeQuest = graph.getActiveMainQuest();
      expect(activeQuest, isNotNull);
      expect(activeQuest!.isMain, isTrue);
      expect(activeQuest.targetVillageId, equals('piratininga'));
    });
  });
}
