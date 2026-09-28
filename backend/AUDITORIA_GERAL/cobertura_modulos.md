# Cobertura de Módulos e Classificação Operacional — RFC v6.1

**Data:** 2026-09-27 21:05:46 UTC  
**Total de Arquivos Auditados:** 72  

---

| Módulo / Arquivo | Linhas | Classes | Funções | Classificação Operacional |
|:---|:---:|:---:|:---:|:---:|
| `ocr_pipeline/__init__.py` | 38 | 0 | 0 | **PRODUÇÃO** |
| `ocr_pipeline/archival_dashboard.py` | 498 | 1 | 2 | **PRODUÇÃO** |
| `ocr_pipeline/benchmarking/__init__.py` | 15 | 0 | 0 | **PRODUÇÃO** |
| `ocr_pipeline/benchmarking/auto_benchmark.py` | 312 | 2 | 4 | **PRODUÇÃO** |
| `ocr_pipeline/benchmarking/benchmark_v3.py` | 229 | 3 | 4 | **PRODUÇÃO** |
| `ocr_pipeline/benchmarking/ground_truth_builder.py` | 244 | 2 | 8 | **PRODUÇÃO** |
| `ocr_pipeline/benchmarking/layout_ensemble_audit.py` | 166 | 2 | 3 | **PRODUÇÃO** |
| `ocr_pipeline/benchmarking/ocr_engine_championship.py` | 284 | 2 | 6 | **PRODUÇÃO** |
| `ocr_pipeline/benchmarking/scientific_benchmark.py` | 351 | 3 | 8 | **PRODUÇÃO** |
| `ocr_pipeline/cache_manager.py` | 228 | 1 | 23 | **PRODUÇÃO** |
| `ocr_pipeline/chunk_worker.py` | 181 | 1 | 3 | **PRODUÇÃO** |
| `ocr_pipeline/compute_summary.py` | 104 | 0 | 2 | **DESCONECTADO** |
| `ocr_pipeline/confidence_engine/__init__.py` | 22 | 0 | 0 | **PRODUÇÃO** |
| `ocr_pipeline/confidence_engine/bayesian_confidence.py` | 298 | 4 | 11 | **PRODUÇÃO** |
| `ocr_pipeline/confidence_engine/confidence_fusion.py` | 201 | 2 | 6 | **PRODUÇÃO** |
| `ocr_pipeline/confidence_engine/token_voting.py` | 244 | 1 | 5 | **PRODUÇÃO** |
| `ocr_pipeline/confidence_worker.py` | 126 | 1 | 4 | **PRODUÇÃO** |
| `ocr_pipeline/core/__init__.py` | 46 | 0 | 1 | **PRODUÇÃO** |
| `ocr_pipeline/core/checkpoint_manager.py` | 118 | 1 | 7 | **PRODUÇÃO** |
| `ocr_pipeline/core/config.py` | 68 | 6 | 0 | **PRODUÇÃO** |
| `ocr_pipeline/core/dataset_versioning.py` | 338 | 3 | 13 | **PRODUÇÃO** |
| `ocr_pipeline/core/gpu_orchestrator.py` | 141 | 2 | 4 | **PRODUÇÃO** |
| `ocr_pipeline/core/metrics.py` | 98 | 5 | 4 | **PRODUÇÃO** |
| `ocr_pipeline/core/orchestrator.py` | 376 | 2 | 3 | **PRODUÇÃO** |
| `ocr_pipeline/core/provenance.py` | 128 | 4 | 4 | **PRODUÇÃO** |
| `ocr_pipeline/core/quality_certification.py` | 219 | 3 | 4 | **PRODUÇÃO** |
| `ocr_pipeline/core/scheduler.py` | 44 | 1 | 3 | **PRODUÇÃO** |
| `ocr_pipeline/diagnostic_engine/__init__.py` | 15 | 0 | 0 | **PRODUÇÃO** |
| `ocr_pipeline/diagnostic_engine/forensic_analyzer.py` | 392 | 2 | 16 | **PRODUÇÃO** |
| `ocr_pipeline/diagnostic_engine/region_quality.py` | 168 | 3 | 5 | **PRODUÇÃO** |
| `ocr_pipeline/download_models.py` | 77 | 0 | 2 | **DESCONECTADO** |
| `ocr_pipeline/ensemble_engine/__init__.py` | 14 | 0 | 0 | **PRODUÇÃO** |
| `ocr_pipeline/ensemble_engine/multi_engine.py` | 259 | 2 | 9 | **PRODUÇÃO** |
| `ocr_pipeline/ensemble_engine/self_consistency.py` | 237 | 3 | 5 | **PRODUÇÃO** |
| `ocr_pipeline/export_engine/__init__.py` | 18 | 0 | 0 | **PRODUÇÃO** |
| `ocr_pipeline/export_engine/academic_paper_generator.py` | 421 | 1 | 7 | **PRODUÇÃO** |
| `ocr_pipeline/export_engine/artifact_bundle.py` | 274 | 2 | 11 | **PRODUÇÃO** |
| `ocr_pipeline/export_engine/multi_exporter.py` | 328 | 2 | 10 | **PRODUÇÃO** |
| `ocr_pipeline/export_engine/research_report_generator.py` | 634 | 1 | 7 | **PRODUÇÃO** |
| `ocr_pipeline/import_bundle_notebook.py` | 103 | 0 | 3 | **DESCONECTADO** |
| `ocr_pipeline/layout_engine/__init__.py` | 15 | 0 | 0 | **PRODUÇÃO** |
| `ocr_pipeline/layout_engine/consensus_layout.py` | 346 | 5 | 5 | **PRODUÇÃO** |
| `ocr_pipeline/layout_engine/doc_layout.py` | 322 | 3 | 10 | **PRODUÇÃO** |
| `ocr_pipeline/layout_worker.py` | 74 | 1 | 2 | **PRODUÇÃO** |
| `ocr_pipeline/lexical_engine/__init__.py` | 30 | 0 | 0 | **PRODUÇÃO** |
| `ocr_pipeline/lexical_engine/active_learning.py` | 225 | 2 | 7 | **PRODUÇÃO** |
| `ocr_pipeline/lexical_engine/forensic_lexicon.py` | 776 | 5 | 11 | **PRODUÇÃO** |
| `ocr_pipeline/lexical_engine/hierarchical_lexicon.py` | 224 | 2 | 3 | **PRODUÇÃO** |
| `ocr_pipeline/lexical_engine/never_hallucinate_guard.py` | 188 | 2 | 3 | **PRODUÇÃO** |
| `ocr_pipeline/lexicon_worker.py` | 203 | 1 | 4 | **PRODUÇÃO** |
| `ocr_pipeline/models.py` | 101 | 7 | 0 | **PRODUÇÃO** |
| `ocr_pipeline/ocr_worker.py` | 195 | 1 | 7 | **PRODUÇÃO** |
| `ocr_pipeline/overnight_scheduler.py` | 464 | 1 | 4 | **PRODUÇÃO** |
| `ocr_pipeline/pipeline_orchestrator.py` | 207 | 1 | 2 | **PRODUÇÃO** |
| `ocr_pipeline/preprocessing_engine/__init__.py` | 12 | 0 | 0 | **PRODUÇÃO** |
| `ocr_pipeline/preprocessing_engine/dewarp_engine.py` | 183 | 2 | 7 | **PRODUÇÃO** |
| `ocr_pipeline/preprocessing_engine/multi_branch.py` | 628 | 1 | 56 | **PRODUÇÃO** |
| `ocr_pipeline/preprocessing_worker.py` | 129 | 1 | 5 | **PRODUÇÃO** |
| `ocr_pipeline/quality_worker.py` | 267 | 1 | 7 | **PRODUÇÃO** |
| `ocr_pipeline/rag_validation_engine/__init__.py` | 23 | 0 | 0 | **PRODUÇÃO** |
| `ocr_pipeline/rag_validation_engine/corpus_inverted_index.py` | 177 | 2 | 8 | **PRODUÇÃO** |
| `ocr_pipeline/rag_validation_engine/document_consensus.py` | 122 | 3 | 3 | **PRODUÇÃO** |
| `ocr_pipeline/rag_validation_engine/rag_validator.py` | 313 | 3 | 8 | **PRODUÇÃO** |
| `ocr_pipeline/rollback_engine/__init__.py` | 21 | 0 | 0 | **PRODUÇÃO** |
| `ocr_pipeline/rollback_engine/rollback_manager.py` | 261 | 6 | 4 | **PRODUÇÃO** |
| `ocr_pipeline/run_batch_559.py` | 392 | 2 | 5 | **DESCONECTADO** |
| `ocr_pipeline/run_benchmark_and_eval.py` | 192 | 0 | 2 | **DESCONECTADO** |
| `ocr_pipeline/smoke_test_gpu.py` | 92 | 0 | 0 | **DESCONECTADO** |
| `ocr_pipeline/super_resolution_engine/__init__.py` | 13 | 0 | 0 | **PRODUÇÃO** |
| `ocr_pipeline/super_resolution_engine/tile_enhancer.py` | 179 | 2 | 5 | **PRODUÇÃO** |
| `ocr_pipeline/super_resolution_engine/token_sr_engine.py` | 167 | 2 | 4 | **PRODUÇÃO** |
| `ocr_pipeline/test_pipeline_units.py` | 135 | 1 | 8 | **DESCONECTADO** |

---

## Legenda Operacional:
* **PRODUÇÃO:** Módulo homologado, conectado ao fluxo de execução principal e validado por testes.
* **EXPERIMENTAL:** Módulo em validação ou com ganho comprovado em subconjunto de categorias.
* **PLACEHOLDER:** Módulo contendo estruturas vazias que devem ser fechadas antes do processamento final.
* **DESCONECTADO:** Módulo presente no repositório mas sem chamadas no orquestrador ativo.
* **OBSOLETO:** Módulo arquivado substituído por versões superiores na v6/v6.1.
