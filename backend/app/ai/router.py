"""
Define as cadeias de fallback de modelos LLM para cada tipo de tarefa no TupiLingo.
Organiza catálogos completos para:
  - Alibaba Cloud (Model Studio / DashScope)
  - Groq Cloud (14 modelos ativos da chave)
  - OpenRouter (Modelos gratuitos e auxiliares)
  - Cerebras Cloud
  - SambaNova Cloud
  - Google Gemini
"""

from __future__ import annotations

import logging
from typing import Literal
import os
from app.core.config import settings

logger = logging.getLogger(__name__)

# ==============================================================================
# CATÁLOGOS CENTRALIZADOS DE MODELOS POR PROVEDOR E ESPECIALIDADE
# ==============================================================================

# A. OpenRouter
# 1. Modelos Gratuitos de Texto / Chat para Inferência
OPENROUTER_FREE_TEXT_MODELS = [
    "poolside/laguna-xs-2.1:free",                 # 112B
    "cohere/north-mini-code:free",                  # 115B
    "minimax/minimax-m3:free",                      # 5.77T
    # "minimax/minimax-m2.7:free": desativado por erro 404 em 2026-09-25 (movido para tier pago na OpenRouter)
    "google/gemma-4-26b-a4b-it:free",
    "google/gemma-4-31b-it:free",
    "nvidia/nemotron-3-ultra-550b-a55b:free",
    "nvidia/nemotron-3-super-120b-a12b:free",
    "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free",
]

# 2. Modelos Auxiliares (Embeddings, Rerankers, Moderação - NÃO colocar em filas de chat)
OPENROUTER_AUXILIARY_MODELS = {
    "embeddings": [
        "nvidia/nemotron-3-embed-1b:free",
        "nvidia/llama-nemotron-embed-vl-1b-v2:free",
    ],
    "rerankers": [
        "nvidia/llama-nemotron-rerank-vl-1b-v2:free",
    ],
    "safety": [
        "nvidia/nemotron-3.5-content-safety:free",
    ],
}

# B. Groq (Catálogo de modelos ativos da chave - testados via API)
GROQ_TEXT_MODELS = [
    "openai/gpt-oss-120b",           # Ativo, latência ~400ms
    "openai/gpt-oss-20b",            # Ativo, latência ~250ms
    "openai/gpt-oss-safeguard-20b",  # Ativo
    "qwen/qwen3.8-27b",              # Ativo
    "allam-2-7b",                    # Ativo
    # "qwen/qwen3.6-27b": desativado por erro 404 em 2026-09-25 (descontinuado na Groq)
    # "groq/compound": desativado por erro 404 em 2026-09-25
    # "groq/compound-mini": desativado por erro 404 em 2026-09-25
]

GROQ_GUARD_MODELS = [
    "meta-llama/llama-prompt-guard-2-86m",
    "meta-llama/llama-prompt-guard-2-22m",
]

GROQ_AUDIO_MODELS = [
    "canopylabs/orpheus-v1-english",
    "canopylabs/orpheus-arabic-saudi",
    "whisper-large-v3-turbo",
    "whisper-large-v3",
]

# C. Cerebras Cloud
CEREBRAS_MODELS = [
    "qwen-3.8-27b",             # Contexto: 131k, 450 RPM - Confirmado via API
    "gpt-oss-120b",             # Contexto: 131k - Confirmado via API (substituiu gpt-oss-120bProduction desativado por 404 em 2026-09-25)
    # "gemma-4-31bPreview": desativado por erro 404 em 2026-09-25
    # "gpt-oss-120bProduction": desativado por erro 404 em 2026-09-25
]

# D. Alibaba Cloud (Model Studio / DashScope)
DASHSCOPE_MODELS = {
    "classifier_primary": "qwen-plus",                  # Classificador Semântico Principal
    "classifier_secondary": "qwen3.6-plus",             # Fallback Secundário vocab_worker
    "classifier_contingency": "qwen3.6-plus-2026-04-02",# Snapshot de Contingência
    "classifier_fast": "qwen-turbo",                    # Classificação Rápida de Vocabulário
    "quiz_primary": "qwen-max",                         # Gerador de Quizzes e Raciocínio TRI
    "quiz_fallback": "qwen3.7-max",                     # Fallback para Geração de Quizzes
    "quiz_contingency": "qwen3.7-max-2026-05-17",       # Snapshot de Contingência rag_service
    "psychometric_val": "qwen3.8-max",                  # Validação Psicométrica e Calibração TRI
    # "structured_outputs": "qwen2.5-coder": desativado por erro 404 em 2026-09-25 no endpoint OpenAI compatível
    "structured_outputs": "qwen-coder-plus",            # Confirmado na documentação oficial Alibaba Model Studio
}

# E. SambaNova Cloud
SAMBANOVA_MODELS = [
    "DeepSeek-V3.1",
    "DeepSeek-V3.2",
    "Meta-Llama-3.3-70B-Instruct",
    "MiniMax-M2.7",
    "MiniMax-M3",
    "gemma-4-31B-it",
    "gpt-oss-120b",
]


# ==============================================================================
# CADEIAS DE FALLBACK POR TAREFA
# ==============================================================================

# VOCAB_EXTRACTION_CLOUD: Esteira de classificação do vocab_worker
# Prioridade configurável: Groq (ativo) -> Gemini (ativo) -> DashScope -> OpenRouter -> SambaNova -> Cerebras
_CHAIN_VOCAB_EXTRACTION_CLOUD: list[str] = [
    # 1. Groq (Provedor ativo com modelos funcionais e baixa latência)
    f"groq/{GROQ_TEXT_MODELS[0]}",   # openai/gpt-oss-120b
    f"groq/{GROQ_TEXT_MODELS[1]}",   # openai/gpt-oss-20b
    f"groq/{GROQ_TEXT_MODELS[3]}",   # qwen/qwen3.8-27b
    f"groq/{GROQ_TEXT_MODELS[4]}",   # allam-2-7b
    f"groq/{GROQ_TEXT_MODELS[2]}",   # openai/gpt-oss-safeguard-20b

    # 2. Google Gemini (Provedor ativo com suporte multimodal e estruturado)
    "gemini/gemini-2.5-flash",
    "gemini/gemini-3.6-flash",
    "gemini/gemini-2.5-flash-lite",

    # 3. Alibaba Cloud / DashScope (Modelos válidos; atualmente com cota FreeTier esgotada 403, acionados assim que recarregados)
    f"dashscope/{DASHSCOPE_MODELS['classifier_primary']}",
    f"dashscope/{DASHSCOPE_MODELS['classifier_fast']}",
    f"dashscope/{DASHSCOPE_MODELS['quiz_primary']}",
    f"dashscope/{DASHSCOPE_MODELS['structured_outputs']}",

    # 4. OpenRouter Free Endpoints
    f"openrouter/{OPENROUTER_FREE_TEXT_MODELS[4]}",  # google/gemma-4-31b-it:free
    f"openrouter/{OPENROUTER_FREE_TEXT_MODELS[3]}",  # google/gemma-4-26b-a4b-it:free
    f"openrouter/{OPENROUTER_FREE_TEXT_MODELS[0]}",  # poolside/laguna-xs-2.1:free
    f"openrouter/{OPENROUTER_FREE_TEXT_MODELS[1]}",  # cohere/north-mini-code:free

    # 5. SambaNova Cloud
    f"sambanova/{SAMBANOVA_MODELS[1]}",  # DeepSeek-V3.2
    f"sambanova/{SAMBANOVA_MODELS[2]}",  # Meta-Llama-3.3-70B-Instruct

    # 6. Cerebras Cloud
    f"cerebras/{CEREBRAS_MODELS[0]}",   # qwen-3.8-27b
    f"cerebras/{CEREBRAS_MODELS[1]}",   # gpt-oss-120b
]

# FAST: Latência crítica — geração de quiz com prompt < 800 tokens (rag_service).
# Prioriza modelos com resposta sub-segundo e cotas ativas no topo para a PingRace
_CHAIN_FAST: list[str] = [
    # 1. Groq LPU (Baixíssima latência ~200-500ms)
    f"groq/{GROQ_TEXT_MODELS[0]}",   # openai/gpt-oss-120b
    f"groq/{GROQ_TEXT_MODELS[1]}",   # openai/gpt-oss-20b
    f"groq/{GROQ_TEXT_MODELS[4]}",   # allam-2-7b (alta disponibilidade)
    f"groq/{GROQ_TEXT_MODELS[3]}",   # qwen/qwen3.8-27b

    # 2. Google Gemini & Cerebras (Ultrarrápido)
    "gemini/gemini-2.5-flash",
    f"cerebras/{CEREBRAS_MODELS[0]}",   # qwen-3.8-27b

    # 3. SambaNova Cloud
    f"sambanova/{SAMBANOVA_MODELS[1]}",  # DeepSeek-V3.2
    f"sambanova/{SAMBANOVA_MODELS[2]}",  # Meta-Llama-3.3-70B-Instruct

    # 4. OpenRouter Free
    f"openrouter/{OPENROUTER_FREE_TEXT_MODELS[4]}",  # google/gemma-4-31b-it:free
    f"openrouter/{OPENROUTER_FREE_TEXT_MODELS[0]}",  # poolside/laguna-xs-2.1:free

    # 5. DashScope (Model Studio / Alibaba)
    f"dashscope/{DASHSCOPE_MODELS['quiz_primary']}",
    f"dashscope/{DASHSCOPE_MODELS['quiz_fallback']}",
    f"dashscope/{DASHSCOPE_MODELS['psychometric_val']}",
    f"dashscope/{DASHSCOPE_MODELS['quiz_contingency']}",
    f"dashscope/{DASHSCOPE_MODELS['classifier_primary']}",
]

# LONG_CONTEXT: Prompts extensos (> 30k tokens)
_CHAIN_LONG_CONTEXT: list[str] = [
    "gemini/gemini-2.5-flash",
    f"dashscope/{DASHSCOPE_MODELS['quiz_primary']}",
    f"dashscope/{DASHSCOPE_MODELS['classifier_primary']}",
    f"openrouter/{OPENROUTER_FREE_TEXT_MODELS[2]}",  # minimax/minimax-m3:free
    f"openrouter/{OPENROUTER_FREE_TEXT_MODELS[6]}",  # nvidia/nemotron-3-super-120b-a12b:free
]

# LOCAL_ONLY: Totalmente offline via Ollama
_CHAIN_LOCAL_ONLY: list[str] = [
    "ollama/qwen2.5:1.5b-instruct",
    "ollama/qwen2.5:1.5b",
    "ollama/llama3.2:1b",
]

TaskType = Literal["fast", "long_context", "local_only", "balanced", "vocab_extraction_cloud", "thematic_practice"]


class ModelRouter:
    """
    Fornece as listas de modelos (fallback chain) de acordo com a task.
    """

    @classmethod
    def get_chain_for_task(
        cls,
        task_type: TaskType = "fast",
        context_length: int = 0,
    ) -> list[str]:
        """Retorna a cadeia apropriada, forçando contexto longo se necessário."""
        if context_length > 30_000:
            logger.warning(
                "[ModelRouter] Contexto longo detectado (%d tokens). "
                "Usando cadeia LONG_CONTEXT.",
                context_length,
            )
            return list(_CHAIN_LONG_CONTEXT)

        # Permite override dinâmico da cadeia de extração via variável de ambiente
        custom_vocab_chain = os.getenv("VOCAB_EXTRACTION_CHAIN")
        if custom_vocab_chain:
            vocab_chain = [m.strip() for m in custom_vocab_chain.split(",") if m.strip()]
        else:
            vocab_chain = _CHAIN_VOCAB_EXTRACTION_CLOUD

        chain_map: dict[str, list[str]] = {
            "fast":                   _CHAIN_FAST,
            "thematic_practice":      _CHAIN_FAST,
            "long_context":           _CHAIN_LONG_CONTEXT,
            "local_only":             _CHAIN_LOCAL_ONLY,
            "balanced":               list(settings.FALLBACK_CHAIN),
            "vocab_extraction_cloud": vocab_chain,
        }

        chain = chain_map.get(task_type, list(settings.FALLBACK_CHAIN))
        logger.debug(
            "[ModelRouter] Cadeia selecionada para task_type='%s' (%d modelos): %s",
            task_type,
            len(chain),
            chain,
        )
        return list(chain)  # retorna cópia para evitar mutação acidental
