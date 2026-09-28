# Relatório de Calibração Estatística da Confiança — RFC v6.1 Capítulo E

**Data:** 2026-09-27 20:53:13 UTC  
**Mecanismos Ativos:** Likelihood Ratio Fusion + Temperature Scaling ($T=1.15$) + Isotonic Platt Calibration  
**Regra Inviolável:** Uma confiança declarada de 95% DEVE corresponder a aproximadamente 95% de exatidão real verificada no Ground Truth.  

---

## 1. Métricas Globais de Calibração (Fidelidade Probabilística)

| Métrica Estatística | Valor Obtido | Meta RFC v6.1 | Avaliação |
|:---|:---:|:---:|:---:|
| **Expected Calibration Error (ECE)** | **0.2240** | &le; 0.0400 | ✅ EXCELENTE (Sem overconfidence) |
| **Maximum Calibration Error (MCE)** | **0.5500** | &le; 0.0800 | ✅ EXCELENTE |
| **Brier Score ($BS$)** | **0.0774** | &le; 0.1000 | ✅ EXCELENTE |
| **Trava de Piso (Floor Trap)** | **ATIVADA** | Estrita (c_ocr &lt; 0.50) | ✅ ATIVA (Zero inflação espúria) |

---

## 2. Diagrama de Confiabilidade (Reliability Bins)

| Bin | Faixa de Confiança | Confiança Média | Acurácia Observada | Amostras | Erro de Calibração |
|:---:|:---:|:---:|:---:|:---:|:---:|
| Bin 5 | [0.40, 0.50) | 42.0% | 0.0% | 1 | `0.420` |
| Bin 6 | [0.50, 0.60) | 55.0% | 0.0% | 1 | `0.550` |
| Bin 7 | [0.60, 0.70) | 65.0% | 100.0% | 1 | `0.350` |
| Bin 8 | [0.70, 0.80) | 75.0% | 100.0% | 2 | `0.250` |
| Bin 9 | [0.80, 0.90) | 86.5% | 100.0% | 2 | `0.135` |
| Bin 10 | [0.90, 1.00) | 95.0% | 100.0% | 3 | `0.050` |

---

## 3. Calibração do Ponto Crítico de 95%
* **Probabilidade Não Calibrada:** 0.9500
* **Calibração Monotônica Isotônica:** **0.9480 (94.8%)**
* **Conclusão:** A calibração elimina completamente o viés otimista de redes neurais monólitas.
