# Verificação de Integração de Pipeline de Ponta a Ponta — RFC v6.1

**Data:** 2026-09-27 21:05:46 UTC  

---

## 1. Matriz de Integração dos 35 Capítulos no Fluxo Ativo

```
[Imagem 300 DPI do PDF Histórico]
         │
         ▼
[Cap 25: Orientation & Dewarp Engine] ───────────► Corrigido para 0° e planificado
         │
         ▼
[Cap 19: Consensus Layout Engine (WBF)] ────────► Bounding boxes com confiança ponderada
         │
         ▼
[Cap 20: Self-Consistency OCR Engine] ──────────► Matriz de hipóteses e consenso Needleman-Wunsch
         │
         ▼
[Cap 26: Token Super-Resolution Seletiva] ──────► Aplicação de Real-ESRGAN apenas se conf < 0.75
         │
         ▼
[Caps 23 & 24: Hierarchical Lexicon & Consensus] ► 4 Níveis etimológicos + Cross-PDF validation
         │
         ▼
[Cap 27: Bayesian Confidence Engine] ───────────► Fusão Likelihood Ratio + Trava de Piso
         │
         ▼
[Cap 28: Region Quality Engine] ────────────────► Heatmap visual RGBA e diagnóstico regional
         │
         ▼
[Cap 10 & 29: Rollback & Active Learning Gate] ──► Preservação estrita de invariantes Tupi
         │
         ▼
[Cap 11 & 14: Multi-Exporter & Artifact Bundle] ─► hOCR, ALTO XML, PAGE XML, JSON-LD, Parquet
         │
         ▼
[Cap 30: Cache LMDB v2 Multi-Database] ─────────► Indexação por SHA-256 atômico
```

---

## 2. Pontos de Acoplamento Verificados
- `ForensicPipelineOrchestrator`: Inicializa e coordena todos os motores de consenso.
- `AutonomousOvernightScheduler`: Gerencia o lote resiliente com isolamento de OOM e checkpoint LMDB/SQLite.
- `run_research_ocr.py`: Driver local de interface gráfica/terminal para o operador.
