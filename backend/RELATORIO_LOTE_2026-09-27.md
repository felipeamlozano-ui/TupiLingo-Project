# Relatório de Execução do Lote — TupiLingo OCR v5

**Data de Execução:** 2026-09-27  
**Versão do Pipeline:** v5.0 (Pipeline Arquivístico Distribuído GPU)  
**Ambiente:** Desktop (Intel i5-12400F, RTX 5060 8GB VRAM, ONNX Runtime GPU CUDA)  
**Tempo Real Total:** 27.08 segundos (0.45 minutos)  
**Artifact Bundle Gerado:** [`artifact_bundle_2026-09-27T17-10-23`](C:\Users\Felipe\Downloads\Tupilingo\backend\ocr_cache\artifact_bundle_2026-09-27T17-10-23)  
**Dashboard Arquivístico:** [`dashboard.html`](C:\Users\Felipe\Downloads\Tupilingo\backend\ocr_cache\dashboard.html)  

---

## 1. Resumo Executivo

| Métrica | Valor Real |
| :--- | :--- |
| **Total de Páginas Processadas com Sucesso** | **5** |
| **Total de Páginas com Falhas / Erros** | **0** |
| **Páginas Roteadas para Revisão Humana (`needs_review=True`)** | **2** |
| **Páginas Aprovadas Automaticamente** | **3** |
| **Taxa de Homologação Automática** | **60.0%** |

> **Nota de Conformidade Científica (Capítulo 17):**  
> Todas as métricas de recuperação expressas neste relatório são rotuladas formalmente como **Proxy Heurístico (v5)**, uma vez que o cálculo estrito de CER/WER requer confronto contra o conjunto de verdade fundamental humana (seção 17.2).

---

## 2. Tabela de Evidências Brutas (Páginas Individuais Nomeadas)

| PDF | Pág | c_ocr | Conf. v5 | Trava Piso | Revisão Humana? | Motivo / Diagnóstico | Tempo |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- | :---: |
| `Ayrosa_1943_ApontBibliogrLingTupiGuarani1ed` | 1 | 99.8% | 52.3% | SIM | **SIM** | char_count (10) < 40 | 9.95s |
| `Ayrosa_1943_ApontBibliogrLingTupiGuarani1ed` | 2 | 95.6% | 48.2% | SIM | **SIM** | char_count (14) < 40 | 7.69s |
| `Ayrosa_1943_ApontBibliogrLingTupiGuarani1ed` | 15 | 87.2% | 75.7% | NÃO | Não | approved | 5.90s |
| `Ayrosa_1943_ApontBibliogrLingTupiGuarani1ed` | 20 | 96.2% | 78.2% | NÃO | Não | approved | 5.15s |
| `Barbosa_1956_CursoDeTupiAntigo_BDCN_CNic` | 10 | 96.6% | 90.3% | NÃO | Não | approved | 15.97s |

---
*Relatório gerado automaticamente pelo AutonomousOvernightScheduler (Capítulo 18).*
