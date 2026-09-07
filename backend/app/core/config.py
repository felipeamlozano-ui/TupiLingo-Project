from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field
from typing import List, Optional

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file='.env', env_file_encoding='utf-8', extra='ignore')

    # Django Settings (Feature flags override)
    DEBUG: bool = True
    PRODUCTION: bool = False
    
    # Feature Flags
    ENABLE_RAG: bool = True
    ENABLE_PROMPT_CACHE: bool = True
    ENABLE_CELERY: bool = True
    ENABLE_CEREBRAS: bool = True
    ENABLE_GROQ: bool = True
    ENABLE_GEMINI: bool = True
    ENABLE_OLLAMA: bool = True
    ENABLE_OPENAI: bool = True
    ENABLE_DASHSCOPE: bool = True
    ENABLE_SAMBANOVA: bool = True
    ENABLE_OPENROUTER: bool = True
    ENABLE_OTEL: bool = True
    ENABLE_METRICS: bool = True
    # RFC v3.0: Engine Heurística Determinística
    # true  → usa RPC Supabase + LLM para redação (prod)
    # false → usa pipeline legado GraphRAG (rollback imediato)
    USE_SUPABASE_QUIZ_ENGINE: bool = True
    # TTL do cache de quiz gerado pela engine hírida (padrão: 24h)
    QUIZ_CACHE_TTL: int = 3600 * 24

    # Supabase (used elsewhere, keeping decoupled if possible, but safe to list)
    SUPABASE_URL: str = ""
    SUPABASE_SERVICE_ROLE_KEY: str = ""

    # AI API Keys
    GEMINI_API_KEY: Optional[str] = None
    GROQ_API_KEY: Optional[str] = None
    CEREBRAS_API_KEY: Optional[str] = None
    OPENAI_API_KEY: Optional[str] = None
    DASHSCOPE_API_KEY: Optional[str] = None
    SAMBANOVA_API_KEY: Optional[str] = None
    OPENROUTER_API_KEY: Optional[str] = None
    COHERE_API_KEY: Optional[str] = None
    
    # Base URLs
    OLLAMA_BASE_URL: str = "http://localhost:11434/v1"
    DASHSCOPE_BASE_URL: str = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
    SAMBANOVA_BASE_URL: str = "https://api.sambanova.ai/v1"
    CEREBRAS_BASE_URL: str = "https://api.cerebras.ai/v1"
    
    # RAG Config
    RAG_TOP_K: int = 5
    DDG_TIMEOUT: int = 5
    
    # Fallback Chain Configuration (can be overridden via env)
    FALLBACK_CHAIN: List[str] = Field(
        default=[
            "groq/openai/gpt-oss-20b",
            "cerebras/llama3.1-8b",
            "groq/openai/gpt-oss-120b",
            "gemini/gemini-2.5-flash",
            "openai/gpt-4o-mini",
        ]
    )

    # Redis Cache
    REDIS_URL: str = "redis://localhost:6379/0"
    PROMPT_CACHE_TTL: int = 3600 * 24 * 7 # 1 week

settings = Settings()
