from app.core.config import settings
def initialize_providers():
    """
    Inicializa e registra os provedores de IA habilitados.
    Executado no boot da aplicação.
    """
    from app.ai.registry import registry

    if settings.ENABLE_GROQ:
        try:
            from app.ai.providers.groq import GroqProvider
            registry.register("groq", GroqProvider())
        except Exception as e:
            print(f"Aviso: Não foi possível inicializar Groq: {e}")

    if settings.ENABLE_GEMINI:
        try:
            from app.ai.providers.gemini import GeminiProvider
            registry.register("gemini", GeminiProvider())
        except Exception as e:
            print(f"Aviso: Não foi possível inicializar Gemini: {e}")

    if settings.ENABLE_CEREBRAS:
        try:
            from app.ai.providers.cerebras import CerebrasProvider
            registry.register("cerebras", CerebrasProvider())
        except Exception as e:
            print(f"Aviso: Não foi possível inicializar Cerebras: {e}")

    if settings.ENABLE_OPENAI:
        try:
            from app.ai.providers.openai import OpenAIProvider
            registry.register("openai", OpenAIProvider())
        except Exception as e:
            print(f"Aviso: Não foi possível inicializar OpenAI: {e}")

    if settings.ENABLE_DASHSCOPE:
        try:
            from app.ai.providers.dashscope import DashScopeProvider
            registry.register("dashscope", DashScopeProvider())
        except Exception as e:
            print(f"Aviso: Não foi possível inicializar DashScope: {e}")

    if settings.ENABLE_SAMBANOVA:
        try:
            from app.ai.providers.sambanova import SambaNovaProvider
            registry.register("sambanova", SambaNovaProvider())
        except Exception as e:
            print(f"Aviso: Não foi possível inicializar SambaNova: {e}")

    if settings.ENABLE_OLLAMA:
        try:
            from app.ai.providers.ollama import OllamaProvider
            registry.register("ollama", OllamaProvider())
        except Exception as e:
            print(f"Aviso: Não foi possível inicializar Ollama: {e}")



# Executa ao importar
initialize_providers()
