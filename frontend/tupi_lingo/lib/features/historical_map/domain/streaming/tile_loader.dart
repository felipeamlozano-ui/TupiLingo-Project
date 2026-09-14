import 'package:flutter/material.dart';
import 'package:tupi_lingo/features/historical_map/domain/streaming/tile_chunk.dart';
import 'package:tupi_lingo/features/historical_map/domain/streaming/tile_cache.dart';

/// Predictively streams world tile chunks based on camera position.
class TileLoader {
  final TileCache cache;

  TileLoader({TileCache? cache}) : cache = cache ?? TileCache();

  /// Identifies chunk coordinates needed for [viewportBounds] plus a 1-ring margin.
  Set<ChunkCoord> computeRequiredChunks(Rect viewportBounds) {
    final startX = (viewportBounds.left / TileChunk.chunkSize).floor() - 1;
    final endX = (viewportBounds.right / TileChunk.chunkSize).floor() + 1;
    final startY = (viewportBounds.top / TileChunk.chunkSize).floor() - 1;
    final endY = (viewportBounds.bottom / TileChunk.chunkSize).floor() + 1;

    final Set<ChunkCoord> coords = {};
    for (int x = startX; x <= endX; x++) {
      for (int y = startY; y <= endY; y++) {
        coords.add(ChunkCoord(x, y));
      }
    }
    return coords;
  }

  /// Synchronously loads or retrieves chunks for current viewport.
  List<TileChunk> updateViewport(Rect viewportBounds) {
    final required = computeRequiredChunks(viewportBounds);
    final List<TileChunk> activeChunks = [];

    for (final coord in required) {
      var chunk = cache.get(coord);
      if (chunk == null) {
        // Create and cache newly visible chunk
        chunk = TileChunk(
          coord: coord,
          isLoaded: true,
        );
        cache.put(chunk);
      }
      activeChunks.add(chunk);
    }

    return activeChunks;
  }
}
