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

# Executar migrações do banco — necessário em todos os ambientes para garantir schema atualizado
echo "[entrypoint] Aplicando migrações..."
python manage.py migrate --noinput

# Coletar arquivos estáticos — necessário em todos os ambientes (servidos pelo Nginx/whitenoise)
echo "[entrypoint] Coletando arquivos estáticos..."
python manage.py collectstatic --noinput --clear

# Executar o comando passado pro container (runserver, gunicorn ou bash)
exec "$@"
