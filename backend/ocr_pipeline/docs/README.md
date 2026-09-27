# TupiLingo OCR Forense v3.0 (Production Architecture)

Pipeline de Engenharia Reversa e OCR Forense Arquivístico para Reconstrução de Documentos Históricos em Língua Tupi.

Projetada para execução contínua autônoma (_Overnight Autonomous Processing_) em estações com CPU **AMD Ryzen 5 5500U (6 núcleos / 12 threads) e 8 GB de RAM**, sem dependência de placas aceleradoras GPU/CUDA.

---

## 🚀 Destaques da Arquitetura v3.0

- **Qualidade Absoluta em CPU**: Utiliza ONNX Runtime CPU com quantização INT8 dinâmica e paralelismo controlado (`OMP_NUM_THREADS=6`), operando estritamente dentro da memória livre disponível (< 1.5 GB working set).
- **12 Motores Independentes**:
  1. **Diagnóstico Forense (12 Dimensões)**: Blur score, variância Laplaciana, ângulo de inclinação (Hough/PCA), histograma LAB, detector de sangramento de verso (_bleed-through_), heatmap de iluminação, espessura de traço (Stroke Width Transform), componentes conectados, amarelamento de celulose (_foxing_), desbotamento de tinta, espectro de ruído 2D FFT e energia de Wavelets.
  2. **Pré-processamento Multi-Branch (30 Branches)**: Catálogo com 30 pipelines ortogonais de visão computacional (Sauvola, Niblack, Wolf, Bernsen, Otsu, Multi-Otsu, CLAHE, Retinex, NLM, Wavelet, FFT, TopHat, BlackHat, Reconstrução Morfológica, Deskew, etc.).
  3. **Análise de Layout**: Identificação semântica de cabeçalhos, colunas duplas, notas de rodapé e blocos de verbetes com preservação estrita da ordem lógica de leitura.
  4. **Super-Resolução Seletiva**: Realce localizado 2x/3x/4x via interpolação de alta ordem com realce de bordas em tiles com degradação visual.
  5. **OCR Ensemble Multi-Motor**: Combinação do RapidOCR (PaddleOCR PP-OCRv4 ONNX) com o Tesseract LSTM executando múltiplos PSMs (3, 4, 6, 11) e dicionários de termos Tupi (`--user-words`).
  6. **Votação e Alinhamento por Token**: Programação dinâmica de Needleman-Wunsch para alinhamento global de caracteres, distância de Levenshtein e votação ponderada com salvaguarda de diacríticos nasais Tupi (`ẽ`, `ĩ`, `ỹ`, `õ`, `ã`).
  7. **Fusão de Confiança e Heatmaps**: Pontuação composta ponderada ($0.45 \cdot \text{ocr} + 0.20 \cdot \text{vis} + 0.20 \cdot \text{lex} + 0.15 \cdot \text{rag}$) e renderização de mapa de calor em PNG com transparência alfa.
  8. **Corretor Léxico Forense**: SymSpell adaptativo com **Parser Morfológico Tupi** (decomposição de prefixos, sufixos nominais e clíticos) e salvaguardas invariantes (números, datas e nomes próprios estritamente intocáveis).
  9. **Validador RAG Zero Alucinação**: Consulta direta ao banco de dados SQLite local (`vector_store.db`) com 22.140 chunks de texto histórico para rejeitar alucinações e vocábulos espúrios sem suporte empírico.
  10. **Recuperação Iterativa e Rollback Gate**: Regiões com confiança inferior a 90% são reprocessadas iterativamente com permutações de filtros; qualquer proposta de alteração que reduza a confiança é revertida imediatamente ao original bruto.
  11. **Checkpoints Persistentes**: Gravação transacional atômica em SQLite (`pipeline_checkpoints.db`) e streaming JSONL (`pipeline_progress.jsonl`), permitindo retomar o processamento de onde parou após qualquer interrupção.
  12. **Exportação Arquivística Multi-Formato**: Exportação simultânea para **TXT, Markdown com frontmatter, JSON, JSONL, CSV tabular, ALTO XML (Library of Congress), PAGE XML (PRImA) e HTML anotado interativo**.

---

## 🛠️ Instalação e Requisitos

### Pré-requisitos
- Python 3.11, 3.12, 3.13 ou 3.14
- Tesseract-OCR instalado no sistema operacional (em Windows: `C:\Program Files\Tesseract-OCR\tesseract.exe`)

### Dependências Python
```bash
pip install -r requirements.txt
pip install scikit-image onnxruntime rapidocr-onnxruntime pytesseract pydantic symspellpy PyMuPDF
```

---

## 💻 Guia Rápido de Uso

### 1. Processar uma página individual
```python
import cv2
from ocr_pipeline.core.orchestrator import ForensicPipelineOrchestrator

orchestrator = ForensicPipelineOrchestrator()
img = cv2.imread("pagina_historica.png")
summary = orchestrator.process_page(
    image_rgb=cv2.cvtColor(img, cv2.COLOR_BGR2RGB),
    page_num=42,
    filename="documento_anchieta.pdf",
    force_reprocess=False
)

print(f"Confiança média: {summary.mean_confidence * 100:.2f}%")
print(f"Tokens Tupi identificados: {summary.tupi_tokens_count}")
print(f"Relatório exportado em: {summary.export_bundle.markdown_path}")
```

### 2. Processar um PDF por Streaming (Sem carregar na RAM)
```python
from pathlib import Path
from ocr_pipeline.core.orchestrator import ForensicPipelineOrchestrator

orchestrator = ForensicPipelineOrchestrator()
pdf_path = Path("pdfs/Dicionario_Tupi.pdf")

for page_summary in orchestrator.process_pdf(pdf_path, max_pages=100, start_page=1):
    print(f"Página {page_summary.page_num} processada em {page_summary.duration_seconds:.2f}s")
```

### 3. Executar o Benchmark Comparativo
```bash
python -m ocr_pipeline.benchmarking.benchmark_v3
```

---

## 🧪 Testes Automatizados

A suíte completa conta com 26 testes cobrindo todos os módulos da arquitetura:
```bash
pytest ocr_pipeline/tests/ -v
```

---

## 📊 Formatos Exportados por Página

| Formato | Arquivo | Finalidade |
| :--- | :--- | :--- |
| **Markdown** | `page_XXXX.md` | Leitura humana com metadados forenses no frontmatter YAML |
| **TXT** | `page_XXXX.txt` | Transcrição textual limpa em UTF-8 |
| **JSON** | `page_XXXX.json` | Estrutura completa de diagnósticos, caixas e confiança |
| **JSONL** | `page_XXXX.tokens.jsonl` | Linhagem por token para indexação vetorial |
| **CSV** | `page_XXXX_tokens.csv` | Tabela de tokens, coordenadas, motor de origem e score |
| **ALTO XML** | `page_XXXX_alto.xml` | Padrão arquivístico da Library of Congress para OCR |
| **PAGE XML** | `page_XXXX_page.xml` | Padrão PRImA Research para análise de leiaute |
| **HTML** | `page_XXXX_annotated.html` | Interface visual interativa com tooltips de confiança |
| **Heatmap** | `page_XXXX_heatmap.png` | Mapa de calor com overlay semitransparente por nível de certeza |

---

## 🔧 Solução de Problemas (Troubleshooting)

1. **Erro de Caminho do Tesseract**:
   - Se o Tesseract não estiver no PATH global do Windows, confirme se o binário reside em `C:\Program Files\Tesseract-OCR\tesseract.exe`. É possível customizar via `OCREnsembleConfig(tesseract_cmd="...")`.
2. **Alerta de Memória Elevada (> 1500 MB)**:
   - A pipeline possui `gc.collect()` ativado por padrão após cada página. Se executar em lote muito grande, garanta que os pixmaps do PyMuPDF sejam deletados entre iterações conforme implementado em `process_pdf()`.
3. **Caracteres Tupi com Diacrítico Subvertidos**:
   - O `ForensicTokenVotingEngine` aplica automaticamente um multiplicador de 1.25 para tokens contendo diacríticos autênticos (`ẽ`, `ĩ`, `ỹ`), priorizando o motor que os preservou em detrimento de aproximações sem acento.
