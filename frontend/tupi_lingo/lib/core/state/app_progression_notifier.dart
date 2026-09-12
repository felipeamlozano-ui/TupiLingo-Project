import 'package:flutter/foundation.dart';

/// Notificador reativo de alta performance para sincronização
/// instantânea de progresso, XP, ofensiva e baús entre telas.
class AppProgressionNotifier extends ChangeNotifier {
  AppProgressionNotifier._();
  static final AppProgressionNotifier instance = AppProgressionNotifier._();

  int _lastCompletedLessonId = 0;
  int _lastUnlockedLessonId = 0;
  int _totalXp = 0;
  int _streakDays = 0;
  int _conchas = 0;
  int _lastConchasGained = 0;
  bool _hasPendingUpdates = false;

  int get lastCompletedLessonId => _lastCompletedLessonId;
  int get lastUnlockedLessonId => _lastUnlockedLessonId;
  int get totalXp => _totalXp;
  int get streakDays => _streakDays;
  int get conchas => _conchas;
  int get lastConchasGained => _lastConchasGained;
  bool get hasPendingUpdates => _hasPendingUpdates;

  /// Disparado após a conclusão de uma lição ou coleta de baú
  void notifyProgressUpdated({
    int? completedLessonId,
    int? unlockedLessonId,
    int? xpGained,
    int? newStreak,
    int? conchasGained,
  }) {
    if (completedLessonId != null) _lastCompletedLessonId = completedLessonId;
    if (unlockedLessonId != null) _lastUnlockedLessonId = unlockedLessonId;
    if (xpGained != null) _totalXp += xpGained;
    if (newStreak != null) _streakDays = newStreak;
    if (conchasGained != null) {
      _conchas += conchasGained;
      _lastConchasGained = conchasGained;
    }

    _hasPendingUpdates = true;
    notifyListeners();
  }

  /// Notificação geral de progressão (lição, teste, variante)
  void notifyProgressionChanged() {
    _hasPendingUpdates = true;
    notifyListeners();
  }

  /// Consome e zera o último ganho de conchas
  int consumeLastConchasGained() {
    final int gained = _lastConchasGained;
    _lastConchasGained = 0;
    return gained;
  }

  /// Consome a flag de atualizações pendentes
  void markUpdatesConsumed() {
    _hasPendingUpdates = false;
    _lastConchasGained = 0;
  }
}

