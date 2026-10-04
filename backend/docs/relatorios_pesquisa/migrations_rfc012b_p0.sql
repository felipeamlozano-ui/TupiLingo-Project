-- ============================================================================
-- RFC-012B: Phase P0 Database Schema Migration
-- Features: Feature Flags, Linguistic Morphology, Truth Layer
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. FEATURE FLAGS TABLE (Chapter 47)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS feature_flags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    flag_id VARCHAR(100) UNIQUE NOT NULL,
    is_enabled BOOLEAN DEFAULT FALSE,
    rollout_percent INT DEFAULT 0 CHECK (rollout_percent BETWEEN 0 AND 100),
    experiment_id VARCHAR(100),
    description TEXT,
    pillar VARCHAR(10),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_feature_flags_flag_id ON feature_flags(flag_id);
CREATE INDEX IF NOT EXISTS idx_feature_flags_pillar ON feature_flags(pillar);

-- Seed all 18 RFC-012B flags (Default: FALSE)
INSERT INTO feature_flags (flag_id, is_enabled, rollout_percent, description, pillar)
VALUES
    ('morphology_engine_v1', FALSE, 0, 'Chapter 26: Linguistic Morphology Engine', 'P1'),
    ('phonology_engine_v1', FALSE, 0, 'Chapter 27: Phonology & IPA Engine', 'P1'),
    ('evolution_engine_v1', FALSE, 0, 'Chapter 28: Linguistic Evolution Tree', 'P1'),
    ('semantic_search_v1', FALSE, 0, 'Chapter 29: Multi-Axis Semantic Search', 'P1'),
    ('scene_graph_v1', FALSE, 0, 'Chapter 30: Scene Graph 2D Renderer', 'P2'),
    ('world_streaming_v1', FALSE, 0, 'Chapter 31: World Streaming & Tile Chunks', 'P2'),
    ('ecs_v2', FALSE, 0, 'Chapter 32: ECS V2 Entity World', 'P2'),
    ('adaptive_rendering_v1', FALSE, 0, 'Chapter 33: Adaptive Rendering & Device Profiling', 'P2'),
    ('runtime_orchestrator_v1', FALSE, 0, 'Chapter 35: Battery & Task Runtime Orchestrator', 'P2'),
    ('kg_v2_embeddings', FALSE, 0, 'Chapter 36: Knowledge Graph V2 Embeddings', 'P3'),
    ('curriculum_graph_v2', FALSE, 0, 'Chapter 37: Curriculum Graph V2 & DAG Unlock', 'P3'),
    ('cultural_narrative_v1', FALSE, 0, 'Chapter 38: Cultural Narrative & Historical Events', 'P3'),
    ('truth_layer_v1', FALSE, 0, 'Chapter 40: Truth Layer 6-Gate Zero Hallucination', 'P4'),
    ('prompt_builder_v3', FALSE, 0, 'Chapter 42: Modular Prompt Engineering V3', 'P4'),
    ('semantic_diversity_v2', FALSE, 0, 'Chapter 43: Semantic Diversity & Entropy Planner', 'P4'),
    ('otel_full_stack', FALSE, 0, 'Chapter 45: OpenTelemetry Distributed Observability', 'P5'),
    ('ab_testing_v1', FALSE, 0, 'Chapter 46: Analytics & A/B Testing Platform', 'P5'),
    ('performance_benchmark_v1', FALSE, 0, 'Chapter 48: Frame & Engine Benchmarks', 'P5')
ON CONFLICT (flag_id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 2. LINGUISTIC MORPHOLOGY TABLES (Chapter 26)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS morphology_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    variante_id INT REFERENCES trilha_variantetupi(id) ON DELETE CASCADE,
    morpheme_surface VARCHAR(50) NOT NULL,
    morpheme_type VARCHAR(20) NOT NULL CHECK (morpheme_type IN (
        'root', 'prefix', 'suffix', 'infix', 'particle'
    )),
    morphological_function VARCHAR(40) NOT NULL,
    meaning_pt VARCHAR(200) NOT NULL,
    allomorphs JSONB DEFAULT '[]'::jsonb,
    source_reference VARCHAR(300),
    confidence DOUBLE PRECISION DEFAULT 1.0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_morphology_rules_surface ON morphology_rules(morpheme_surface);
CREATE INDEX IF NOT EXISTS idx_morphology_rules_variant ON morphology_rules(variante_id);
CREATE INDEX IF NOT EXISTS idx_morphology_rules_type ON morphology_rules(morpheme_type);

CREATE TABLE IF NOT EXISTS morphological_analyses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    word_label VARCHAR(200) NOT NULL,
    variante_id INT REFERENCES trilha_variantetupi(id) ON DELETE CASCADE,
    root_surface VARCHAR(50) NOT NULL,
    morphemes JSONB NOT NULL DEFAULT '[]'::jsonb,
    explanation_pt TEXT,
    confidence DOUBLE PRECISION DEFAULT 1.0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_morph_analysis UNIQUE (word_label, variante_id)
);

CREATE INDEX IF NOT EXISTS idx_morph_analyses_word ON morphological_analyses(word_label);
CREATE INDEX IF NOT EXISTS idx_morph_analyses_root ON morphological_analyses(root_surface);

CREATE TABLE IF NOT EXISTS morphological_families (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    root_surface VARCHAR(50) NOT NULL,
    shared_meaning_pt VARCHAR(200) NOT NULL,
    variante_id INT REFERENCES trilha_variantetupi(id) ON DELETE CASCADE,
    member_words JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_morph_family UNIQUE (root_surface, variante_id)
);

CREATE INDEX IF NOT EXISTS idx_morph_families_root ON morphological_families(root_surface);

-- ----------------------------------------------------------------------------
-- 3. TRUTH LAYER AUDIT & VALIDATION TABLES (Chapter 40)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS truth_validation_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question_candidate_hash VARCHAR(64) NOT NULL,
    variante_id INT REFERENCES trilha_variantetupi(id) ON DELETE SET NULL,
    validation_result VARCHAR(10) NOT NULL CHECK (validation_result IN ('pass', 'fail')),
    failed_gate VARCHAR(30),
    failure_reason TEXT,
    grounding_confidence DOUBLE PRECISION,
    validated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_truth_val_result ON truth_validation_log(validation_result);
CREATE INDEX IF NOT EXISTS idx_truth_val_gate ON truth_validation_log(failed_gate);
CREATE INDEX IF NOT EXISTS idx_truth_val_time ON truth_validation_log(validated_at DESC);

CREATE TABLE IF NOT EXISTS truth_repository (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    claim_text TEXT NOT NULL,
    variante_id INT REFERENCES trilha_variantetupi(id) ON DELETE SET NULL,
    grounding_source_type VARCHAR(20) NOT NULL, -- 'rag_chunk', 'kg_node', 'morphology_rule'
    grounding_source_id VARCHAR(100),
    confidence DOUBLE PRECISION DEFAULT 1.0,
    verified_by VARCHAR(50) DEFAULT 'automated',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_truth_repo_source ON truth_repository(grounding_source_type, grounding_source_id);
