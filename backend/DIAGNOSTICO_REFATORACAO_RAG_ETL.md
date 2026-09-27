# RELATÓRIO FORENSE DE DIAGNÓSTICO PRÉ-REFATORAÇÃO — RAG, ETL & FALLBACK
**Data:** 25 de Setembro de 2026  
**Auditor:** Agente de Engenharia e Segurança do TupiLingo  
**Diretriz:** Factual, baseado estritamente na inspeção do código-fonte e chamadas de teste aos endpoints reais.

---

## 1. Provedores Configurados e Modelos Hardcoded Hoje

### 1.1 Chaves Presentes no Arquivo `.env` (`backend/.env`)
Inspeção direta de `backend/.env` revelou as seguintes chaves de API:
1. `GROQ_API_KEY`: Presente (`gsk_...`) -> **Provedor ATIVO**.
2. `GEMINI_API_KEY`: Presente (`AQ.Ab8...`) -> **Provedor ATIVO**.
3. `DASHSCOPE_API_KEY`: Presente (`sk-ws-H...`) -> **Provedor INATIVO** (HTTP 403 `AllocationQuota.FreeTierOnly` confirmado por API).
4. `CEREBRAS_API_KEY`: Presente (`csk-9x...`) -> **Provedor INATIVO** (HTTP 402 `payment_required` confirmado por API).
5. `SAMBANOVA_API_KEY`: Presente (`aef513...`) -> **Provedor INATIVO** (HTTP 402 `PAYMENT_METHOD_REQUIRED` confirmado por API).
6. `OPENROUTER_API_KEY`: Presente (`sk-or-v1-...`) -> **Instável/Pago** (`minimax/minimax-m2.7:free` retornou 404 por descontinuação do tier free).
7. `OPENAI_API_KEY`: Presente (`sk-proj-...`).
8. `COHERE_API_KEY`: Presente (`xPkYdN...`).
*Nota sobre o "provedor com C":* Existem chaves para **Cerebras** e **Cohere**. Não há chave de Claude/Anthropic no `.env`.

### 1.2 Modelos Hardcoded vs. Modelos Reais nos Provedores (`app/ai/router.py`)

| Provedor | Modelos Hardcoded no `router.py` | Status Real na API do Provedor (`models.list()`) |
| :--- | :--- | :--- |
| **DashScope** | `qwen-plus`, `qwen3.6-plus`, `qwen-turbo`, `qwen-max`, `qwen2.5-coder` | `qwen-plus`, `qwen-turbo`, `qwen-max` existem; **`qwen2.5-coder` NÃO EXISTE (404)** (o slug correto é `qwen-coder-plus`). Cota free esgotada (403). |
| **Cerebras** | `qwen-3.8-27b`, `gemma-4-31bPreview`, `gpt-oss-120bProduction` | `qwen-3.8-27b` e `gpt-oss-120b` existem; **`gemma-4-31bPreview` e `gpt-oss-120bProduction` NÃO EXISTEM (404)**. Saldo zerado (402). |
| **Groq** | `openai/gpt-oss-120b`, `openai/gpt-oss-20b`, `qwen/qwen3.8-27b`, `qwen/qwen3.6-27b`, `allam-2-7b`, `groq/compound`, `groq/compound-mini` | `openai/gpt-oss-120b`, `openai/gpt-oss-20b`, `qwen/qwen3.8-27b`, `allam-2-7b` existem e respondem; **`qwen/qwen3.6-27b`, `groq/compound`, `groq/compound-mini` NÃO EXISTEM (404)**. |
| **SambaNova** | `DeepSeek-V3.1`, `DeepSeek-V3.2`, `Meta-Llama-3.3-70B-Instruct`, `MiniMax-M2.7`, `MiniMax-M3`, `gemma-4-31B-it`, `gpt-oss-120b` | Slugs existem na listagem, mas **todas as requisições falham com 402** (método de pagamento obrigatório). |
| **Gemini** | `gemini-2.5-flash` | **Ativo e respondendo com sucesso** em `gemini-2.5-flash`, `gemini-3.6-flash`, `gemini-2.5-flash-lite`. |

---

## 2. Propagação de Exceções por SDK no Código Atual

Leitura dos arquivos `app/ai/providers/*.py` e teste das respostas HTTP:

| Código HTTP | Exceção Lançada pelo SDK | Como o Código Atual trata (`_map_exception`) | Impacto no Fallback |
| :---: | :--- | :--- | :--- |
| **401** (Unauthorized) | `openai.AuthenticationError` / `google.genai.errors.APIError(401)` | Mapeia para `app.ai.exceptions.AuthenticationError`. | Não está em `_RETRYABLE`, mas `fallback.py` não desativa o modelo no Redis por 24h. |
| **402** (Payment Required) | `openai.APIStatusError(402)` | Não tratado nos providers; cai no `AIProviderError(str(e))`. | Tratado como erro genérico. Vai para cooldown de apenas 120s e é tentado de novo. |
| **403** (Forbidden / Quota) | `openai.PermissionDeniedError(403)` | Não tratado especificamente em `dashscope.py`, `cerebras.py`, `sambanova.py`; cai no `AIProviderError(str(e))`. | Tratado como erro genérico. Repetido em loop. |
| **404** (Not Found / Bad Slug) | `openai.NotFoundError(404)` / `google.genai.errors.APIError(404)` | Não tratado; cai no `AIProviderError(str(e))`. | O modelo morto não é marcado como fatal. Gera tentativa a cada chunk. |
| **429** (Rate Limit) | `openai.RateLimitError` / `google.genai.errors.APIError(429)` | Mapeia para `RateLimitError`. | Está em `_RETRYABLE`, mas o cooldown progressivo é resetado pelo loop de emergência. |
| **500 / 503** (Server Error) | `openai.InternalServerError` / `google.genai.errors.APIError(500/503)` | Mapeia para `ServiceUnavailableError`. | Transitório. |

---

## 3. Por Que o `FallbackOrchestrator` Permitir ~190 Tentativas em um Modelo Morto

A investigação encontrou 3 falhas estruturais combinadas:

1. **Reset Cego de Penalidades no `FallbackOrchestrator` (`app/ai/fallback.py`, linhas 103–107):**
   ```python
   active_chain = [m for m in ranked_chain if not PingRaceRouter.is_in_cooldown(m)]
   if not active_chain:
       # FALHA: Quando todos os modelos entram em cooldown, reseta TODAS as penalidades!
       active_chain = list(ranked_chain)
   ```
   Quando o modelo morto (`dashscope/qwen2.5-coder` ou DashScope 403) recebia cooldown, assim que os outros modelos também falhavam ou estavam em cooldown, o orquestrador simplesmente **apagava a penalidade** e tentava o modelo morto novamente na mesma requisição ou na próxima.

2. **Loop Externo 1 a 1 no Worker (`trilha/management/commands/extract_vocab_from_rag.py`, linhas 213–231):**
   ```python
   for target in chain:
       res = FallbackOrchestrator.execute_with_fallback(..., chain=[target])
   ```
   O worker itera sobre cada modelo individualmente passando `chain=[target]`. Como a lista passada tem apenas 1 modelo, o `FallbackOrchestrator` vê `active_chain` com tamanho 1 e, se estiver em cooldown, executa o reset de emergência e **bate no modelo morto de novo a cada chunk do lote de 50**. $50 \text{ chunks} \times 4 \text{ modelos mortos} = 200 \text{ tentativas frustradas}$ com log massivo.

3. **Inexistência de Categoria "Fatal" (Dead Model) Persistida:**
   O circuito não diferenciava um 429 temporário de um 404/403 definitivo. Não existia chave Redis de modelo morto (ex.: `circuit:fatal:<target>`) com TTL de 24h que sobreviva entre execuções.

---

## 4. Mecanismos de Checkpoint Existentes no Repositório

1. **`ingest_progress.json`:** Localizado na raiz do backend (`backend/ingest_progress.json`). Utilizado pelo `pdf_worker.py` para rastrear o processamento de PDFs por `file_hash`, salvando `last_page`, `chunk_counter` e `done: bool`.
2. **SQLite local (`vector_store.db`):** Tabela `documents` possui a coluna `category_extracted` (0 para pendente, 1 para processado).
3. **Supabase/PostgreSQL:** Tabela `rag_document_categories` com restrição de unicidade `idx_rag_document_categories_chunk_id ON rag_document_categories (chunk_id)`.

**Diretriz para o ETL:** A idempotência do worker deve consultar tanto a coluna `category_extracted` no SQLite quanto a existência do `chunk_id` em `rag_document_categories`, suportando as flags `--reprocess-all` (reprocessar do zero) e `--reprocess-heuristic` (reprocessar apenas chunks que usaram fallback heurístico).
