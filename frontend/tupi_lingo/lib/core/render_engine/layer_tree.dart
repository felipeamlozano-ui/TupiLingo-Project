import 'package:tupi_lingo/core/render_engine/render_node.dart';

/// Named render layer with an explicit z-index in the composite tree.
class RenderLayer {
  final String name;
  final int zIndex;
  final List<RenderNode> nodes = [];
  bool isVisible;

  RenderLayer({
    required this.name,
    required this.zIndex,
    this.isVisible = true,
  });

  void add(RenderNode node) {
    node.zIndex = zIndex;
    nodes.add(node);
  }

  void remove(RenderNode node) {
    nodes.remove(node);
  }

  void clear() {
    nodes.clear();
  }
}

/// Organizes nodes into ordered render layers (e.g. background, terrain, paths, entities, fog, UI).
class LayerTree {
  final List<RenderLayer> _layers = [];

  List<RenderLayer> get layers => List.unmodifiable(_layers);

  void addLayer(RenderLayer layer) {
    _layers.add(layer);
    _sortLayers();
  }

  RenderLayer? getLayer(String name) {
    for (final l in _layers) {
      if (l.name == name) return l;
    }
    return null;
  }

  void _sortLayers() {
    _layers.sort((a, b) => a.zIndex.compareTo(b.zIndex));
  }
}
