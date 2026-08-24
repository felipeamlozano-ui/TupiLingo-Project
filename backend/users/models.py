"""
Model UserProfile — vincula usuários do Supabase Auth ao banco Django.

Corrigido pela Auditoria Técnica V3.0:
- DB-001: CharField(max_length=255) → UUIDField para supabase_uid
- DB-002: email sem unique → unique=True + db_index=True
- DB-003: tupi_level sem choices → TextChoices + validação
- DB-004: campo updated_at adicionado
"""

import uuid
from django.db import models


class TupiLevelChoices(models.TextChoices):
    """Valores permitidos para o nível de Tupi do usuário."""
    NENHUM = 'nenhum', 'Sem conhecimento'
    INICIANTE = 'iniciante', 'Iniciante'
    INTERMEDIARIO = 'intermediario', 'Intermediário'
    AVANCADO = 'avancado', 'Avançado'
    # Níveis numéricos pós-teste (1-10) são gerenciados pela view
    N1 = '1', 'Nível 1'
    N2 = '2', 'Nível 2'
    N3 = '3', 'Nível 3'
    N4 = '4', 'Nível 4'
    N5 = '5', 'Nível 5'
    N6 = '6', 'Nível 6'
    N7 = '7', 'Nível 7'
    N8 = '8', 'Nível 8'
    N9 = '9', 'Nível 9'
    N10 = '10', 'Nível 10'


class SourceChoices(models.TextChoices):
    """Como o usuário conheceu o app."""
    REDES_SOCIAIS = 'redes_sociais', 'Redes Sociais'
    INDICACAO = 'indicacao', 'Indicação de amigo'
    ESCOLA = 'escola', 'Escola / Universidade'
    PESQUISA = 'pesquisa', 'Pesquisa na internet'
    OUTRO = 'outro', 'Outro'
    VAZIO = '', 'Não informado'


class UserProfile(models.Model):
    """
    Perfil do usuário vinculado ao Supabase Auth.
    O supabase_uid é o 'sub' (subject) do JWT do Supabase,
    que identifica unicamente cada usuário autenticado.
    """
    # DB-001: UUIDField nativo ocupa 16 bytes vs 36 bytes do VARCHAR — mais eficiente
    supabase_uid = models.UUIDField(
        unique=True,
        db_index=True,
        help_text="UUID do usuário no Supabase Auth (campo 'sub' do JWT)",
    )
    # DB-002: unique=True garante que um e-mail mapeia para exatamente um perfil
    email = models.EmailField(
        unique=True,
        db_index=True,
    )
    name = models.CharField(max_length=150)
    source = models.CharField(
        max_length=50,
        blank=True,
        default='',
        choices=SourceChoices.choices,
        help_text="Como o usuário conheceu o app",
    )
    # DB-003: choices garante integridade no banco
    tupi_level = models.CharField(
        max_length=30,
        blank=True,
        default='',
        choices=TupiLevelChoices.choices,
        help_text="Nível de conhecimento em Tupi",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    # DB-004: updated_at para auditoria de mudanças de nível
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Perfil do Usuário'
        verbose_name_plural = 'Perfis dos Usuários'
        indexes = [
            models.Index(
                fields=['tupi_level'],
                name='userprofile_level_idx',
                condition=models.Q(tupi_level__gt=''),
            ),
        ]

    def __str__(self):
        return f"{self.name} ({self.email}) — nível: {self.tupi_level or 'indefinido'}"
