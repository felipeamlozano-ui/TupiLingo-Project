import '../../domain/entities/historical_region.dart';
import '../../domain/repositories/historical_map_repository.dart';
import '../datasources/historical_map_remote_data_source.dart';
import '../models/historical_region_model.dart';

class HistoricalMapRepositoryImpl implements HistoricalMapRepository {
  final HistoricalMapRemoteDataSource remoteDataSource;

  HistoricalMapRepositoryImpl({HistoricalMapRemoteDataSource? remoteDataSource})
      : remoteDataSource = remoteDataSource ?? HistoricalMapRemoteDataSourceImpl();

  @override
  Future<List<HistoricalRegion>> getHistoricalRegions() async {
    return await remoteDataSource.fetchRegions();
  }

  @override
  Future<HistoricalRegion> createRegion(HistoricalRegion region) async {
    final model = HistoricalRegionModel(
      id: region.id,
      name: region.name,
      indigenousNation: region.indigenousNation,
      historicalPeriod: region.historicalPeriod,
      relativeX: region.relativeX,
      relativeY: region.relativeY,
      radius: region.radius,
      culturalSummary: region.culturalSummary,
      vocabularyHighlights: region.vocabularyHighlights,
      isUnlocked: region.isUnlocked,
      requiredLevel: region.requiredLevel,
      lessonsCount: region.lessonsCount,
      completedLessonsCount: region.completedLessonsCount,
    );
    return await remoteDataSource.createRegion(model);
  }

  @override
  Future<HistoricalRegion> updateRegion(HistoricalRegion region) async {
    final model = HistoricalRegionModel(
      id: region.id,
      name: region.name,
      indigenousNation: region.indigenousNation,
      historicalPeriod: region.historicalPeriod,
      relativeX: region.relativeX,
      relativeY: region.relativeY,
      radius: region.radius,
      culturalSummary: region.culturalSummary,
      vocabularyHighlights: region.vocabularyHighlights,
      isUnlocked: region.isUnlocked,
      requiredLevel: region.requiredLevel,
      lessonsCount: region.lessonsCount,
      completedLessonsCount: region.completedLessonsCount,
    );
    return await remoteDataSource.updateRegion(model);
  }

  @override
  Future<bool> deleteRegion(int regionId) async {
    return await remoteDataSource.deleteRegion(regionId);
  }
}
