#!/bin/bash
set -e

echo "========================================================"
echo "  TupiLingo Backend — Iniciando..."
if [ "$PRODUCTION" = "True" ]; then
    echo "  Ambiente: PRODUÇÃO"
else
    echo "  Ambiente: DESENVOLVIMENTO"
fi
echo "========================================================"

# Executar migrações do banco apenas se não estiver desabilitado explicitamente
if [ "$SKIP_MIGRATIONS" != "true" ] && [ "$SKIP_MIGRATIONS" != "1" ]; then
    echo "[entrypoint] Aplicando migrações..."
    python manage.py migrate --noinput
else
    echo "[entrypoint] Pulando migrações (SKIP_MIGRATIONS ativo)..."
fi

# Coletar arquivos estáticos apenas no container da web/API
if [ "$SKIP_COLLECTSTATIC" != "true" ] && [ "$SKIP_COLLECTSTATIC" != "1" ] && [ "$SKIP_MIGRATIONS" != "true" ]; then
    echo "[entrypoint] Coletando arquivos estáticos..."
    python manage.py collectstatic --noinput --clear
fi

# Executar o comando passado pro container (runserver, gunicorn ou bash)
exec "$@"
