# Auditoria de Código Morto e Módulos Desconectados — RFC v6.1

**Data:** 2026-09-27 21:05:46 UTC  

---

## 1. Módulos Desconectados do Fluxo Principal
* `ocr_pipeline/compute_summary.py`
* `ocr_pipeline/download_models.py`
* `ocr_pipeline/import_bundle_notebook.py`
* `ocr_pipeline/run_batch_559.py`
* `ocr_pipeline/run_benchmark_and_eval.py`
* `ocr_pipeline/smoke_test_gpu.py`
* `ocr_pipeline/test_pipeline_units.py`

## 2. Módulos Obsoletos Identificados
* Nenhum módulo obsoleto ativo detectado.

## 3. Diretriz de Higienização
Módulos identificados como desconectados ou obsoletos devem permanecer isolados de `ForensicPipelineOrchestrator` e `AutonomousOvernightScheduler` para assegurar que não haja impacto no processamento do corpus oficial.
