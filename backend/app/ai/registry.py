from typing import TYPE_CHECKING

from app.ai.exceptions import ProviderNotFoundError

if TYPE_CHECKING:
    from app.ai.providers.base import BaseProvider

class ProviderRegistry:
    """Registry pattern para gerenciar provedores de IA dinamicamente."""
    _providers: dict[str, 'BaseProvider'] = {}

    @classmethod
    def register(cls, name: str, provider_instance: 'BaseProvider'):
        """Registra uma instância de provedor."""
        cls._providers[name.lower()] = provider_instance

    @classmethod
    def get_provider(cls, name: str) -> 'BaseProvider':
        """Retorna uma instância de provedor pelo nome."""
        name = name.lower()
        if name not in cls._providers:
            raise ProviderNotFoundError(f"Provedor '{name}' não registrado ou desativado.")
        return cls._providers[name]

    @classmethod
    def clear(cls):
        """Limpa todos os provedores."""
        cls._providers.clear()

registry = ProviderRegistry()

# Importar os provedores no final para garantir que o registry seja povoado
