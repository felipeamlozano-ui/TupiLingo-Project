import 'package:flutter/material.dart';

/// Tracks rectangular regions of the screen that changed and require repainting.
class DirtyRegionTracker {
  Rect? _dirtyRegion;

  bool get hasDirtyRegions => _dirtyRegion != null && !_dirtyRegion!.isEmpty;

  Rect? get dirtyRegion => _dirtyRegion;

  void markDirty(Rect bounds) {
    if (_dirtyRegion == null) {
      _dirtyRegion = bounds;
    } else {
      _dirtyRegion = _dirtyRegion!.expandToInclude(bounds);
    }
  }

  void markAllDirty(Size viewportSize) {
    _dirtyRegion = Offset.zero & viewportSize;
  }

  void reset() {
    _dirtyRegion = null;
  }
}
