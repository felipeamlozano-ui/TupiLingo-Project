import '../entities/historical_region.dart';

abstract class HistoricalMapRepository {
  Future<List<HistoricalRegion>> getHistoricalRegions();
  Future<HistoricalRegion> createRegion(HistoricalRegion region);
  Future<HistoricalRegion> updateRegion(HistoricalRegion region);
  Future<bool> deleteRegion(int regionId);
}
