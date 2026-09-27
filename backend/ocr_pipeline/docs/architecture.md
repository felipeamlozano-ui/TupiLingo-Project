# Arquitetura Técnica — TupiLingo OCR Forense v3.0

## 1. Visão Geral da Arquitetura

O **TupiLingo OCR Forense v3.0** foi projetado com Clean Architecture e Domain Driven Design (DDD), organizado em 12 módulos independentes e desacoplados, voltados para a preservação arquivística e textual de documentos históricos em língua Tupi.

```mermaid
graph TD
    A["PDF Histórico (Streaming fitz)"] --> B["1. Engine de Diagnóstico Forense (12D)"]
    B --> C["2. Pré-processamento Multi-Branch (30 Branches)"]
    C --> D["3. Análise de Layout (DocLayout)"]
    D --> E["4. Super-Resolução Seletiva em CPU"]
    E --> F["5. OCR Ensemble (RapidOCR + Tesseract multi-PSM)"]
    F --> G["6. OCR Voting Engine (Needleman-Wunsch)"]
    G --> H["7. Confidence Fusion & Heatmap"]
    H --> I["8. Corretor Léxico com Salvaguarda Tupi"]
    I --> J["9. Validador RAG Zero Alucinação"]
    J --> K["10. Motor de Rollback & Recuperação Iterativa"]
    K --> L["11. Checkpoint Transacional (SQLite & JSONL)"]
    L --> M["12. Export Engine (8 Formatos Arquivísticos)"]
```

---

## 2. Diagrama Detalhado de Interação Entre Módulos

```mermaid
sequenceDiagram
    autonumber
    actor CLI as Orquestrador Batch
    participant Diag as DiagnosticEngine (12D)
    participant Pre as PreprocessingEngine (30B)
    participant Ens as EnsembleEngine (RapidOCR/Tess)
    participant Vote as Voting & Needleman-Wunsch
    participant Lex as LexicalEngine & TupiMorphology
    participant RAG as RAGValidator (vector_store.db)
    participant Roll as RollbackManager
    participant Exp as ForensicMultiExporter
    participant DB as CheckpointManager (SQLite)

    CLI->>DB: is_page_completed(file, page)
    DB-->>CLI: False (necessário processar)
    CLI->>Diag: analyze_image(pil_img)
    Diag-->>CLI: ForensicDiagnosticReport (blur, skew, bleed, aging)
    CLI->>Pre: process_branch(pil_img, primary_branch)
    Pre-->>CLI: preprocessed_pil
    CLI->>Ens: run_ensemble(preprocessed_pil, psms=[6,4])
    Ens-->>CLI: List[OCRCandidate]
    CLI->>Vote: vote_on_candidates(candidates)
    Vote-->>CLI: VotedTokens (text, conf, bbox, engine)
    CLI->>Lex: process_text(tokens, confs)
    Lex-->>CLI: ForensicLexicalResult (Tupi morfológico, invariantes)
    CLI->>RAG: validate_page_tokens(words)
    RAG-->>CLI: List[RAGValidationResult] (evidência no acervo)
    CLI->>Roll: evaluate_and_enforce(orig, prop, conf_before, conf_after)
    Roll-->>CLI: final_word (com rollback se houver violação)
    CLI->>Exp: export_all(page_num, text, tokens, meta)
    Exp-->>CLI: ForensicExportBundle (TXT, MD, JSON, ALTO, PAGE XML, HTML)
    CLI->>DB: record_page(file, page, status="completed", metrics)
```

---

## 3. Composição da Confiança Multidimensional

A confiança de cada caractere e palavra é modelada como uma função convexa multidimensional:

$$C_{\text{final}} = w_{\text{ocr}} \cdot C_{\text{ocr}} + w_{\text{vis}} \cdot C_{\text{vis}} + w_{\text{lex}} \cdot C_{\text{lex}} + w_{\text{rag}} \cdot C_{\text{rag}}$$

Onde os pesos canônicos são parametrizados em:
- $w_{\text{ocr}} = 0.45$: Confiabilidade intrínseca das redes neurais do OCR (logits softmax das saídas CRNN/CTC).
- $w_{\text{vis}} = 0.20$: Nitidez visual avaliada pela variância Laplaciana e ausência de manchas de _bleed-through_.
- $w_{\text{lex}} = 0.20$: Validade morfológica e conformidade com os radicais do Tupi Antigo ou dicionário histórico.
- $w_{\text{rag}} = 0.15$: Densidade de evidência documental real nos 22.140 chunks do banco SQLite local.

---

## 4. Estrutura Modular dos Pacotes

```text
ocr_pipeline/
├── core/
│   ├── config.py                 # Pydantic v2 Settings globais e caminhos
│   ├── provenance.py             # Modelos de linhagem (BoundingBox, TokenProvenance)
│   ├── metrics.py                # Telemetria Windows API ctypes e Prometheus
│   ├── checkpoint_manager.py     # SQLite transacional e JSONL append-only
│   ├── scheduler.py              # Fatiamento em tiles com overlap
│   └── orchestrator.py           # Orquestrador Master end-to-end
│
├── diagnostic_engine/
│   └── forensic_analyzer.py      # 12 dimensões forenses pré-OCR
│
├── preprocessing_engine/
│   └── multi_branch.py           # 30 branches independentes de OpenCV/skimage
│
├── layout_engine/
│   └── doc_layout.py             # Segmentação semântica e ordem de leitura
│
├── super_resolution_engine/
│   └── tile_enhancer.py          # Super-resolução seletiva via Lanczos / ONNX INT8
│
├── ensemble_engine/
│   └── multi_engine.py           # RapidOCR ONNX + Tesseract multi-PSM
│
├── confidence_engine/
│   ├── token_voting.py           # Needleman-Wunsch e votação ponderada
│   └── confidence_fusion.py      # Fusão composta e heatmap visual RGBA
│
├── lexical_engine/
│   └── forensic_lexicon.py       # SymSpell adaptativo e parser morfológico Tupi
│
├── rag_validation_engine/
│   └── rag_validator.py          # Consulta contra vector_store.db local
│
├── rollback_engine/
│   └── rollback_manager.py       # Rollback Gate e recuperação iterativa (< 90%)
│
├── export_engine/
│   └── multi_exporter.py         # 8 formatos arquivísticos
│
├── benchmarking/
│   └── benchmark_v3.py           # Comparador quantitativo Legacy vs Forense v3
│
├── tests/                        # 12 suítes de testes unitários e de integração
└── docs/                         # Documentação técnica e ADRs
```
