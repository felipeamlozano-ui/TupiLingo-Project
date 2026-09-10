/// Serviço de domínio para cálculo e validação de regras de negócio
/// de progressão estrita, desbloqueio de lições e baús de recompensa.
class ProgressionDomainService {
  const ProgressionDomainService();

  /// Verifica se uma lição pode ser iniciada pelo aluno
  bool isLessonAccessible({
    required int lessonId,
    required List<int> allOrderedLessonIds,
    required Set<int> completedLessonIds,
  }) {
    if (completedLessonIds.contains(lessonId)) return true;
    if (allOrderedLessonIds.isEmpty) return false;

    final index = allOrderedLessonIds.indexOf(lessonId);
    if (index == -1) return false;
    if (index == 0) return true; // Primeira lição da trilha sempre acessível

    final previousLessonId = allOrderedLessonIds[index - 1];
    return completedLessonIds.contains(previousLessonId);
  }

  /// Verifica se o baú cultural de um marco está liberado para abertura
  bool isChestUnlocked({
    required List<int> chapterLessonIds,
    required Set<int> completedLessonIds,
    int requiredLessonsCount = 2,
  }) {
    if (chapterLessonIds.isEmpty) return false;
    final limit = chapterLessonIds.length < requiredLessonsCount
        ? chapterLessonIds.length
        : requiredLessonsCount;
    final requiredLessons = chapterLessonIds.take(limit);
    return requiredLessons.every(completedLessonIds.contains);
  }

  /// Calcula a porcentagem de conclusão de um capítulo
  double calculateChapterProgress({
    required int totalLessons,
    required int completedLessons,
  }) {
    if (totalLessons <= 0) return 0.0;
    return (completedLessons / totalLessons).clamp(0.0, 1.0);
  }
}
