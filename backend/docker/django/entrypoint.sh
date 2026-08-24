#!/bin/bash
# =============================================================
# entrypoint.sh — TupiLingo Django/Worker
# Executado ao iniciar qualquer container Django ou Worker
# =============================================================

set -e  # Sai imediatamente se qualquer comando falhar

echo "========================================================"
echo "  TupiLingo Backend — Iniciando..."
echo "  Settings: ${DJANGO_SETTINGS_MODULE}"
echo "========================================================"

# Aguarda banco de dados ficar pronto (Supabase é remoto, normalmente disponível)
# Mas faz 3 tentativas de migração com retry para lidar com cold start
MAX_RETRIES=5
RETRY_INTERVAL=5

echo "[entrypoint] Verificando conexão com o banco de dados..."
for i in $(seq 1 $MAX_RETRIES); do
    python manage.py check --database default > /dev/null 2>&1 && break
    echo "[entrypoint] Tentativa $i/$MAX_RETRIES — aguardando banco... (${RETRY_INTERVAL}s)"
    sleep $RETRY_INTERVAL
done

# Aplica migrações pendentes
echo "[entrypoint] Aplicando migrações..."
python manage.py migrate --noinput

# Coleta arquivos estáticos (necessário para Nginx servir em produção)
echo "[entrypoint] Coletando arquivos estáticos..."
python manage.py collectstatic --noinput --clear

echo "[entrypoint] Inicialização completa!"
echo "========================================================"

# Executa o comando passado ao container (CMD do compose)
exec "$@"
