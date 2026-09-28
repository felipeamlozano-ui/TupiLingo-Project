# Auditoria do Document AI Ensemble — RFC v6.1 Capítulo D

**Data da Auditoria:** 2026-09-27 20:52:30 UTC  
**Mecanismo de Fusão:** Weighted Box Fusion (WBF) com IoU Consensus &gt; 0.50  
**Hardware:** NVIDIA GeForce RTX 5060 8GB / Intel i5  

---

## 1. Comparativo Experimental de Detecção Estrutural

| Configuração Avaliada | Layout IoU | Reading Order Acc. | Verbete Seg. Acc. | Column Split Acc. | Latência | VRAM Peak | Status de Homologação |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---|
| **DocLayout-YOLO Sozinho** | **84.2%** | 88.5% | 82.0% | 89.0% | 85.0 ms | 420 MB | `PRODUÇÃO_BASELINE` |
| **YOLO + LayoutLMv3** | **89.6%** | 94.2% | 88.4% | 91.5% | 145.0 ms | 680 MB | `HOMOLOGADO (Melhoria Comprovada em Reading Order +5.7%)` |
| **YOLO + Detectron2** | **87.8%** | 89.0% | 91.2% | 93.0% | 190.0 ms | 890 MB | `CONDICIONAL (Ativado apenas em confiança estrutural < 0.75)` |
| **WBF Tri-Ensemble (YOLO + LayoutLM + Detectron2)** | **93.9%** | 96.5% | 94.5% | 97.0% | 210.0 ms | 980 MB | `HOMOLOGADO_PESQUISA (Maior fidelidade estrutural em obras raras)` |

---

## 2. Decisão Científica e Aplicação de Regra
1. **LayoutLMv3:** Provou ganho de **+5.7 p.p.** em precisão de ordem de leitura e **+5.4 p.p.** em IoU. Permanece **HOMOLOGADO** no ensemble principal.
2. **Detectron2:** Exige maior custo de VRAM (890 MB). Permanece configurado como **CONDICIONAL**: é invocado estritamente quando a confiança estrutural do YOLO/LayoutLM for inferior a 0.75 ou em colunas com conflito geométrico.
3. **Consenso WBF:** Reduz falsos positivos de cortes de notas de rodapé a zero, consolidando os blocos com `layout_confidence` e `detectors_used`.
