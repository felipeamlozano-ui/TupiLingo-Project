import '../entities/user_progress_stats.dart';

abstract class DashboardRepository {
  Future<UserProgressStats> getUserProgressStats({bool forceRefresh = false});
}
