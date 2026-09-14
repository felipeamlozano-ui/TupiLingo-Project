import 'package:tupi_lingo/features/adaptive_srs/domain/entities/contextual_review_session.dart';
import 'package:tupi_lingo/features/adaptive_srs/domain/repositories/adaptive_srs_repository.dart';

/// In-memory cache implementation of AdaptiveSRSRepository.
class AdaptiveSRSRepositoryImpl implements AdaptiveSRSRepository {
  final Map<String, List<ContextualReviewSession>> _userSessions = {};

  @override
  Future<List<ContextualReviewSession>> getPendingSessions(String userId) async {
    final list = _userSessions[userId] ?? const [];
    return list.where((s) => !s.isCompleted).toList();
  }

  @override
  Future<void> saveSessions(String userId, List<ContextualReviewSession> sessions) async {
    _userSessions[userId] = List.from(sessions);
  }

  @override
  Future<void> completeSession(String userId, String sessionId) async {
    final list = _userSessions[userId];
    if (list != null) {
      final index = list.indexWhere((s) => s.id == sessionId);
      if (index != -1) {
        list[index] = list[index].copyWith(isCompleted: true);
      }
    }
  }
}
