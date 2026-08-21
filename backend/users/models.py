from django.db import models


class UserProfile(models.Model):
    """
    Perfil do usuario vinculado ao Supabase Auth.
    O supabase_uid e o 'sub' (subject) do JWT do Supabase,
    que identifica unicamente cada usuario autenticado.
    """
    supabase_uid = models.CharField(
        max_length=255,
        unique=True,
        db_index=True,
        help_text="UUID do usuario no Supabase Auth (campo 'sub' do JWT)"
    )
    email = models.EmailField()
    name = models.CharField(max_length=150)
    source = models.CharField(
        max_length=50,
        blank=True,
        default='',
        help_text="Como o usuario conheceu o app (redes_sociais, indicacao, etc.)"
    )
    tupi_level = models.CharField(
        max_length=30,
        blank=True,
        default='',
        help_text="Nivel de conhecimento em Tupi (iniciante, intermediario, avancado)"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = 'Perfil do Usuario'
        verbose_name_plural = 'Perfis dos Usuarios'

    def __str__(self):
        return f"{self.name} ({self.email})"
