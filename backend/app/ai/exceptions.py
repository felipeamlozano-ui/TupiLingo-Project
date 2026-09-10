class AIProviderError(Exception):
    """Base exception for all AI provider errors."""
    pass

class RateLimitError(AIProviderError):
    """Raised when a provider's rate limit is exceeded."""
    pass

class TimeoutError(AIProviderError):
    """Raised when a provider times out."""
    pass

class AuthenticationError(AIProviderError):
    """Raised when authentication fails (invalid API key)."""
    pass

class ContextWindowExceededError(AIProviderError):
    """Raised when the prompt exceeds the model's context window."""
    pass

class StructuredOutputError(AIProviderError):
    """Raised when the model fails to return the requested structured output (JSON)."""
    pass

class NetworkError(AIProviderError):
    """Raised on connection issues."""
    pass

class ServiceUnavailableError(AIProviderError):
    """Raised when the provider is down (503/500)."""
    pass

class ProviderNotFoundError(AIProviderError):
    """Raised when a requested provider is not registered."""
    pass
