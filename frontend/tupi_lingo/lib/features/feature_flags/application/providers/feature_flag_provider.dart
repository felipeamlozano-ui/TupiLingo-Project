import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tupi_lingo/features/feature_flags/domain/entities/feature_flag.dart';
import 'package:tupi_lingo/features/feature_flags/domain/entities/flag_ids.dart';
import 'package:tupi_lingo/features/feature_flags/domain/repositories/feature_flag_repository.dart';
import 'package:tupi_lingo/features/feature_flags/data/repositories/feature_flag_repository_impl.dart';

/// Singleton instance of the repository for fast zero-latency access across the app.
final featureFlagRepositoryInstance = FeatureFlagRepositoryImpl();

/// Riverpod provider for FeatureFlagRepository.
final featureFlagRepositoryProvider = Provider<FeatureFlagRepository>((ref) {
  return featureFlagRepositoryInstance;
});

/// Riverpod AsyncNotifier providing reactive state for all feature flags.
class FeatureFlagNotifier extends AsyncNotifier<Map<String, FeatureFlag>> {
  @override
  Future<Map<String, FeatureFlag>> build() async {
    final repo = ref.watch(featureFlagRepositoryProvider);
    if (repo is FeatureFlagRepositoryImpl) {
      await repo.init();
    }
    // Attempt background sync, but return cached immediately
    unawaited(repo.syncFlags().then((updated) {
      state = AsyncData(updated);
    }).catchError((_) {}));

    return repo.getCachedFlags();
  }

  /// Manually triggers a remote refresh.
  Future<void> refresh() async {
    final repo = ref.read(featureFlagRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => repo.syncFlags());
  }

  /// Sets a development override.
  Future<void> setOverride(String flagId, bool isEnabled) async {
    final repo = ref.read(featureFlagRepositoryProvider);
    await repo.setFlagOverride(flagId, isEnabled);
    state = AsyncData(repo.getCachedFlags());
  }

  /// Clears developer overrides.
  Future<void> clearOverrides() async {
    final repo = ref.read(featureFlagRepositoryProvider);
    await repo.clearOverrides();
    state = AsyncData(repo.getCachedFlags());
  }
}

final featureFlagNotifierProvider =
    AsyncNotifierProvider<FeatureFlagNotifier, Map<String, FeatureFlag>>(
  FeatureFlagNotifier.new,
);

/// Family provider to reactively watch if a specific flag is enabled.
final isFlagEnabledProvider = Provider.family<bool, String>((ref, flagId) {
  final flagsState = ref.watch(featureFlagNotifierProvider);
  return flagsState.when(
    data: (flags) => flags[flagId]?.isEnabled ?? false,
    loading: () => ref.read(featureFlagRepositoryProvider).isEnabled(flagId),
    error: (err, st) => ref.read(featureFlagRepositoryProvider).isEnabled(flagId),
  );
});

// ── Convenient per-pillar selectors ──────────────────────────────────────────

final isMorphologyEngineEnabledProvider = Provider<bool>((ref) {
  return ref.watch(isFlagEnabledProvider(FlagIds.morphologyEngineV1));
});

final isSemanticSearchEnabledProvider = Provider<bool>((ref) {
  return ref.watch(isFlagEnabledProvider(FlagIds.semanticSearchV1));
});

final isTruthLayerEnabledProvider = Provider<bool>((ref) {
  return ref.watch(isFlagEnabledProvider(FlagIds.truthLayerV1));
});

final isSceneGraphEnabledProvider = Provider<bool>((ref) {
  return ref.watch(isFlagEnabledProvider(FlagIds.sceneGraphV1));
});

final isWorldStreamingEnabledProvider = Provider<bool>((ref) {
  return ref.watch(isFlagEnabledProvider(FlagIds.worldStreamingV1));
});

final isCustomThemesEnabledProvider = Provider<bool>((ref) {
  return ref.watch(isFlagEnabledProvider(FlagIds.customThemesEnabled));
});

