#!/bin/bash
# =============================================================
# worker/entrypoint.sh — TupiLingo PDF Worker
# Roda o pdf_worker.py de forma robusta no container
# =============================================================

set -e

echo "========================================================"
echo "  TupiLingo PDF Worker — Iniciando..."
echo "========================================================"

# O worker não precisa do Django, mas garante que o DB SQLite exista
if [ ! -d "/app/pdfs" ]; then
    echo "[worker] Criando diretório /app/pdfs..."
    mkdir -p /app/pdfs
fi

# Verifica se Tesseract está disponível
if command -v tesseract &> /dev/null; then
    echo "[worker] Tesseract disponível: $(tesseract --version 2>&1 | head -1)"
else
    echo "[worker] AVISO: Tesseract não encontrado. OCR de imagens será desativado."
fi

echo "[worker] Iniciando processamento de PDFs..."
echo "========================================================"

# Executa o worker
exec python /app/pdf_worker.py
