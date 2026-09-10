"""
URLs da API de Trilha — Jornada Histórica do TupiLingo.

Endpoints:
- GET /api/v1/trilha/variantes/               → lista variantes disponíveis
- GET /api/v1/trilha/<variante_id>/           → dados da trilha daquela variante
- GET /api/v1/trilha/<variante_id>/capitulos/ → capítulos + lições (mapa interativo)
- GET /api/v1/trilha/licao/<licao_id>/        → detalhes de uma lição (StoryBlocks + Exercícios)
- POST /api/v1/trilha/licao/<licao_id>/concluir/ → conclui uma lição e calcula XP
- POST /api/v1/exercicios/verificar/          → verifica resposta de exercício com unaccent/levenshtein
"""

from django.urls import path
from . import views
from . import admin_views

urlpatterns = [
    # ── Variantes ─────────────────────────────────────────────────────────────
    path(
        'trilha/variantes/',
        views.listar_variantes,
        name='listar_variantes',
    ),

    # ── Trilha / Mapa ─────────────────────────────────────────────────────────
    path(
        'trilha/regioes/',
        views.listar_regioes_mapa,
        name='listar_regioes_mapa',
    ),
    path(
        'trilha/<int:variante_id>/capitulos/',
        views.listar_capitulos_mapa,
        name='listar_capitulos_mapa',
    ),

    # ── Lição ─────────────────────────────────────────────────────────────────
    path(
        'trilha/licao/<int:licao_id>/',
        views.detalhe_licao,
        name='detalhe_licao',
    ),
    path(
        'trilha/licao/<int:licao_id>/concluir/',
        views.concluir_licao,
        name='concluir_licao',
    ),
    path(
        'trilha/capitulo/<int:capitulo_id>/bau/<int:milestone_index>/coletar/',
        views.coletar_bau,
        name='coletar_bau',
    ),
    path(
        'trilha/capitulo/<int:capitulo_id>/bau/coletar/',
        views.coletar_bau,
        {'milestone_index': 1},
        name='coletar_bau_default',
    ),

    # ── Validação de Exercícios ───────────────────────────────────────────────
    path(
        'exercicios/verificar/',
        views.verificar_resposta,
        name='verificar_resposta',
    ),

    # ── Rotas Admin In-App ────────────────────────────────────────────────────
    path(
        'admin/trilha/dados/',
        admin_views.admin_listar_dados,
        name='admin_listar_dados',
    ),
    path(
        'admin/trilha/capitulos/',
        admin_views.admin_criar_capitulo,
        name='admin_criar_capitulo',
    ),
    path(
        'admin/trilha/capitulos/<int:capitulo_id>/',
        admin_views.admin_gerenciar_capitulo,
        name='admin_gerenciar_capitulo',
    ),
    path(
        'admin/trilha/licoes/',
        admin_views.admin_criar_licao,
        name='admin_criar_licao',
    ),
    path(
        'admin/trilha/licoes/<int:licao_id>/',
        admin_views.admin_gerenciar_licao,
        name='admin_gerenciar_licao',
    ),
    path(
        'admin/trilha/exercicios/',
        admin_views.admin_criar_exercicio,
        name='admin_criar_exercicio',
    ),
    path(
        'admin/trilha/exercicios/<int:exercicio_id>/',
        admin_views.admin_gerenciar_exercicio,
        name='admin_gerenciar_exercicio',
    ),
]

