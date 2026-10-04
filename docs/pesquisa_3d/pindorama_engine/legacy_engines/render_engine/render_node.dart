import 'package:flutter/material.dart';

/// Base abstract node in the hierarchical Scene Graph (RFC-012B Chapter 30).
abstract class RenderNode {
  final String id;
  RenderNode? parent;
  final List<RenderNode> _children = [];

  Offset position;
  Size size;
  double scale;
  double rotation; // Radians
  double opacity;
  bool isVisible;
  bool isDirty;
  int zIndex;

  RenderNode({
    required this.id,
    this.position = Offset.zero,
    this.size = Size.zero,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.opacity = 1.0,
    this.isVisible = true,
    this.isDirty = true,
    this.zIndex = 0,
  });

  List<RenderNode> get children => List.unmodifiable(_children);

  void addChild(RenderNode child) {
    child.parent = this;
    _children.add(child);
    markDirty();
  }

  void removeChild(RenderNode child) {
    if (_children.remove(child)) {
      child.parent = null;
      markDirty();
    }
  }

  void markDirty() {
    isDirty = true;
    parent?.markDirty();
  }

  /// Bounding box in local coordinate space.
  Rect get localBounds => Rect.fromLTWH(0, 0, size.width, size.height);

  /// Bounding box in parent coordinate space.
  Rect get boundsInParent => Rect.fromLTWH(position.dx, position.dy, size.width * scale, size.height * scale);

  /// Performs the draw call for this node.
  void render(Canvas canvas, Matrix4 transform);

  /// Traverses and renders this node and its children.
  void renderTree(Canvas canvas, Matrix4 parentTransform) {
    if (!isVisible || opacity <= 0.0) return;

    canvas.save();

    // Compute local matrix
    final localTransform = Matrix4.copy(parentTransform)
      ..multiply(Matrix4.translationValues(position.dx, position.dy, 0.0))
      ..rotateZ(rotation)
      ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0));

    render(canvas, localTransform);

    // Sort children by zIndex
    final sortedChildren = List<RenderNode>.from(_children)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    for (final child in sortedChildren) {
      child.renderTree(canvas, localTransform);
    }

    canvas.restore();
    isDirty = false;
  }
}
