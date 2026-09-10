import '../../domain/entities/user_progress_stats.dart';

class UserProgressStatsModel extends UserProgressStats {
  const UserProgressStatsModel({
    required super.totalXp,
    required super.streakDays,
    super.maiorStreak,
    required super.completedLessons,
    required super.totalLessons,
    required super.totalWords,
    super.accuracyGeral,
    super.tempoTotalMinutos,
    super.isEmptyState,
    required super.weeklyActivity,
    required super.categoryMasteries,
  });

  factory UserProgressStatsModel.fromJson(Map<String, dynamic> json) {
    final weeklyList = (json['weekly_activity'] as List<dynamic>? ?? []).map((w) {
      final m = w as Map<String, dynamic>? ?? {};
      return DailyXpData(
        dayName: m['day_name']?.toString() ?? '',
        dayIndex: (m['day_index'] as num?)?.toInt() ?? 0,
        xp: (m['xp'] as num?)?.toInt() ?? 0,
        lessonsCompleted: (m['lessons_completed'] as num?)?.toInt() ?? 0,
        studyTimeMin: (m['study_time_min'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    final categoriesList = (json['category_masteries'] as List<dynamic>? ?? []).map((c) {
      final m = c as Map<String, dynamic>? ?? {};
      return CategoryMastery(
        category: m['category']?.toString() ?? 'Geral',
        icon: m['icon']?.toString() ?? '🌿',
        masteredWords: (m['mastered_words'] as num?)?.toInt() ?? 0,
        totalWords: (m['total_words'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    final xpTotal = (json['xp_total'] as num?)?.toInt() ?? 0;
    final streakDays = (json['dias_ofensiva'] as num?)?.toInt() ?? 0;
    final maiorStreak = (json['maior_streak'] as num?)?.toInt() ?? streakDays;
    final completedLessons = (json['licoes_concluidas'] as num?)?.toInt() ?? 0;
    final totalLessons = (json['total_licoes'] as num?)?.toInt() ?? 0;
    final totalWords = (json['total_palavras'] as num?)?.toInt() ?? 0;
    final accuracyGeral = (json['accuracy_geral'] as num?)?.toDouble() ?? 0.0;
    final tempoTotalMinutos = (json['tempo_total_minutos'] as num?)?.toInt() ?? 0;

    // Detecção estrita de estado vazio (zero dados reais)
    final bool isEmptyState = json['is_empty_state'] == true ||
        (completedLessons == 0 && xpTotal == 0 && totalWords == 0);

    // Se a lista semanal vier vazia do backend, inicializa os 7 dias zerados
    final authenticWeekly = weeklyList.isNotEmpty ? weeklyList : _emptyWeekDays();

    return UserProgressStatsModel(
      totalXp: xpTotal,
      streakDays: streakDays,
      maiorStreak: maiorStreak,
      completedLessons: completedLessons,
      totalLessons: totalLessons,
      totalWords: totalWords,
      accuracyGeral: accuracyGeral,
      tempoTotalMinutos: tempoTotalMinutos,
      isEmptyState: isEmptyState,
      weeklyActivity: authenticWeekly,
      categoryMasteries: categoriesList,
    );
  }

  /// Gera os 7 dias da semana zerados para contas novas ou sem dados
  static List<DailyXpData> _emptyWeekDays() {
    const days = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    return List.generate(
      7,
      (i) => DailyXpData(dayName: days[i], dayIndex: i, xp: 0, lessonsCompleted: 0),
    );
  }
}
