import 'package:tupi_lingo/features/adaptive_srs/domain/entities/contextual_review_session.dart';

/// Contract for Adaptive SRS review persistence and scheduling.
abstract class AdaptiveSRSRepository {
  Future<List<ContextualReviewSession>> getPendingSessions(String userId);
  Future<void> saveSessions(String userId, List<ContextualReviewSession> sessions);
  Future<void> completeSession(String userId, String sessionId);
}
