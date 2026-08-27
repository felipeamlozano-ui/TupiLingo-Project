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
    ENABLE_OTEL: bool = True
    ENABLE_METRICS: bool = True

    # Supabase (used elsewhere, keeping decoupled if possible, but safe to list)
    SUPABASE_URL: str = ""
    SUPABASE_SERVICE_ROLE_KEY: str = ""

    # AI API Keys
    GEMINI_API_KEY: Optional[str] = None
    GROQ_API_KEY: Optional[str] = None
    CEREBRAS_API_KEY: Optional[str] = None
    OPENAI_API_KEY: Optional[str] = None
    
    # Base URLs
    OLLAMA_BASE_URL: str = "http://localhost:11434/v1"
    
    # RAG Config
    RAG_TOP_K: int = 5
    DDG_TIMEOUT: int = 5
    
    # Fallback Chain Configuration (can be overridden via env)
    FALLBACK_CHAIN: List[str] = Field(
        default=[
            "gemini/gemini-2.5-flash",
            "cerebras/gpt-oss-120b",
            "openai/gpt-4o-mini",
            "groq/qwen/qwen3.6-27b"
        ]
    )

    # Redis Cache
    REDIS_URL: str = "redis://localhost:6379/0"
    PROMPT_CACHE_TTL: int = 3600 * 24 * 7 # 1 week

settings = Settings()
