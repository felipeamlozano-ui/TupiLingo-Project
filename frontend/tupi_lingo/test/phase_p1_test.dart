import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/render_engine/render_node.dart';
import 'package:tupi_lingo/core/render_engine/camera_node.dart';
import 'package:tupi_lingo/core/render_engine/culling/view_frustum_culler.dart';
import 'package:tupi_lingo/features/historical_map/domain/streaming/tile_chunk.dart';
import 'package:tupi_lingo/features/historical_map/domain/streaming/tile_cache.dart';
import 'package:tupi_lingo/features/historical_map/domain/streaming/tile_loader.dart';
import 'package:tupi_lingo/features/runtime_scheduler/task_priority.dart';
import 'package:tupi_lingo/features/runtime_scheduler/battery_aware_scheduler.dart';
import 'package:tupi_lingo/features/runtime_scheduler/runtime_orchestrator.dart';
import 'package:tupi_lingo/features/knowledge_graph/domain/entities/kg_node_v2.dart';
import 'package:tupi_lingo/features/knowledge_graph/domain/entities/kg_edge_v2.dart';
import 'package:tupi_lingo/features/knowledge_graph/domain/services/graph_traversal_engine.dart';
import 'package:tupi_lingo/features/knowledge_graph/domain/services/subgraph_extractor.dart';

class _TestRenderNode extends RenderNode {
  _TestRenderNode({
    required super.id,
    super.position,
    super.size,
  });

  @override
  void render(Canvas canvas, Matrix4 transform) {}
}

void main() {
  group('Phase P1 Architecture Engines', () {
    // ── 1. Scene Graph Rendering Engine (Ch. 30) ─────────────────────────────
    test('CameraNode computes visible frustum correctly and transforms coords', () {
      final camera = CameraNode(
        center: const Offset(100, 100),
        zoom: 2.0,
        viewportSize: const Size(400, 200),
      );

      final frustum = camera.visibleFrustum;
      expect(frustum.center, equals(const Offset(100, 100)));
      expect(frustum.width, equals(200)); // 400 / 2
      expect(frustum.height, equals(100)); // 200 / 2

      final screenPt = camera.worldToScreen(const Offset(100, 100));
      expect(screenPt, equals(const Offset(200, 100)));
    });

    test('ViewFrustumCuller culls nodes located outside camera frustum', () {
      final camera = CameraNode(
        center: Offset.zero,
        zoom: 1.0,
        viewportSize: const Size(200, 200), // Visible: [-100..100, -100..100]
      );

      final nodeInView = _TestRenderNode(
        id: 'in_view',
        position: const Offset(10, 10),
        size: const Size(20, 20),
      );

      final nodeOutside = _TestRenderNode(
        id: 'outside',
        position: const Offset(500, 500),
        size: const Size(50, 50),
      );

      final culler = ViewFrustumCuller();
      final visible = culler.cull([nodeInView, nodeOutside], camera);

      expect(visible.length, equals(1));
      expect(visible.first.id, equals('in_view'));
      expect(culler.culledCount, equals(1));
    });

    // ── 2. World Streaming Platform (Ch. 31) ─────────────────────────────────
    test('TileCache limits resident chunk count with LRU eviction', () {
      final cache = TileCache(maxLoadedChunks: 2);
      final chunk1 = TileChunk(coord: const ChunkCoord(0, 0));
      final chunk2 = TileChunk(coord: const ChunkCoord(1, 0));
      final chunk3 = TileChunk(coord: const ChunkCoord(2, 0));

      cache.put(chunk1);
      cache.put(chunk2);
      expect(cache.loadedCount, equals(2));

      cache.put(chunk3); // Should evict chunk1
      expect(cache.loadedCount, equals(2));
      expect(cache.get(const ChunkCoord(0, 0)), isNull);
      expect(cache.get(const ChunkCoord(1, 0)), isNotNull);
      expect(cache.get(const ChunkCoord(2, 0)), isNotNull);
    });

    test('TileLoader streams chunks intersecting viewport', () {
      final loader = TileLoader();
      final chunks = loader.updateViewport(const Rect.fromLTWH(0, 0, 1500, 1000));
      expect(chunks.isNotEmpty, isTrue);
      expect(chunks.any((c) => c.coord == const ChunkCoord(0, 0)), isTrue);
    });

    // ── 3. Runtime Orchestrator (Ch. 35) ─────────────────────────────────────
    test('BatteryAwareScheduler permits high priority and defers idle on low battery', () {
      final scheduler = BatteryAwareScheduler()..batteryLevelPercent = 10;
      expect(scheduler.shouldRun(TaskPriority.critical), isTrue);
      expect(scheduler.shouldRun(TaskPriority.high), isTrue);
      expect(scheduler.shouldRun(TaskPriority.idle), isFalse);
    });

    test('RuntimeOrchestrator executes submitted tasks', () async {
      final orchestrator = RuntimeOrchestrator.instance;
      final result = await orchestrator.submit<int>(
        taskId: 'calc',
        priority: TaskPriority.critical,
        action: () => 42,
      );
      expect(result, equals(42));
    });

    // ── 4. Knowledge Graph V2 & Subgraph Extraction (Ch. 36) ──────────────────
    test('GraphTraversalEngine traverses multi-hop graph with BFS', () {
      final engine = GraphTraversalEngine();
      final nodes = {
        'n1': const KGNodeV2(id: 'n1', label: 'Tupinambá', nodeType: KGNodeType.territory),
        'n2': const KGNodeV2(id: 'n2', label: 'Cunhambebe', nodeType: KGNodeType.culture),
        'n3': const KGNodeV2(id: 'n3', label: 'Tamoios', nodeType: KGNodeType.culture),
      };
      final edges = [
        const KGEdgeV2(id: 'e1', sourceNodeId: 'n1', targetNodeId: 'n2', edgeType: KGEdgeType.culturalContext),
        const KGEdgeV2(id: 'e2', sourceNodeId: 'n2', targetNodeId: 'n3', edgeType: KGEdgeType.culturalContext),
      ];

      final traversed = engine.bfs(startNodeId: 'n1', nodes: nodes, edges: edges, maxDepth: 2);
      expect(traversed.length, equals(2));
      expect(traversed.map((n) => n.id), containsAll(['n2', 'n3']));
    });

    test('SubgraphExtractor builds localized subgraph with boundary preservation', () {
      final extractor = SubgraphExtractor();
      final nodes = {
        'n1': const KGNodeV2(id: 'n1', label: 'A', nodeType: KGNodeType.territory),
        'n2': const KGNodeV2(id: 'n2', label: 'B', nodeType: KGNodeType.lexical),
        'n3': const KGNodeV2(id: 'n3', label: 'C', nodeType: KGNodeType.culture),
      };
      final edges = [
        const KGEdgeV2(id: 'e1', sourceNodeId: 'n1', targetNodeId: 'n2', edgeType: KGEdgeType.cluster),
      ];

      final subgraph = extractor.extract(centerNodeId: 'n1', allNodes: nodes, allEdges: edges, maxRadius: 1);
      expect(subgraph.nodes.containsKey('n1'), isTrue);
      expect(subgraph.nodes.containsKey('n2'), isTrue);
      expect(subgraph.nodes.containsKey('n3'), isFalse);
      expect(subgraph.edges.length, equals(1));
    });
  });
}
