class AIProviderError(Exception):
    """Base exception for all AI provider errors."""
    pass

class TransientModelError(AIProviderError):
    """Erro transitório (429, 500, 503, timeout, conexão) sujeito a cooldown curto."""
    pass

class FatalModelError(AIProviderError):
    """Erro fatal (401, 402, 403, 404) exigindo desativação imediata do modelo por 24h."""
    pass

class RateLimitError(TransientModelError):
    """Raised when a provider's rate limit is exceeded (HTTP 429)."""
    pass

class TimeoutError(TransientModelError):
    """Raised when a provider times out."""
    pass

class NetworkError(TransientModelError):
    """Raised on connection issues."""
    pass

class ServiceUnavailableError(TransientModelError):
    """Raised when the provider is down (HTTP 500/502/503)."""
    pass

class AuthenticationError(FatalModelError):
    """Raised when authentication fails (invalid API key / HTTP 401)."""
    pass

class ModelNotFoundError(FatalModelError):
    """Raised when model does not exist or endpoint is dead (HTTP 404)."""
    pass

class QuotaExhaustedError(FatalModelError):
    """Raised when quota/credits are completely exhausted (HTTP 402 / 403)."""
    pass

class ContextWindowExceededError(FatalModelError):
    """Raised when the prompt exceeds the model's context window."""
    pass

class StructuredOutputError(AIProviderError):
    """Raised when the model fails to return the requested structured output (JSON)."""
    pass

class ProviderNotFoundError(FatalModelError):
    """Raised when a requested provider is not registered."""
    pass
