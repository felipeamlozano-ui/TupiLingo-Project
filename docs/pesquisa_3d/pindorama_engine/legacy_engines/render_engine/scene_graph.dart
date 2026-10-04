import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/render_engine/render_node.dart';
import 'package:tupi_lingo/core/render_engine/camera_node.dart';
import 'package:tupi_lingo/core/render_engine/layer_tree.dart';
import 'package:tupi_lingo/core/render_engine/culling/view_frustum_culler.dart';
import 'package:tupi_lingo/core/render_engine/cache/dirty_region_tracker.dart';

/// Concrete root node for the Scene Graph.
class RootSceneNode extends RenderNode {
  RootSceneNode() : super(id: 'root_scene_node');

  @override
  void render(Canvas canvas, Matrix4 transform) {
    // Root container performs no direct drawing
  }
}

/// Hierarchical Scene Graph Engine (RFC-012B Chapter 30).
/// Replaces monolithic redraws with dirty tracking and frustum culling.
class SceneGraph {
  final RootSceneNode root = RootSceneNode();
  final CameraNode camera;
  final LayerTree layerTree = LayerTree();
  final ViewFrustumCuller culler = ViewFrustumCuller();
  final DirtyRegionTracker dirtyTracker = DirtyRegionTracker();

  SceneGraph({CameraNode? camera}) : camera = camera ?? CameraNode();

  /// Adds a node to a specific named layer in the layer tree.
  void addNodeToLayer(String layerName, RenderNode node) {
    var layer = layerTree.getLayer(layerName);
    if (layer == null) {
      layer = RenderLayer(name: layerName, zIndex: layerTree.layers.length * 10);
      layerTree.addLayer(layer);
    }
    layer.add(node);
    root.addChild(node);
    dirtyTracker.markDirty(node.boundsInParent);
  }

  /// Traverses visible layers and executes draw calls with frustum culling.
  void render(Canvas canvas, Size size) {
    camera.viewportSize = size;

    canvas.save();
    camera.apply(canvas);

    final identity = Matrix4.identity();

    for (final layer in layerTree.layers) {
      if (!layer.isVisible) continue;

      // Cull nodes in this layer that are outside the camera frustum
      final visibleNodes = culler.cull(layer.nodes, camera);

      for (final node in visibleNodes) {
        node.renderTree(canvas, identity);
      }
    }

    canvas.restore();
    dirtyTracker.reset();
  }
}
