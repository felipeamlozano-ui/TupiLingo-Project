# Auditoria de Dependências — TupiLingo OCR Pipeline v6.1

**Data:** 2026-09-27 21:05:46 UTC  
**Ambiente Python:** Python 3.12 (venv local)  
**Acelerador Primário:** NVIDIA GeForce RTX 5060 (8GB VRAM `sm_120`)  

---

## 1. Dependências Críticas e Status de Aceleração

| Pacote | Versão Detectada | Suporte CUDA / Hardware | Papel no Pipeline | Status de Validação |
|:---|:---:|:---:|:---|:---:|
| `onnxruntime-gpu` | 1.19.2 | ✅ CUDA 12 Provider Ativo | Motor de inferência rápida do RapidOCR | **HOMOLOGADO** |
| `torch` / `torchvision` | 2.5.1+cu124 | ⚠️ sm_120 (fallback CPU/Torch) | Modelos neurais de super-resolução | **MONITORADO (CPU Safe)** |
| `rapidocr_onnxruntime` | 1.3.8 | ✅ CUDA Execution Provider | OCR principal via GPU | **HOMOLOGADO** |
| `pytesseract` | 0.3.13 | ℹ️ CPU Multi-threading | OCR secundário para validação por consenso | **HOMOLOGADO** |
| `opencv-python` | 4.10.0.84 | ✅ Otimizado AVX2/CPU | Filtros de imagem e morfologia matemática | **HOMOLOGADO** |
| `lmdb` | 1.4.1 | ✅ I/O em disco nativo | Cache persistente v2 de tensores | **HOMOLOGADO** |
| `pyarrow` | 25.0.1 | ✅ Colunar de alta performance | Exportação de `METRICAS_DETALHADAS.parquet` | **HOMOLOGADO** |
| `PyPDF2` | 3.0.1 | ℹ️ I/O Puro | Leitura estrutural dos 39 PDFs | **HOMOLOGADO** |
| `pypdfium2` | 4.30.0 | ✅ Renderização rápida C++ | Rasterização de páginas em 300 DPI | **HOMOLOGADO** |
| `pydantic` | 2.10.6 | ℹ️ Validação de Contrato | Modelagem tipada de metadados | **HOMOLOGADO** |

---

## 2. Diagnóstico de Isolamento Offline
- **Chamadas de Rede Externas:** 0 (zero) chamadas permitidas em produção.
- **Modelos Pré-Treinados:** Devem ser cacheados localmente em `models/` e `ocr_cache/`.
