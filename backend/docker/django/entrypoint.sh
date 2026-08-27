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

# Aguardar o banco de dados e o Redis, se necessário
# Aqui usamos um simples check, mas em produção o depends_on com healthcheck do compose lidará melhor.

# Executar migrações do banco (opcional no boot em prod, mas mantido para dev)
if [ "$PRODUCTION" != "True" ]; then
    echo "[entrypoint] Aplicando migrações..."
    python manage.py migrate --noinput
    
    echo "[entrypoint] Coletando arquivos estáticos..."
    python manage.py collectstatic --noinput
fi

# Executar o comando passado pro container (runserver, gunicorn ou bash)
exec "$@"
