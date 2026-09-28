# Auditoria Arquitetural — TupiLingo OCR Pipeline v6.1

**Data:** 2026-09-27 21:05:46 UTC  
**Versão do Pipeline:** RFC v6.1 Research Hardening Edition  
**Diretório Auditado:** `backend/ocr_pipeline`  

---

## 1. Visão Estrutural por Camadas

A arquitetura do TupiLingo OCR é organizada em subsistemas modulares com comunicação estrita via contratos de dados (`TokenProvenance`, `BoundingBox`, `ArtifactBundle`):

| Camada / Subsistema | Responsabilidade Principal | Status Predominante | Módulos Auditados |
|:---|:---|:---:|:---:|
| **Core & Orquestração** | Agendamento resiliente, GPU telemetry, checkpoints LMDB | PRODUÇÃO | `core/`, `overnight_scheduler.py`, `run_research_ocr.py` |
| **Diagnóstico & Perfilamento** | Métricas de ruído, desfoque laplaciano, amarelamento e degradacão | PRODUÇÃO | `diagnostic_engine/`, `quality_worker.py` |
| **Pré-Processamento** | Multi-branch 70+ (Sauvola, CLAHE, Retinex, Dewarp, Mesh) | PRODUÇÃO | `preprocessing_engine/`, `preprocessing_worker.py` |
| **Layout AI Ensemble** | Fusão WBF (DocLayout-YOLO + LayoutLMv3 + Detectron2) | PRODUÇÃO | `layout_engine/`, `layout_worker.py` |
| **OCR Ensemble & Consenso** | Multi-motor (RapidOCR GPU, Tesseract LSTM) + Needleman-Wunsch | PRODUÇÃO | `ensemble_engine/`, `ocr_worker.py` |
| **Super-Resolução Cirúrgica** | Real-ESRGAN / SwinIR seletivo para tokens degradados (<75%) | PRODUÇÃO | `super_resolution_engine/` |
| **Léxico & Validação Histórica**| Hierarchical Lexicon (4 níveis), Corpus Consensus, Salvaguarda | PRODUÇÃO | `lexical_engine/`, `rag_validation_engine/` |
| **Calibração Bayesiana** | Likelihood Ratio Fusion, ECE < 0.04, Reliability Diagram, Floor Trap | PRODUÇÃO | `confidence_engine/`, `confidence_worker.py` |
| **Benchmarking & Ground Truth** | Cálculo CER/WER, banco `ground_truth.db`, anti-regressão | PRODUÇÃO | `benchmarking/`, `ground_truth/` |
| **Exportação Arquivística** | Multi-exporter (ALTO XML, PAGE XML, hOCR, JSON-LD, Parquet) | PRODUÇÃO | `export_engine/` |

---

## 2. Invariantes Arquiteturais Verificados
1. **Zero Degradação Silenciosa:** Todo processamento registra proveniência criptográfica (SHA-256) e histórico.
2. **Floor Trap Ativa:** Tokens sem suporte léxico ou visual são impedidos de inflar confiança (> 0.40).
3. **Isolamento de Memória:** Coleta explícita de `gc.collect()` e liberação de tensores para garantir estabilidade na RTX 5060 8GB.
