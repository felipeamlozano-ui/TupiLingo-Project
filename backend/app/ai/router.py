"""
Define as cadeias de fallback de modelos LLM para cada tipo de tarefa.
Prioriza fallbacks rápidos em vez de retries com backoff.
Inclui uma vasta gama de provedores gratuitos de alta velocidade e alta taxa de tokens (Groq, Gemini, OpenRouter Free).
"""

from __future__ import annotations

import logging
from typing import Literal

from app.core.config import settings

logger = logging.getLogger(__name__)

# Cadeias de modelos

# FAST: latência crítica — geração de quiz com prompt < 800 tokens.
# Modelos com excelente tempo de resposta (<1s) e tiers gratuitos generosos.
_CHAIN_FAST: list[str] = [
    # 1. Provedores ultrarrápidos dedicados (LPU / Groq)
    "groq/qwen/qwen3.8-27b",
    "groq/groq/compound",
    "groq/groq/compound-mini",
    "groq/openai/gpt-oss-120b",
    "groq/openai/gpt-oss-20b",
    "groq/allam-2-7b",

    # 2. Cohere API Nativa
    "cohere/command-r-08-2024",
    "cohere/command-r-plus-08-2024",
    "cohere/c4ai-aya-expanse-32b",
    "cohere/command-nightly",

    # 3. OpenRouter Free Endpoints testados e ativos (sem custo, na nuvem)
    "openrouter/minimax/minimax-m3:free",
    "openrouter/minimax/minimax-m2.7:free",
    "openrouter/nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free",
    "openrouter/nvidia/nemotron-3.5-lightning:free",
    "openrouter/nvidia/nemotron-3-super-120b-a12b:free",
    "openrouter/poolside/laguna-s-2.1:free",
    "openrouter/poolside/laguna-xs-2.1:free",
    "openrouter/liquid/lfm-2.5-2.6b:free",
    "openrouter/inclusionai/ling-3.0-flash-fin:free",
    "openrouter/cohere/north-mini-code:free",
    "openrouter/dots-studio/dots-3-note-preview:free",

    # 4. Fallback Google GenAI
    "gemini/gemini-2.5-flash",
]

# LONG_CONTEXT: para prompts > 30 k tokens (não usada no caminho crítico do quiz).
_CHAIN_LONG_CONTEXT: list[str] = [
    "cohere/command-r-08-2024",
    "cohere/command-r-plus-08-2024",
    "openrouter/minimax/minimax-m3:free",
    "openrouter/minimax/minimax-m2.7:free",
    "openrouter/nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free",
    "openrouter/nvidia/nemotron-3-super-120b-a12b:free",
    "gemini/gemini-2.5-flash",
]

# LOCAL_ONLY: fallback totalmente offline via Ollama.
_CHAIN_LOCAL_ONLY: list[str] = [
    "ollama/qwen2.5:1.5b-instruct",
    "ollama/qwen2.5:1.5b",
    "ollama/llama3.2:1b",
]

# VOCAB_EXTRACTION_CLOUD: Cadeia Multi-Provider para extração/classificação via nuvem
_CHAIN_VOCAB_EXTRACTION_CLOUD: list[str] = [
    # 1. Groq (limites de rate por modelo independente)
    "groq/qwen/qwen3.8-27b",
    "groq/groq/compound",
    "groq/groq/compound-mini",
    "groq/openai/gpt-oss-120b",
    "groq/openai/gpt-oss-20b",
    "groq/allam-2-7b",

    # 2. Cohere API Nativa
    "cohere/command-r-08-2024",
    "cohere/command-r-plus-08-2024",
    "cohere/c4ai-aya-expanse-32b",
    "cohere/command-nightly",

    # 3. OpenRouter Free Endpoints
    "openrouter/minimax/minimax-m3:free",
    "openrouter/minimax/minimax-m2.7:free",
    "openrouter/nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free",
    "openrouter/nvidia/nemotron-3.5-lightning:free",
    "openrouter/nvidia/nemotron-3-super-120b-a12b:free",
    "openrouter/poolside/laguna-s-2.1:free",
    "openrouter/poolside/laguna-xs-2.1:free",
    "openrouter/liquid/lfm-2.5-2.6b:free",
    "openrouter/inclusionai/ling-3.0-flash-fin:free",
    "openrouter/cohere/north-mini-code:free",
    "openrouter/dots-studio/dots-3-note-preview:free",
    "gemini/gemini-2.5-flash",
]

TaskType = Literal["fast", "long_context", "local_only", "balanced", "vocab_extraction_cloud"]


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

        chain_map: dict[str, list[str]] = {
            "fast":             _CHAIN_FAST,
            "long_context":     _CHAIN_LONG_CONTEXT,
            "local_only":       _CHAIN_LOCAL_ONLY,
            "balanced":         list(settings.FALLBACK_CHAIN),
            "vocab_extraction_cloud": _CHAIN_VOCAB_EXTRACTION_CLOUD,
        }

        chain = chain_map.get(task_type, list(settings.FALLBACK_CHAIN))
        logger.debug(
            "[ModelRouter] Cadeia selecionada para task_type='%s' (%d modelos): %s",
            task_type,
            len(chain),
            chain,
        )
        return list(chain)  # retorna cópia para evitar mutação acidental
