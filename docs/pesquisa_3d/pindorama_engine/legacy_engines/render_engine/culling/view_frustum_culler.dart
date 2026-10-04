import 'package:tupi_lingo/core/render_engine/render_node.dart';
import 'package:tupi_lingo/core/render_engine/camera_node.dart';

/// Frustum culler that discards nodes outside the camera view frustum.
class ViewFrustumCuller {
  int culledCount = 0;
  int visibleCount = 0;

  /// Filters [nodes] returning only those whose bounds overlap [camera.visibleFrustum].
  List<T> cull<T extends RenderNode>(List<T> nodes, CameraNode camera) {
    final frustum = camera.visibleFrustum;
    final List<T> visible = [];
    culledCount = 0;
    visibleCount = 0;

    for (final node in nodes) {
      if (!node.isVisible) {
        culledCount++;
        continue;
      }
      final bounds = node.boundsInParent;
      if (frustum.overlaps(bounds)) {
        visible.add(node);
        visibleCount++;
      } else {
        culledCount++;
      }
    }
    return visible;
  }
}
