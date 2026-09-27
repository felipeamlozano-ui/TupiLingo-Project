# Dockerfile — TupiLingo OCR Forense v3.0 (CPU-Only Production Build)
FROM python:3.12-slim-bookworm

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    OMP_NUM_THREADS=6 \
    MKL_NUM_THREADS=6 \
    DEBIAN_FRONTEND=noninteractive

# Instalação de utilitários de sistema e Tesseract OCR com idiomas de suporte
RUN apt-get update && apt-get install -y --no-install-recommends \
    tesseract-ocr \
    tesseract-ocr-por \
    libgl1 \
    libglib2.0-0 \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Instalação das dependências Python
COPY requirements.txt .
RUN pip install --no-cache-dir -U pip setuptools wheel && \
    pip install --no-cache-dir \
    numpy \
    scipy \
    opencv-python-headless \
    scikit-image \
    Pillow \
    pydantic \
    onnxruntime \
    rapidocr-onnxruntime \
    pytesseract \
    symspellpy \
    PyMuPDF \
    pytest

# Cópia do código-fonte da pipeline
COPY . /app

# Volume para exportações arquivísticas e checkpoints
VOLUME ["/app/ocr_exports", "/app/ocr_cache"]

# Ponto de entrada padrão
CMD ["python", "-m", "pytest", "ocr_pipeline/tests/", "-v"]
