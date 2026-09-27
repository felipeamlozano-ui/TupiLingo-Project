import sys
sys.path.insert(0, ".")
from app.ai.registry import registry
from app.ai.exceptions import FatalModelError, QuotaExhaustedError

provider = registry.get_provider("sambanova")
try:
    provider.client.chat.completions.create(
        model="Meta-Llama-3.3-70B-Instruct",
        messages=[{"role": "user", "content": "ping"}],
        max_tokens=1,
        timeout=5.0
    )
    print("Sucesso inesperado")
except Exception as exc:
    print(f"Exceção original: {type(exc)} -> {exc}")
    mapped = provider._map_exception(exc)
    print(f"Exceção mapeada: {type(mapped)} -> {mapped}")
    print(f"É FatalModelError?: {isinstance(mapped, FatalModelError)}")
