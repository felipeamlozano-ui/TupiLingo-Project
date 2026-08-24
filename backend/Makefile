# =============================================================
# Makefile — TupiLingo Backend Docker
# Atalhos para os comandos Docker mais comuns
# =============================================================

.PHONY: dev prod down logs shell ingest migrate collectstatic help

# Arquivos de compose
COMPOSE_BASE = docker-compose.yml
COMPOSE_DEV  = docker-compose.dev.yml
COMPOSE_PROD = docker-compose.prod.yml

## Desenvolvimento
dev:
	@echo ">>> Subindo ambiente de desenvolvimento..."
	docker compose -f $(COMPOSE_BASE) -f $(COMPOSE_DEV) up --build

dev-d:
	@echo ">>> Subindo desenvolvimento em background..."
	docker compose -f $(COMPOSE_BASE) -f $(COMPOSE_DEV) up --build -d

## Produção
prod:
	@echo ">>> Subindo ambiente de produção..."
	docker compose -f $(COMPOSE_BASE) -f $(COMPOSE_PROD) up --build -d

## Para todos os serviços
down:
	docker compose -f $(COMPOSE_BASE) -f $(COMPOSE_DEV) down --remove-orphans

down-prod:
	docker compose -f $(COMPOSE_BASE) -f $(COMPOSE_PROD) down --remove-orphans

## Logs
logs:
	docker compose -f $(COMPOSE_BASE) -f $(COMPOSE_DEV) logs -f django

logs-worker:
	docker compose -f $(COMPOSE_BASE) -f $(COMPOSE_DEV) logs -f pdf_worker

logs-all:
	docker compose -f $(COMPOSE_BASE) -f $(COMPOSE_DEV) logs -f

## Shell interativo dentro do container Django
shell:
	docker compose -f $(COMPOSE_BASE) -f $(COMPOSE_DEV) exec django python manage.py shell

## Processamento manual de PDFs (coloca PDFs em backend/pdfs/ primeiro!)
ingest:
	@echo ">>> Rodando PDF Worker manualmente..."
	docker compose -f $(COMPOSE_BASE) -f $(COMPOSE_DEV) run --rm pdf_worker python /app/pdf_worker.py

## Migrações manuais
migrate:
	docker compose -f $(COMPOSE_BASE) -f $(COMPOSE_DEV) exec django python manage.py migrate

## Coleta de estáticos manual
collectstatic:
	docker compose -f $(COMPOSE_BASE) -f $(COMPOSE_DEV) exec django python manage.py collectstatic --noinput

## Build apenas (sem subir)
build-dev:
	docker compose -f $(COMPOSE_BASE) -f $(COMPOSE_DEV) build

build-prod:
	docker compose -f $(COMPOSE_BASE) -f $(COMPOSE_PROD) build

## Limpa volumes (CUIDADO: apaga o banco vetorial!)
clean-volumes:
	@echo "AVISO: Isso apagará todos os volumes incluindo o banco vetorial SQLite!"
	@read -p "Tem certeza? (s/N) " confirm; \
	if [ "$$confirm" = "s" ]; then \
		docker compose -f $(COMPOSE_BASE) -f $(COMPOSE_DEV) down -v; \
	fi

## Ajuda
help:
	@echo "TupiLingo Backend — Comandos Docker"
	@echo "======================================"
	@echo "  make dev          — Sobe ambiente de desenvolvimento com hot reload"
	@echo "  make prod         — Sobe produção com Gunicorn (modo daemon)"
	@echo "  make down         — Para os containers de desenvolvimento"
	@echo "  make logs         — Segue os logs do Django"
	@echo "  make logs-worker  — Segue os logs do PDF Worker"
	@echo "  make ingest       — Processa PDFs manualmente"
	@echo "  make shell        — Shell Django interativo"
	@echo "  make migrate      — Aplica migrações"
	@echo "  make build-dev    — Faz build da imagem de dev"
	@echo "  make build-prod   — Faz build da imagem de produção"
	@echo "  make clean-volumes— APAGA TODOS OS VOLUMES (use com cuidado!)"
