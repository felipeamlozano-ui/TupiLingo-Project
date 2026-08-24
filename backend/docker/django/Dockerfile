# =============================================================
# Dockerfile — TupiLingo Django Backend (PRODUÇÃO)
# Multi-stage: builder instala deps, runner é a imagem final enxuta
# =============================================================

# ------------- STAGE 1: builder -------------
FROM python:3.13-slim AS builder

WORKDIR /build

# Dependências do sistema para compilação e PostgreSQL
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copia e instala dependências Python em modo "wheel"
# Separar o COPY do requirements antes do código evita rebuilds desnecessários
COPY requirements.txt .
RUN pip install --upgrade pip \
    && pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt


# ------------- STAGE 2: runner (imagem final) -------------
FROM python:3.13-slim AS runner

# Usuário não-root (segurança)
RUN groupadd -r tupilingo && useradd -r -g tupilingo -m -d /home/tupilingo tupilingo

WORKDIR /app

# Dependências de sistema para runtime
# - libpq5: driver PostgreSQL (psycopg2)
# - tesseract-ocr: OCR de imagens nos PDFs
# - tesseract-ocr-por: dicionário Português para Tesseract
# - poppler-utils: suporte a PDF para Pillow (imagens embutidas)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    tesseract-ocr \
    tesseract-ocr-por \
    poppler-utils \
    && rm -rf /var/lib/apt/lists/*

# Instala wheels compilados no stage anterior (rápido, sem compilar novamente)
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir --no-index --find-links=/wheels /wheels/* \
    && rm -rf /wheels

# Copia o código da aplicação
COPY --chown=tupilingo:tupilingo . .

# Garante que os diretórios de dados existam e pertencem ao usuário
RUN mkdir -p /app/staticfiles /app/media /app/pdfs /app/logs \
    && chown -R tupilingo:tupilingo /app

# Entrypoint (migrate + collectstatic + gunicorn)
COPY --chown=tupilingo:tupilingo docker/django/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Troca para usuário não-root
USER tupilingo

# Variáveis de ambiente padrão (podem ser sobrescritas no compose)
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    DJANGO_SETTINGS_MODULE=config.settings.production \
    PYTHONPATH=/app

# Porta interna do Gunicorn
EXPOSE 8000

# Healthcheck: Django responde em /api/health/
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/api/health/')" || exit 1

ENTRYPOINT ["/entrypoint.sh"]
