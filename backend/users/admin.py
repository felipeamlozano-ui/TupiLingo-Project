"""
Registros do Django Admin para o app users.

Atualizado para a nova arquitetura da Jornada Histórica:
- Removida referência a tupi_level (campo legado removido).
- Adicionados variante_ativa, xp_total, Achievement e UserLesson.
"""

from django.contrib import admin

from .models import (
    Achievement,
    UserAchievement,
    UserLesson,
    UserProfile,
    VocabularyProgress,
)


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = (
        "name",
        "email",
        "variante_ativa",
        "xp_total",
        "source",
        "created_at",
    )
    list_filter = ("variante_ativa", "source")
    search_fields = ("name", "email", "supabase_uid")
    readonly_fields = ("supabase_uid", "created_at", "updated_at")
    ordering = ("-created_at",)

    fieldsets = (
        (
            "Identificação",
            {
                "fields": ("supabase_uid", "email", "name"),
            },
        ),
        (
            "Jornada de Aprendizado",
            {
                "fields": ("variante_ativa", "xp_total", "source"),
            },
        ),
        (
            "Timestamps",
            {
                "fields": ("created_at", "updated_at"),
                "classes": ("collapse",),
            },
        ),
    )


@admin.register(Achievement)
class AchievementAdmin(admin.ModelAdmin):
    list_display = ("icone", "nome", "tipo", "xp_necessario", "codigo")
    list_filter = ("tipo",)
    search_fields = ("nome", "codigo")
    ordering = ("xp_necessario", "nome")


@admin.register(UserAchievement)
class UserAchievementAdmin(admin.ModelAdmin):
    list_display = ("user", "achievement", "conquistada_em")
    list_filter = ("achievement__tipo",)
    search_fields = ("user__name", "user__email", "achievement__nome")
    ordering = ("-conquistada_em",)


@admin.register(UserLesson)
class UserLessonAdmin(admin.ModelAdmin):
    list_display = (
        "usuario",
        "licao",
        "status",
        "accuracy",
        "earned_xp",
        "concluida_em",
    )
    list_filter = ("status",)
    search_fields = ("usuario__name", "licao__titulo")
    ordering = ("-concluida_em",)


@admin.register(VocabularyProgress)
class VocabularyProgressAdmin(admin.ModelAdmin):
    list_display = ("usuario", "item", "repetitions", "ease_factor", "next_review")
    search_fields = ("usuario__name", "item__palavra_tupi")
    ordering = ("next_review",)
