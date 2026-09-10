"""
Django Admin para o app Trilha.

O painel administrativo serve como o "Construtor de Trilhas".
O administrador pode criar toda a jornada narrativa sem escrever código:
- Variantes Tupi
- Trilhas Históricas
- Capítulos (com cenário e cor de tema)
- Lições (com posição no mapa)
- StoryBlocks (montagem LEGO da narrativa)
- Exercícios (múltipla escolha, completar, associação)
- Vocabulário

Cada objeto maior (Capítulo, Lição) usa Inlines para exibir seus filhos
diretamente na página de edição — facilitando a construção da trilha de forma fluida.
"""

from django.contrib import admin
from django.utils.html import format_html

from .models import (
    VarianteTupi,
    TrilhaHistorica,
    Scenario,
    Capitulo,
    Licao,
    StoryBlock,
    VocabularyItem,
    Exercicio,
    ExercicioEscolha,
    ExercicioCompletar,
    ExercicioAssociacao,
)


# ─── Inlines ─────────────────────────────────────────────────────────────────

class StoryBlockInline(admin.TabularInline):
    model = StoryBlock
    extra = 1
    fields = ('ordem', 'tipo', 'titulo', 'conteudo', 'midia', 'xp_bonus')
    ordering = ('ordem',)
    show_change_link = True


class ExercicioInline(admin.TabularInline):
    model = Exercicio
    extra = 0
    fields = ('ordem', 'tipo', 'enunciado', 'dificuldade', 'pontos_base')
    show_change_link = True


class ExercicioEscolhaInline(admin.TabularInline):
    model = ExercicioEscolha
    extra = 0
    fields = ('ordem', 'enunciado', 'opcoes', 'resposta_correta', 'dificuldade', 'pontos_base')
    show_change_link = True


class ExercicioCompletarInline(admin.TabularInline):
    model = ExercicioCompletar
    extra = 0
    fields = ('ordem', 'enunciado', 'texto_com_lacunas', 'respostas_corretas', 'tolerancia_levenshtein', 'dificuldade', 'pontos_base')
    show_change_link = True


class ExercicioAssociacaoInline(admin.TabularInline):
    model = ExercicioAssociacao
    extra = 0
    fields = ('ordem', 'enunciado', 'coluna_esquerda', 'coluna_direita', 'associacao_correta', 'dificuldade', 'pontos_base')
    show_change_link = True


class VocabularyItemInline(admin.TabularInline):
    model = VocabularyItem
    extra = 1
    fields = ('ordem', 'palavra_tupi', 'traducao_pt', 'transliteracao', 'audio', 'exemplo_tupi')
    ordering = ('ordem',)


class LicaoInline(admin.TabularInline):
    model = Licao
    extra = 0
    fields = ('numero', 'titulo', 'descricao', 'xp_base', 'pos_x', 'pos_y', 'publicada')
    ordering = ('numero',)
    show_change_link = True


class CapituloInline(admin.TabularInline):
    model = Capitulo
    extra = 0
    fields = ('numero', 'titulo', 'scenario', 'publicado')
    ordering = ('numero',)
    show_change_link = True


# ─── VarianteTupi ─────────────────────────────────────────────────────────────

@admin.register(VarianteTupi)
class VarianteTupiAdmin(admin.ModelAdmin):
    list_display = ('icone', 'nome', 'codigo', 'ativo', 'ordem')
    list_editable = ('ativo', 'ordem')
    search_fields = ('nome', 'codigo')
    ordering = ('ordem',)


# ─── TrilhaHistorica ──────────────────────────────────────────────────────────

@admin.register(TrilhaHistorica)
class TrilhaHistoricaAdmin(admin.ModelAdmin):
    list_display = ('titulo', 'variante', 'publicada', 'updated_at')
    list_filter = ('publicada', 'variante')
    inlines = [CapituloInline]
    readonly_fields = ('created_at', 'updated_at')


# ─── Scenario ─────────────────────────────────────────────────────────────────

@admin.register(Scenario)
class ScenarioAdmin(admin.ModelAdmin):
    list_display = ('nome', 'preview_palette')
    search_fields = ('nome',)

    def preview_palette(self, obj):
        primary = obj.palette.get('primary', '#cccccc')
        secondary = obj.palette.get('secondary', '#aaaaaa')
        return format_html(
            '<span style="background:{}; width:20px; height:20px; display:inline-block; border-radius:4px; margin-right:4px;"></span>'
            '<span style="background:{}; width:20px; height:20px; display:inline-block; border-radius:4px;"></span>',
            primary, secondary,
        )
    preview_palette.short_description = 'Paleta'


# ─── Capitulo ─────────────────────────────────────────────────────────────────

@admin.register(Capitulo)
class CapituloAdmin(admin.ModelAdmin):
    list_display = ('__str__', 'trilha', 'numero', 'scenario', 'publicado')
    list_filter = ('trilha', 'publicado')
    ordering = ('trilha', 'numero')
    inlines = [LicaoInline]

    fieldsets = (
        ('Identificação', {
            'fields': ('trilha', 'numero', 'titulo', 'descricao'),
        }),
        ('Visual e Cenário', {
            'fields': ('scenario', 'publicado'),
        }),
    )


# ─── Licao ────────────────────────────────────────────────────────────────────

@admin.register(Licao)
class LicaoAdmin(admin.ModelAdmin):
    list_display = ('titulo', 'capitulo', 'numero', 'xp_base', 'publicada', 'pos_display')
    list_filter = ('capitulo__trilha', 'publicada')
    ordering = ('capitulo', 'numero')
    search_fields = ('titulo',)
    inlines = [StoryBlockInline, VocabularyItemInline, ExercicioInline, ExercicioEscolhaInline, ExercicioCompletarInline, ExercicioAssociacaoInline]

    fieldsets = (
        ('Identificação', {
            'fields': ('capitulo', 'numero', 'titulo', 'descricao'),
        }),
        ('Gamificação', {
            'fields': ('xp_base', 'publicada'),
        }),
        ('Posição no Mapa Interativo', {
            'description': 'Define onde este ponto de lição aparecerá no mapa (0-100%, relativo ao cenário).',
            'fields': ('pos_x', 'pos_y'),
            'classes': ('collapse',),
        }),
    )

    def pos_display(self, obj):
        return f"X: {obj.pos_x:.0f}%, Y: {obj.pos_y:.0f}%"
    pos_display.short_description = 'Posição no Mapa'


# ─── StoryBlock ───────────────────────────────────────────────────────────────

@admin.register(StoryBlock)
class StoryBlockAdmin(admin.ModelAdmin):
    list_display = ('licao', 'ordem', 'tipo', 'titulo', 'xp_bonus')
    list_filter = ('tipo', 'licao__capitulo__trilha')
    ordering = ('licao', 'ordem')
    search_fields = ('titulo', 'conteudo')


# ─── VocabularyItem ───────────────────────────────────────────────────────────

@admin.register(VocabularyItem)
class VocabularyItemAdmin(admin.ModelAdmin):
    list_display = ('palavra_tupi', 'traducao_pt', 'transliteracao', 'licao')
    search_fields = ('palavra_tupi', 'traducao_pt')
    list_filter = ('licao__capitulo__trilha',)
    ordering = ('licao', 'ordem')


# ─── Exercícios ───────────────────────────────────────────────────────────────

@admin.register(ExercicioEscolha)
class ExercicioEscolhaAdmin(admin.ModelAdmin):
    list_display = ('enunciado_curto', 'licao', 'dificuldade', 'pontos_base')
    list_filter = ('dificuldade', 'licao__capitulo__trilha')
    search_fields = ('enunciado',)

    def enunciado_curto(self, obj):
        return obj.enunciado[:60] + '...' if len(obj.enunciado) > 60 else obj.enunciado
    enunciado_curto.short_description = 'Enunciado'


@admin.register(ExercicioCompletar)
class ExercicioCompletarAdmin(admin.ModelAdmin):
    list_display = ('enunciado_curto', 'licao', 'dificuldade', 'tolerancia_levenshtein', 'pontos_base')
    list_filter = ('dificuldade', 'licao__capitulo__trilha')
    search_fields = ('enunciado', 'texto_com_lacunas')
    help_text_extra = "Use ___ para marcar lacunas no campo 'texto_com_lacunas'."

    def enunciado_curto(self, obj):
        return obj.enunciado[:60] + '...' if len(obj.enunciado) > 60 else obj.enunciado
    enunciado_curto.short_description = 'Enunciado'


@admin.register(ExercicioAssociacao)
class ExercicioAssociacaoAdmin(admin.ModelAdmin):
    list_display = ('enunciado_curto', 'licao', 'dificuldade', 'pontos_base')
    list_filter = ('dificuldade', 'licao__capitulo__trilha')
    search_fields = ('enunciado',)

    def enunciado_curto(self, obj):
        return obj.enunciado[:60] + '...' if len(obj.enunciado) > 60 else obj.enunciado
    enunciado_curto.short_description = 'Enunciado'


@admin.register(Exercicio)
class ExercicioAdmin(admin.ModelAdmin):
    list_display = ('enunciado_curto', 'licao', 'tipo', 'dificuldade', 'pontos_base', 'ordem')
    list_filter = ('tipo', 'dificuldade', 'licao__capitulo__trilha')
    search_fields = ('enunciado', 'explicacao')
    ordering = ('licao', 'ordem')

    def enunciado_curto(self, obj):
        return obj.enunciado[:60] + '...' if len(obj.enunciado) > 60 else obj.enunciado
    enunciado_curto.short_description = 'Enunciado'
