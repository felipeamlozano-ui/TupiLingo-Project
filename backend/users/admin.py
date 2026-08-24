"""
Registros do Django Admin para o app users.

DJANGO-002: UserProfile registrado com campos relevantes, filtros e busca.
"""

from django.contrib import admin
from .models import UserProfile


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ('name', 'email', 'tupi_level', 'source', 'created_at', 'updated_at')
    list_filter = ('tupi_level', 'source')
    search_fields = ('name', 'email', 'supabase_uid')
    readonly_fields = ('supabase_uid', 'created_at', 'updated_at')
    ordering = ('-created_at',)

    fieldsets = (
        ('Identificação', {
            'fields': ('supabase_uid', 'email', 'name'),
        }),
        ('Perfil de Aprendizado', {
            'fields': ('tupi_level', 'source'),
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',),
        }),
    )
