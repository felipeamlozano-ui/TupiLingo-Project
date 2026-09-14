import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tupi_lingo/features/adaptive_srs/domain/entities/contextual_review_session.dart';
import 'package:tupi_lingo/features/adaptive_srs/domain/repositories/adaptive_srs_repository.dart';
import 'package:tupi_lingo/features/adaptive_srs/data/repositories/adaptive_srs_repository_impl.dart';
import 'package:tupi_lingo/features/adaptive_srs/domain/services/adaptive_review_scheduler.dart';

final adaptiveSRSRepositoryProvider = Provider<AdaptiveSRSRepository>((ref) {
  return AdaptiveSRSRepositoryImpl();
});

final adaptiveReviewSchedulerProvider = Provider<AdaptiveReviewScheduler>((ref) {
  return AdaptiveReviewScheduler();
});

final pendingContextualReviewsProvider =
    FutureProvider.family<List<ContextualReviewSession>, String>((ref, userId) async {
  final repo = ref.watch(adaptiveSRSRepositoryProvider);
  return repo.getPendingSessions(userId);
});
