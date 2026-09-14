import 'package:tupi_lingo/features/historical_map/domain/streaming/tile_chunk.dart';

/// LRU Memory Cache for loaded World Tile Chunks (RFC-012B Chapter 31).
class TileCache {
  final int maxLoadedChunks;
  final Map<ChunkCoord, TileChunk> _chunks = {};

  TileCache({this.maxLoadedChunks = 25});

  int get loadedCount => _chunks.length;

  TileChunk? get(ChunkCoord coord) {
    final chunk = _chunks[coord];
    chunk?.touch();
    return chunk;
  }

  void put(TileChunk chunk) {
    chunk.touch();
    _chunks[chunk.coord] = chunk;

    // Evict oldest if exceeding capacity
    if (_chunks.length > maxLoadedChunks) {
      _evictLru();
    }
  }

  void remove(ChunkCoord coord) {
    _chunks.remove(coord);
  }

  void clear() {
    _chunks.clear();
  }

  void _evictLru() {
    ChunkCoord? oldestCoord;
    DateTime? oldestTime;

    for (final entry in _chunks.entries) {
      if (oldestTime == null || entry.value.lastAccessed.isBefore(oldestTime)) {
        oldestTime = entry.value.lastAccessed;
        oldestCoord = entry.key;
      }
    }

    if (oldestCoord != null) {
      _chunks.remove(oldestCoord);
    }
  }

  List<TileChunk> getAllLoaded() => _chunks.values.toList();
}
