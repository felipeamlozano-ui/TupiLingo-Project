import 'package:tupi_lingo/features/feature_flags/domain/entities/feature_flag.dart';

/// Contract for accessing and synchronizing feature flags.
abstract class FeatureFlagRepository {
  /// Returns all cached feature flags.
  Map<String, FeatureFlag> getCachedFlags();

  /// Gets a specific flag by ID, falling back to default disabled flag if absent.
  FeatureFlag getFlag(String flagId);

  /// Checks if a feature flag is currently active for the optional user ID.
  bool isEnabled(String flagId, {String? userId});

  /// Synchronizes feature flags from remote source (Supabase) to local cache.
  Future<Map<String, FeatureFlag>> syncFlags();

  /// Sets a local override (e.g. for development or debugging).
  Future<void> setFlagOverride(String flagId, bool isEnabled);

  /// Clears local overrides.
  Future<void> clearOverrides();
}
