import 'package:flutter/material.dart';

/// Coordinate pointing to a discrete 1000x1000 world unit chunk.
@immutable
class ChunkCoord {
  final int x;
  final int y;

  const ChunkCoord(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChunkCoord && runtimeType == other.runtimeType && x == other.x && y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;

  @override
  String toString() => 'ChunkCoord($x, $y)';
}

/// A discrete 1000x1000 unit chunk in the Historical Pindorama World (Chapter 31).
class TileChunk {
  static const double chunkSize = 1000.0;

  final ChunkCoord coord;
  final List<String> territoryIds;
  final List<String> pathIds;
  final Map<String, dynamic> metadata;
  bool isLoaded;
  DateTime lastAccessed;

  TileChunk({
    required this.coord,
    this.territoryIds = const [],
    this.pathIds = const [],
    this.metadata = const {},
    this.isLoaded = false,
  }) : lastAccessed = DateTime.now();

  Rect get worldBounds => Rect.fromLTWH(
        coord.x * chunkSize,
        coord.y * chunkSize,
        chunkSize,
        chunkSize,
      );

  void touch() {
    lastAccessed = DateTime.now();
  }
}
