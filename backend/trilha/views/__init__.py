"""
Pacote de views da Trilha — Jornada Histórica do TupiLingo.
Refatorado de um monólito de 850 linhas para módulos de responsabilidade única (Clean Architecture).
"""

from .common import (
    _get_user,
    _get_or_create_user_lesson,
    _is_celery_broker_reachable,
)
from .trail_views import (
    listar_variantes,
    listar_capitulos_mapa,
    listar_regioes_mapa,
)
from .lesson_views import (
    detalhe_licao,
    concluir_licao,
    _recalibrar_nivel,
    _desbloquear_proxima_licao,
)
from .reward_views import (
    coletar_bau,
)
from .exercise_views import (
    verificar_resposta,
)

__all__ = [
    '_get_user',
    '_get_or_create_user_lesson',
    '_is_celery_broker_reachable',
    'listar_variantes',
    'listar_capitulos_mapa',
    'listar_regioes_mapa',
    'detalhe_licao',
    'concluir_licao',
    '_recalibrar_nivel',
    '_desbloquear_proxima_licao',
    'coletar_bau',
    'verificar_resposta',
]
