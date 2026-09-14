-- ============================================================================
-- RFC-012B: Complete Platform Architecture Database Schema (Phases P1–P3)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. KNOWLEDGE GRAPH V2 & MULTI-MODAL EMBEDDINGS (Chapter 36)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS kg_nodes_v2 (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    label VARCHAR(200) NOT NULL,
    node_type VARCHAR(30) NOT NULL CHECK (node_type IN ('lexical', 'grammar', 'culture', 'mythology', 'territory')),
    variante_id INT REFERENCES trilha_variantetupi(id) ON DELETE CASCADE,
    translation_pt TEXT,
    morphology_root VARCHAR(50),
    ipa VARCHAR(200),
    attributes JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_kg_nodes_v2_type ON kg_nodes_v2(node_type);
CREATE INDEX IF NOT EXISTS idx_kg_nodes_v2_variant ON kg_nodes_v2(variante_id);
CREATE INDEX IF NOT EXISTS idx_kg_nodes_v2_root ON kg_nodes_v2(morphology_root);

CREATE TABLE IF NOT EXISTS kg_edges_v2 (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_node_id UUID REFERENCES kg_nodes_v2(id) ON DELETE CASCADE,
    target_node_id UUID REFERENCES kg_nodes_v2(id) ON DELETE CASCADE,
    edge_type VARCHAR(30) NOT NULL CHECK (edge_type IN ('prerequisite', 'cluster', 'morphology', 'cognate', 'culturalContext')),
    weight DOUBLE PRECISION DEFAULT 1.0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_kg_edge_v2 UNIQUE (source_node_id, target_node_id, edge_type)
);

CREATE INDEX IF NOT EXISTS idx_kg_edges_v2_source ON kg_edges_v2(source_node_id);
CREATE INDEX IF NOT EXISTS idx_kg_edges_v2_target ON kg_edges_v2(target_node_id);

-- ----------------------------------------------------------------------------
-- 2. CURRICULUM GRAPH V2 & UNLOCK CONDITIONS (Chapter 37)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS curriculum_nodes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    variante_id INT REFERENCES trilha_variantetupi(id) ON DELETE CASCADE,
    node_type VARCHAR(20) CHECK (node_type IN ('territory', 'chapter', 'lesson', 'objective', 'boss', 'event', 'mission')),
    label VARCHAR(200) NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    kg_node_id UUID REFERENCES kg_nodes_v2(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS curriculum_edges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_node_id UUID REFERENCES curriculum_nodes(id) ON DELETE CASCADE,
    target_node_id UUID REFERENCES curriculum_nodes(id) ON DELETE CASCADE,
    edge_type VARCHAR(30) CHECK (edge_type IN ('sequence', 'prerequisite', 'optional', 'boss_gate', 'expansion')),
    weight DOUBLE PRECISION DEFAULT 1.0,
    CONSTRAINT uq_curr_edge UNIQUE (source_node_id, target_node_id, edge_type)
);

CREATE TABLE IF NOT EXISTS unlock_conditions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    curriculum_node_id UUID REFERENCES curriculum_nodes(id) ON DELETE CASCADE,
    condition_type VARCHAR(30) NOT NULL, -- score_threshold, mastery_threshold, boss_cleared
    threshold_value DOUBLE PRECISION,
    required_node_id UUID REFERENCES curriculum_nodes(id)
);

-- ----------------------------------------------------------------------------
-- 3. CULTURAL NARRATIVE & HISTORICAL EPISODES (Chapter 38)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS narrative_nodes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    variante_id INT REFERENCES trilha_variantetupi(id) ON DELETE SET NULL,
    title VARCHAR(300) NOT NULL,
    body_pt TEXT NOT NULL,
    trigger_type VARCHAR(30) NOT NULL, -- territory_unlock, lesson_complete, boss_cleared
    trigger_reference_id VARCHAR(100) NOT NULL,
    historical_year INT,
    character_name VARCHAR(200),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_narrative_nodes_trigger ON narrative_nodes(trigger_type, trigger_reference_id);

-- ----------------------------------------------------------------------------
-- 4. PHONOLOGY & IPA TRANSCRIPTIONS (Chapter 27)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS phonemes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    variante_id INT REFERENCES trilha_variantetupi(id) ON DELETE CASCADE,
    ipa_symbol VARCHAR(10) NOT NULL,
    phoneme_class VARCHAR(20) NOT NULL, -- vowel, consonant, semivowel, nasal
    place_of_articulation VARCHAR(30),
    manner_of_articulation VARCHAR(30),
    is_nasal BOOLEAN DEFAULT FALSE,
    source_reference VARCHAR(300)
);

CREATE TABLE IF NOT EXISTS pronunciation_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    variante_id INT REFERENCES trilha_variantetupi(id) ON DELETE CASCADE,
    phonological_context VARCHAR(200) NOT NULL,
    input_symbol VARCHAR(10),
    output_symbol VARCHAR(10),
    source_reference VARCHAR(300),
    confidence DOUBLE PRECISION DEFAULT 1.0
);

-- ----------------------------------------------------------------------------
-- 5. AI TELEMETRY PLATFORM (Chapter 49)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ai_telemetry_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL,
    user_id UUID,
    variante_id INT REFERENCES trilha_variantetupi(id) ON DELETE SET NULL,
    prompt_version VARCHAR(30),
    prompt_hash VARCHAR(64),
    provider_used VARCHAR(50),
    model_name VARCHAR(100),
    input_tokens INT,
    output_tokens INT,
    latency_ms INT,
    cache_hit BOOLEAN DEFAULT FALSE,
    truth_layer_result VARCHAR(10), -- 'pass', 'fail'
    failed_gate VARCHAR(30),
    question_quality_score DOUBLE PRECISION,
    grounding_confidence DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_tel_quality ON ai_telemetry_log(question_quality_score);
CREATE INDEX IF NOT EXISTS idx_ai_tel_time ON ai_telemetry_log(created_at DESC);
