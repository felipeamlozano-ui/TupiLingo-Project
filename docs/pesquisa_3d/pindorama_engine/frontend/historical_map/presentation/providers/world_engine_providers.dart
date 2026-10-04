import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/world_engine/villages/village_node.dart';
import '../../../../core/world_engine/trails/historical_overlay.dart';
import '../../domain/entities/territory_node.dart';
import '../../domain/entities/lesson_node.dart';
import '../../domain/entities/quest_node.dart';
import '../../domain/services/curriculum_world_graph.dart';
import '../widgets/historical_timeline_slider.dart';

// 1. Timeline Notifier & Provider (Active historical epoch)
class TimelineNotifier extends Notifier<HistoricalEpoch> {
  @override
  HistoricalEpoch build() => HistoricalEpoch.epoch1554;

  void setEpoch(HistoricalEpoch epoch) {
    state = epoch;
  }
}

final timelineProvider = NotifierProvider<TimelineNotifier, HistoricalEpoch>(
  TimelineNotifier.new,
);

// 2. Curriculum World Graph Notifier & Provider
class CurriculumWorldGraphNotifier extends Notifier<CurriculumWorldGraph> {
  @override
  CurriculumWorldGraph build() => CurriculumWorldGraph();

  void markLessonCompleted({
    required String villageId,
    required String lessonId,
  }) {
    state = state.updateLessonStatus(
      villageId: villageId,
      lessonId: lessonId,
      newStatus: LessonStatus.completed,
      newProgress: 1.0,
    );
  }

  void updateLessonProgress({
    required String villageId,
    required String lessonId,
    required double progress,
  }) {
    state = state.updateLessonStatus(
      villageId: villageId,
      lessonId: lessonId,
      newStatus: LessonStatus.inProgress,
      newProgress: progress,
    );
  }
}

final curriculumWorldGraphProvider = NotifierProvider<CurriculumWorldGraphNotifier, CurriculumWorldGraph>(
  CurriculumWorldGraphNotifier.new,
);

// 3. Selected Village Notifier & Provider
class SelectedVillageNotifier extends Notifier<VillageNode?> {
  @override
  VillageNode? build() => null;

  void select(VillageNode? village) {
    state = village;
  }
}

final selectedVillageProvider = NotifierProvider<SelectedVillageNotifier, VillageNode?>(
  SelectedVillageNotifier.new,
);

// 4. Selected Territory Provider
final selectedTerritoryProvider = Provider<TerritoryNode?>((ref) {
  final selectedVillage = ref.watch(selectedVillageProvider);
  final graph = ref.watch(curriculumWorldGraphProvider);
  if (selectedVillage != null) {
    return graph.getTerritoryForVillage(selectedVillage.id);
  }
  return graph.allTerritories.firstOrNull;
});

// 5. Active Quest Overlay Provider
final activeQuestProvider = Provider<QuestNode?>((ref) {
  final graph = ref.watch(curriculumWorldGraphProvider);
  return graph.getActiveMainQuest();
});

// 6. Historical Overlays Provider (filtered by epoch)
final activeHistoricalOverlaysProvider = Provider<List<HistoricalOverlay>>((ref) {
  final epoch = ref.watch(timelineProvider);
  return HistoricalOverlay.canonicalOverlays.where((overlay) {
    return overlay.epochId == epoch.id;
  }).toList();
});

// 7. Journey Sheet Visibility State & Notifier
class JourneySheetState {
  final bool isOpen;
  final VillageNode? village;
  final LessonNode? activeLesson;

  const JourneySheetState({
    this.isOpen = false,
    this.village,
    this.activeLesson,
  });

  JourneySheetState copyWith({
    bool? isOpen,
    VillageNode? village,
    LessonNode? activeLesson,
  }) {
    return JourneySheetState(
      isOpen: isOpen ?? this.isOpen,
      village: village ?? this.village,
      activeLesson: activeLesson ?? this.activeLesson,
    );
  }
}

class JourneySheetNotifier extends Notifier<JourneySheetState> {
  @override
  JourneySheetState build() => const JourneySheetState();

  void open(VillageNode village) {
    state = JourneySheetState(isOpen: true, village: village);
  }

  void close() {
    state = const JourneySheetState(isOpen: false);
  }
}

final journeySheetProvider = NotifierProvider<JourneySheetNotifier, JourneySheetState>(
  JourneySheetNotifier.new,
);
