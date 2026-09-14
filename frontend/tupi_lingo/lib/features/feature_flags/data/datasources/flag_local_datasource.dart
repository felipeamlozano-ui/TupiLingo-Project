import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tupi_lingo/features/feature_flags/domain/entities/feature_flag.dart';
import 'package:tupi_lingo/features/feature_flags/domain/entities/flag_ids.dart';

/// Local datasource for feature flags with instant synchronous in-memory read
/// backed by persistent disk storage.
class FlagLocalDataSource {
  static const String _storageKey = 'tupilingo_feature_flags_v1';
  static const String _overridesKey = 'tupilingo_flag_overrides_v1';

  final Map<String, FeatureFlag> _memoryCache = {};
  final Map<String, bool> _overrides = {};

  FlagLocalDataSource() {
    _initializeDefaults();
  }

  void _initializeDefaults() {
    for (final id in FlagIds.allFlags) {
      _memoryCache[id] = FeatureFlag(id: id, isEnabled: false);
    }
  }

  /// Loads persisted flags from SharedPreferences into in-memory cache.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawFlags = prefs.getString(_storageKey);
      if (rawFlags != null) {
        final Map<String, dynamic> decoded = jsonDecode(rawFlags) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          if (entry.value is Map<String, dynamic>) {
            final flag = FeatureFlag.fromJson(entry.value as Map<String, dynamic>);
            _memoryCache[flag.id] = flag;
          }
        }
      }

      final rawOverrides = prefs.getString(_overridesKey);
      if (rawOverrides != null) {
        final Map<String, dynamic> decoded = jsonDecode(rawOverrides) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          if (entry.value is bool) {
            _overrides[entry.key] = entry.value as bool;
          }
        }
      }
    } catch (_) {
      // Keep defaults on error
    }
  }

  /// Synchronous retrieval of all flags (overrides applied).
  Map<String, FeatureFlag> getAllFlags() {
    final result = Map<String, FeatureFlag>.from(_memoryCache);
    for (final entry in _overrides.entries) {
      if (result.containsKey(entry.key)) {
        result[entry.key] = result[entry.key]!.copyWith(isEnabled: entry.value);
      } else {
        result[entry.key] = FeatureFlag(id: entry.key, isEnabled: entry.value);
      }
    }
    return result;
  }

  /// Synchronous retrieval of a single flag.
  FeatureFlag getFlag(String flagId) {
    FeatureFlag base = _memoryCache[flagId] ?? FeatureFlag(id: flagId, isEnabled: false);
    if (_overrides.containsKey(flagId)) {
      base = base.copyWith(isEnabled: _overrides[flagId]!);
    }
    return base;
  }

  /// Persists new flags to in-memory cache and disk.
  Future<void> saveFlags(Map<String, FeatureFlag> flags) async {
    _memoryCache.addAll(flags);
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(
        _memoryCache.map((k, v) => MapEntry(k, v.toJson())),
      );
      await prefs.setString(_storageKey, payload);
    } catch (_) {}
  }

  /// Sets a developer override.
  Future<void> setOverride(String flagId, bool isEnabled) async {
    _overrides[flagId] = isEnabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_overridesKey, jsonEncode(_overrides));
    } catch (_) {}
  }

  /// Clears developer overrides.
  Future<void> clearOverrides() async {
    _overrides.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_overridesKey);
    } catch (_) {}
  }
}
