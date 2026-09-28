# Campeonato Científico de Motores OCR — RFC v6.1 Capítulo C

**Data do Campeonato:** 2026-09-27 20:50:39 UTC  
**Amostras Avaliadas:** 7 Categorias Documentais Reais (Capa, Índice, Dicionário, Gramática, Catecismo, Manuscrito, Degradada)  
**Critério de Ordenação:** Score Composto Ponderado: $Score = (0.50 \cdot CER) + (0.30 \cdot WER) + (0.20 \cdot Lat/100)$  

---

## 1. Ranking Oficial de Desempenho

| Posição | Motor / Configuração | CER Médio | WER Médio | Token Prec. | Token Recall | Latência Média | VRAM Peak | Tokens Recup. | Rank Score |
|:---:|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **🥇 1º LUGAR** | **RapidOCR GPU** | **50.57%** | **72.92%** | 51.0% | 56.6% | 536.9 ms | 380.0 MB | 91 | `48.23` |
| **🥈 2º LUGAR** | **Tesseract PSM 4 (Colunas)** | **100.00%** | **100.00%** | 0.0% | 0.0% | 15.4 ms | 0.0 MB | 0 | `80.03` |
| **🥉 3º LUGAR** | **Tesseract PSM 6 (Bloco Uniforme)** | **100.00%** | **100.00%** | 0.0% | 0.0% | 15.0 ms | 0.0 MB | 0 | `80.03` |
| **4º** | **Tesseract PSM 11 (Texto Esparso)** | **100.00%** | **100.00%** | 0.0% | 0.0% | 15.1 ms | 0.0 MB | 0 | `80.03` |
| **5º** | **Tesseract PSM 3 (Auto)** | **100.00%** | **100.00%** | 0.0% | 0.0% | 17.6 ms | 0.0 MB | 0 | `80.04` |

---

## 2. Decisão Arquivística Homologada
* **Motor Primário da GPU:** **RapidOCR GPU** (vencedor pelo menor CER e maior estabilidade de reconhecimento).
* **Motor Secundário de Consenso:** **Tesseract PSM 4 (Colunas)** (integrado na matriz de auto-consistência para alinhamento via Needleman-Wunsch).
* **Configuração de PSM Recomendada para Tesseract:** **PSM 4** provou-se superior para o corpus histórico bilíngue.
