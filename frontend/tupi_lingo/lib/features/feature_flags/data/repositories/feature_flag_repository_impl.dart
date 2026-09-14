import 'package:tupi_lingo/features/feature_flags/domain/entities/feature_flag.dart';
import 'package:tupi_lingo/features/feature_flags/domain/repositories/feature_flag_repository.dart';
import 'package:tupi_lingo/features/feature_flags/data/datasources/flag_local_datasource.dart';
import 'package:tupi_lingo/features/feature_flags/data/datasources/flag_remote_datasource.dart';

/// Implementation of FeatureFlagRepository combining local persistent storage
/// with remote Supabase synchronization.
class FeatureFlagRepositoryImpl implements FeatureFlagRepository {
  final FlagLocalDataSource _localDataSource;
  final FlagRemoteDataSource _remoteDataSource;

  FeatureFlagRepositoryImpl({
    FlagLocalDataSource? localDataSource,
    FlagRemoteDataSource? remoteDataSource,
  })  : _localDataSource = localDataSource ?? FlagLocalDataSource(),
        _remoteDataSource = remoteDataSource ?? FlagRemoteDataSource();

  /// Initializes the local cache.
  Future<void> init() => _localDataSource.init();

  @override
  Map<String, FeatureFlag> getCachedFlags() => _localDataSource.getAllFlags();

  @override
  FeatureFlag getFlag(String flagId) => _localDataSource.getFlag(flagId);

  @override
  bool isEnabled(String flagId, {String? userId}) {
    final flag = getFlag(flagId);
    return flag.isActiveFor(userId);
  }

  @override
  Future<Map<String, FeatureFlag>> syncFlags() async {
    final remote = await _remoteDataSource.fetchFlags();
    if (remote.isNotEmpty) {
      await _localDataSource.saveFlags(remote);
    }
    return _localDataSource.getAllFlags();
  }

  @override
  Future<void> setFlagOverride(String flagId, bool isEnabled) =>
      _localDataSource.setOverride(flagId, isEnabled);

  @override
  Future<void> clearOverrides() => _localDataSource.clearOverrides();
}
