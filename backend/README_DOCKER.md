# 🐳 TupiLingo Backend — Guia Docker

Containerização completa do backend Django com Nginx, Gunicorn, PDF Worker e banco vetorial SQLite.

## Pré-requisitos

- Docker Desktop 4.x+ (Windows/Mac) ou Docker Engine 24+ (Linux)
- Docker Compose V2 (já incluído no Docker Desktop)

## Estrutura de Arquivos Docker

```
backend/
├── docker/
│   ├── django/
│   │   ├── Dockerfile         # Produção (multi-stage)
│   │   ├── Dockerfile.dev     # Desenvolvimento (hot reload)
│   │   └── entrypoint.sh     # Migrate + collectstatic automático
│   ├── nginx/
│   │   ├── Dockerfile
│   │   ├── nginx.conf         # Configuração global
│   │   └── default.conf       # Virtual host + proxy reverso
│   └── worker/
│       └── entrypoint.sh     # Entrypoint do PDF Worker
├── docker-compose.yml         # Base (compartilhado)
├── docker-compose.dev.yml     # Override desenvolvimento
├── docker-compose.prod.yml    # Override produção
├── .env.example               # Template de variáveis de ambiente
├── Makefile                   # Atalhos de comandos
└── README_DOCKER.md           # Este arquivo
```

## Início Rápido (Desenvolvimento)

### 1. Configure o `.env`
```bash
cp .env.example .env
# Edite o .env com suas credenciais reais do Supabase, Gemini, Groq
```

### 2. Suba o ambiente
```bash
make dev
# ou manualmente:
docker compose -f docker-compose.yml -f docker-compose.dev.yml up --build
```

### 3. Verifique que está funcionando
```
GET http://localhost/api/health/   → {"status": "ok"}
GET http://localhost:8000/api/health/  → {"status": "ok"}  (direto no Django)
```

## Produção (VPS/Servidor)

### 1. Copie os arquivos para o servidor
```bash
scp -r backend/ usuario@seu-servidor:/opt/tupilingo/
```

### 2. Configure o `.env` de produção
```bash
# No servidor:
cd /opt/tupilingo/backend
cp .env.example .env
nano .env
# Ajuste: DEBUG=False, PRODUCTION=True, ALLOWED_HOSTS=seu-dominio.com
```

### 3. Suba em produção
```bash
make prod
# ou:
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```

## Processamento de PDFs

### Adicionar novos PDFs
1. Copie os PDFs para o volume `pdfs_data`:
   ```bash
   # Localmente: coloque PDFs em backend/pdfs/
   # No servidor: copie para o volume Docker
   docker compose run --rm pdf_worker ls /app/pdfs
   ```

2. Execute o worker manualmente:
   ```bash
   make ingest
   ```

> **Nota:** O container `pdf_worker` já está no compose. Ele sobe junto, processa os PDFs novos e termina. Se não houver PDFs novos, termina imediatamente (não é um daemon).

## Comandos Úteis (via Makefile)

| Comando | Descrição |
|---|---|
| `make dev` | Sobe desenvolvimento com hot reload |
| `make prod` | Sobe produção com Gunicorn |
| `make down` | Para containers de dev |
| `make logs` | Segue logs do Django |
| `make logs-worker` | Segue logs do PDF Worker |
| `make ingest` | Processa PDFs manualmente |
| `make shell` | Shell Django interativo |
| `make migrate` | Aplica migrações do banco |
| `make build-prod` | Faz build da imagem de produção |

## Volumes Persistentes

| Volume | O que armazena |
|---|---|
| `vector_db_data` | Banco vetorial SQLite (`vector_store.db`) |
| `pdfs_data` | PDFs para ingestão |
| `static_files` | Arquivos estáticos coletados pelo Django |
| `media_files` | Uploads de usuários |
| `huggingface_cache` | Modelo `all-MiniLM-L6-v2` (~90MB) |

> ⚠️ **NUNCA execute `docker compose down -v`** sem backup — isso apagará o banco vetorial com todos os PDFs indexados!

## Arquitetura dos Serviços

```
Internet
    │
    ▼
┌─────────────────────────────────────────────┐
│  Nginx :80 (reverse proxy)                  │
│  • Serve /static/ e /media/ diretamente     │
│  • Faz proxy de / para o Gunicorn           │
└──────────────────────┬──────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────┐
│  Django (Gunicorn) :8000 (interno)          │
│  • API REST (DRF)                           │
│  • Lê vector_store.db para RAG              │
│  • Chama Gemini/Groq para gerar questões    │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│  PDF Worker (processo separado)             │
│  • Lê PDFs do volume pdfs_data              │
│  • OCR via Tesseract (Linux nativo)         │
│  • Gera embeddings com all-MiniLM-L6-v2    │
│  • Salva no volume vector_db_data           │
└─────────────────────────────────────────────┘

                  ┌────────────────┐
                  │  Supabase      │
                  │  PostgreSQL    │
                  │  (remoto)      │
                  └────────────────┘
```
