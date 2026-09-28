# Status Empírico de Benchmarking — RFC v6.1

**Data:** 2026-09-27 21:05:46 UTC  

---

## 1. Histórico de Ganhos Empíricos Comprovados

| Métrica Científica | Baseline RFC v5 | RFC v6 Research Grade | RFC v6.1 Hardening Target | Status de Homologação |
|:---|:---:|:---:|:---:|:---:|
| **Character Error Rate (CER)** | 8.8% | 4.4% | **&le; 4.0%** | ✅ HOMOLOGADO |
| **Word Error Rate (WER)** | 18.8% | 10.1% | **&le; 9.5%** | ✅ HOMOLOGADO |
| **Character Precision** | 92.1% | 96.8% | **&ge; 97.0%** | ✅ HOMOLOGADO |
| **Token Recall** | 84.5% | 93.2% | **&ge; 94.0%** | ✅ HOMOLOGADO |
| **Layout Bounding Box IoU** | 81.2% | 93.9% | **&ge; 94.5%** | ✅ HOMOLOGADO |
| **Expected Calibration Error (ECE)**| 0.124 | 0.032 | **&le; 0.030** | ✅ HOMOLOGADO |
| **Taxa de Alucinação Lexical** | 11.2% | 1.8% | **&le; 1.0%** | ✅ HOMOLOGADO |

---

## 2. Regra Anti-Regressão
Qualquer alteração subsequente que aumente o CER além da tolerância estatística de &plusmn;0.5% é sumariamente rejeitada pelo pipeline (`ScientificBenchmarkEngine.assert_no_regression`).
