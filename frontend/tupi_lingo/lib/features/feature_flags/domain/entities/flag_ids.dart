/// RFC-012B Chapter 47: Canonical Registry of Feature Flag Identifiers.
/// Every new architecture pillar and engine is gated behind one of these flags.
abstract final class FlagIds {
  // ── Pillar 1: Linguistic Intelligence ──────────────────────────────────────
  static const String morphologyEngineV1 = 'morphology_engine_v1';
  static const String phonologyEngineV1 = 'phonology_engine_v1';
  static const String evolutionEngineV1 = 'evolution_engine_v1';
  static const String semanticSearchV1 = 'semantic_search_v1';

  // ── Pillar 2: Rendering & Runtime ──────────────────────────────────────────
  static const String sceneGraphV1 = 'scene_graph_v1';
  static const String worldStreamingV1 = 'world_streaming_v1';
  static const String ecsV2 = 'ecs_v2';
  static const String adaptiveRenderingV1 = 'adaptive_rendering_v1';
  static const String runtimeOrchestratorV1 = 'runtime_orchestrator_v1';

  // ── Pillar 3: Knowledge Infrastructure ─────────────────────────────────────
  static const String kgV2Embeddings = 'kg_v2_embeddings';
  static const String curriculumGraphV2 = 'curriculum_graph_v2';
  static const String culturalNarrativeV1 = 'cultural_narrative_v1';

  // ── Pillar 4: AI Validation & Semantic Intelligence ────────────────────────
  static const String truthLayerV1 = 'truth_layer_v1';
  static const String promptBuilderV3 = 'prompt_builder_v3';
  static const String semanticDiversityV2 = 'semantic_diversity_v2';

  // ── Pillar 5: Observability & Experimentation ──────────────────────────────
  static const String otelFullStack = 'otel_full_stack';
  static const String abTestingV1 = 'ab_testing_v1';
  static const String performanceBenchmarkV1 = 'performance_benchmark_v1';

  // ── Pillar 6: Personalization & Themes ──────────────────────────────────────
  static const String customThemesEnabled = 'custom_themes_enabled';

  /// Complete list of registered flag IDs in RFC-012B.
  static const List<String> allFlags = [
    morphologyEngineV1,
    phonologyEngineV1,
    evolutionEngineV1,
    semanticSearchV1,
    sceneGraphV1,
    worldStreamingV1,
    ecsV2,
    adaptiveRenderingV1,
    runtimeOrchestratorV1,
    kgV2Embeddings,
    curriculumGraphV2,
    culturalNarrativeV1,
    truthLayerV1,
    promptBuilderV3,
    semanticDiversityV2,
    otelFullStack,
    abTestingV1,
    performanceBenchmarkV1,
    customThemesEnabled,
  ];
}
