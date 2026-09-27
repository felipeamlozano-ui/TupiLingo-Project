# Architecture Decision Records (ADR) — TupiLingo OCR Forense v3.0

## ADR 001: Execução Exclusiva em CPU (Ryzen 5 5500U • No CUDA / No Dedicated GPU)

### Status
Aprovado e Implementado.

### Contexto
O hardware alvo do projeto é um notebook com APU AMD Ryzen 5 5500U (6 núcleos, 12 threads lógicas) e 8 GB DDR4 compartilhados com o subsistema gráfico Vega integrado. Não há placa de vídeo dedicada (sem CUDA, sem TensorRT). O sistema operacional hospedeiro possui entre 1.2 GB e 2.5 GB de RAM livre operacional.

### Decisão
1. Eliminar dependências de PyTorch CUDA pesado e modelos monolíticos não quantizados.
2. Adotar ONNX Runtime CPU com quantização INT8 dinâmica e paralelismo configurado estritamente para 6 threads de computação (`OMP_NUM_THREADS=6`), prevenindo _thread thrashing_.
3. Executar processamento por páginas e regiões individuais (tile processing com sliding window), nunca carregando PDFs inteiros na RAM.
4. Chamar coleta de lixo forçada (`gc.collect()`) explicitamente no encerramento de cada página para manter o working set do processo estritamente abaixo do teto de segurança de 1.500 MB.

### Consequências
- **Positivas**: Estabilidade de longo prazo em lotes noturnos (overnight 12h–24h) sem risco de travamento por Out-Of-Memory (OOM).
- **Compensações**: Latência por página de ~2 a 4 segundos, perfeitamente aceitável dado que o critério primário é a qualidade arquivística absoluta.

---

## ADR 002: Catálogo de 30 Branches Independentes de Visão Computacional

### Status
Aprovado e Implementado.

### Contexto
PDFs históricos coloniais do século XVI a XIX apresentam heterogeneidade extrema de patologias físicas: amarelamento de celulose, _bleed-through_ (tinta que transpassa do verso), _foxing_ (manchas fúngicas), iluminação não-uniforme (vinhetagem) e desgaste de traço tipográfico manual. Nenhum filtro isolado (como binarização de Otsu global) resolve todos os cenários.

### Decisão
Implementar um catálogo ortogonal de 30 branches OpenCV/scikit-image:
- **Binarização adaptativa**: Sauvola, Niblack, Wolf, Bernsen, Otsu, Multi-Otsu.
- **Equalização e Contraste**: CLAHE, Retinex multiescala, Contrast Stretching, Gamma correction.
- **Remoção de Bleed e Fundo**: Background Subtraction morfológico, Illumination Normalization.
- **Denoising e Restauração Espectral**: Wavelet Denoising, 2D FFT Bandpass Denoising, Non-Local Means (NLM), Bilateral, Gaussian, Median.
- **Topologia de Traço**: Stroke Enhance via Distance Transform, Skeleton Enhance, Opening, Closing, TopHat, BlackHat, Morphological Reconstruction por dilatação geodésica.
- **Correção de Inclinação (Deskew)**: Hough Transform Deskew, PCA Orientation Deskew, Horizontal Projection Variance Deskew.

---

## ADR 003: Ensemble Híbrido com Votação Ponderada e Needleman-Wunsch

### Status
Aprovado e Implementado.

### Contexto
Mecanismos OCR individuais possuem forças complementares:
- **RapidOCR (PaddleOCR PP-OCRv4 ONNX)**: Excepcional detecção de linhas em papel envelhecido e alta acurácia em caracteres comuns.
- **Tesseract LSTM**: Suporte a dicionários personalizados (`--user-words`) e capacidade de isolar diacríticos raros quando executado com múltiplos modos de segmentação de página (PSM 3, 4, 6, 11).

### Decisão
Executar ambos os motores sobre as branches processadas e unificar os candidatos por votação ponderada:
1. Ponderação base: RapidOCR (1.35), Tesseract PSM 6 (1.0), Tesseract PSM 4 (0.95).
2. Bônus de autenticidade Tupi: +25% para preservação de diacríticos nasais legítimos (`ẽ`, `ĩ`, `ỹ`, `õ`, `ã`).
3. Alinhamento global de sequências de caracteres via programação dinâmica (Needleman-Wunsch) com medição de concordância por similaridade de Jaccard.

---

## ADR 004: Parser Morfológico Tupi e Invariantes Absolutas

### Status
Aprovado e Implementado.

### Contexto
A esmagadora maioria dos corretores ortográficos tradicionais comete **aportuguesamento indevido**, corrompendo vocábulos Tupi autênticos (ex: forçando _oka_ a virar _oca_ ou _ora_, e descaracterizando aglutinações verbais e pronominais legítimas).

### Decisão
1. **Parser Morfológico Determinístico**: Reconhece prefixos pronominais e causativos canônicos (_xe-, nde-, i-, s-, o-, ore-, pe-, mo-, ye-_), sufixos de caso e nominais (_-a, -ba, -pe, -me, -rama, -puera, -ete, -katu_) e partículas.
2. **Invariantes Invioláveis**:
   - Números arábicos, datas e numerais romanos são estritamente intocáveis.
   - Nomes próprios em blacklist são protegidos.
   - Palavras identificadas como Tupi autêntico nunca podem ser substituídas por português.
3. **Preservação Estrita de Caixa Tipográfica (Regra 1.4)**:
   - Se o token original for minúsculo (`oka`), o resultado final permanece minúsculo (`oka`).
   - Se for em caixa alta (`OKA`), permanece `OKA`.
   - Se for em título (`Oka`), permanece `Oka`.

---

## ADR 005: Validação RAG Local Contra o Acervo Real (Zero Alucinação)

### Status
Aprovado e Implementado.

### Contexto
Pipelines que usam LLMs ou modelos de difusão de texto tendem a alucinar vocábulos inexistentes. No processamento forense arquivístico, nenhuma palavra pode ser inventada sem evidência empírica nos documentos históricos ou no léxico pedagógico.

### Decisão
Conectar o validador diretamente ao banco SQLite local (`vector_store.db`), composto por 22.140 chunks de texto real de 5.648 páginas de obras de referência (Anchieta, Lemos Barbosa, Navarro, etc.).
- Qualquer termo candidato que não possua ocorrência documental nem representação léxica válida é marcado como `rejected_hallucination` com score mínimo de RAG (0.10) e descartado pelo Rollback Gate.

---

## ADR 006: Rollback Gate e Auditoria Estruturada em Streaming JSONL

### Status
Aprovado e Implementado.

### Contexto
Erros acumulados ao longo de estágios subsequentes de OCR e PLN podem degradar a qualidade do texto original.

### Decisão
1. **Rollback Gate**: Se a confiança final de um token proposto for menor do que a confiança original do OCR bruto, a modificação é desfeita imediatamente para o candidato bruto.
2. **Auditoria Transacional**: Cada evento (aceite, rejeição, rollback, recuperação) é registrado em tempo real no arquivo de streaming `forensic_audit_trail.jsonl`, permitindo rastreabilidade forense completa de cada caractere.
