import 'package:flutter_test/flutter_test.dart';
import 'package:tupi_lingo/features/feature_flags/domain/entities/feature_flag.dart';
import 'package:tupi_lingo/features/feature_flags/domain/entities/flag_ids.dart';
import 'package:tupi_lingo/features/feature_flags/data/datasources/flag_local_datasource.dart';
import 'package:tupi_lingo/features/feature_flags/data/repositories/feature_flag_repository_impl.dart';

void main() {
  group('Feature Flag Platform (RFC-012B Ch.47)', () {
    test('all 18 canonical flags are registered in FlagIds', () {
      expect(FlagIds.allFlags.length, 18);
      expect(FlagIds.allFlags.contains(FlagIds.morphologyEngineV1), isTrue);
      expect(FlagIds.allFlags.contains(FlagIds.semanticSearchV1), isTrue);
      expect(FlagIds.allFlags.contains(FlagIds.truthLayerV1), isTrue);
    });

    test('FeatureFlag defaults to disabled', () {
      const flag = FeatureFlag(id: FlagIds.morphologyEngineV1);
      expect(flag.isEnabled, isFalse);
      expect(flag.isActiveFor('user-123'), isFalse);
    });

    test('FeatureFlag evaluates rollout percentage deterministically', () {
      const flag50 = FeatureFlag(
        id: FlagIds.morphologyEngineV1,
        isEnabled: true,
        rolloutPercent: 50,
      );

      // Same user should consistently receive identical outcome
      final res1 = flag50.isActiveFor('user-abc');
      final res2 = flag50.isActiveFor('user-abc');
      expect(res1, equals(res2));

      // 100% rollout always returns true when enabled
      const flag100 = FeatureFlag(
        id: FlagIds.morphologyEngineV1,
        isEnabled: true,
        rolloutPercent: 100,
      );
      expect(flag100.isActiveFor('any-user'), isTrue);
    });

    test('Repository handles local defaults and overrides', () async {
      final localSource = FlagLocalDataSource();
      final repo = FeatureFlagRepositoryImpl(localDataSource: localSource);

      // Default is disabled
      expect(repo.isEnabled(FlagIds.morphologyEngineV1), isFalse);

      // Set developer override
      await repo.setFlagOverride(FlagIds.morphologyEngineV1, true);
      expect(repo.isEnabled(FlagIds.morphologyEngineV1), isTrue);

      // Clear override
      await repo.clearOverrides();
      expect(repo.isEnabled(FlagIds.morphologyEngineV1), isFalse);
    });
  });
}
