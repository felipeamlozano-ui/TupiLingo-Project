class AIProviderError(Exception):
    """Base exception for all AI provider errors."""

class RateLimitError(AIProviderError):
    """Raised when a provider's rate limit is exceeded."""

class TimeoutError(AIProviderError):
    """Raised when a provider times out."""

class AuthenticationError(AIProviderError):
    """Raised when authentication fails (invalid API key)."""

class ContextWindowExceededError(AIProviderError):
    """Raised when the prompt exceeds the model's context window."""

class StructuredOutputError(AIProviderError):
    """Raised when the model fails to return the requested structured output (JSON)."""

class NetworkError(AIProviderError):
    """Raised on connection issues."""

class ServiceUnavailableError(AIProviderError):
    """Raised when the provider is down (503/500)."""

class ProviderNotFoundError(AIProviderError):
    """Raised when a requested provider is not registered."""
