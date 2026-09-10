"""
Models principais do sistema de usuários do TupiLingo.

Inclui:
- UserProfile: perfil do usuário autenticado via Supabase Auth.
- Achievement / UserAchievement: sistema de medalhas culturais.
- UserLesson: progresso do usuário por Lição.
- VocabularyProgress: revisão espaçada (SM-2) por palavra.
- FilaExercicioUsuario: buffer de exercícios offline.
"""

import uuid
from django.db import models
from django.utils import timezone
from django.contrib.contenttypes.models import ContentType
from django.contrib.contenttypes.fields import GenericForeignKey


# ─── Choices ─────────────────────────────────────────────────────────────────

class StatusFilaChoices(models.TextChoices):
    """Estado do exercício em relação ao dispositivo do usuário."""
    NA_FILA = 'na_fila', 'Na Fila'
    BAIXADO = 'baixado', 'Baixado'
    CONCLUIDO = 'concluido', 'Concluído'


class SourceChoices(models.TextChoices):
    """Como o usuário conheceu o app."""
    REDES_SOCIAIS = 'redes_sociais', 'Redes Sociais'
    INDICACAO = 'indicacao', 'Indicação de amigo'
    ESCOLA = 'escola', 'Escola / Universidade'
    PESQUISA = 'pesquisa', 'Pesquisa na internet'
    OUTRO = 'outro', 'Outro'
    VAZIO = '', 'Não informado'


class TipoAchievementChoices(models.TextChoices):
    """Tipo de conquista."""
    XP_TIER = 'xp_tier', 'Medalha de XP'
    CULTURAL = 'cultural', 'Conquista Cultural'
    EXPLORACAO = 'exploracao', 'Exploração'


# ─── UserProfile ─────────────────────────────────────────────────────────────

class UserProfile(models.Model):
    """
    Perfil do usuário vinculado ao Supabase Auth.
    O supabase_uid é o 'sub' (subject) do JWT do Supabase,
    que identifica unicamente cada usuário autenticado.
    """
    supabase_uid = models.UUIDField(
        unique=True,
        db_index=True,
        help_text="UUID do usuário no Supabase Auth (campo 'sub' do JWT)",
    )
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

    # ── Variante ativa ───────────────────────────────────────────────────────
    # A variante que o usuário está estudando atualmente.
    # Definida na primeira seleção e pode ser alterada (o que requer novo teste de nivelamento).
    variante_ativa = models.ForeignKey(
        'trilha.VarianteTupi',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='usuarios_ativos',
        verbose_name="Variante Tupi Ativa",
        help_text="Língua/Variante que o usuário está estudando atualmente."
    )

    # ── Gamificação (sem punição, sem corações) ──────────────────────────────
    xp_total = models.IntegerField(
        default=0,
        verbose_name="XP Total",
        help_text="Pontuação de experiência acumulada ao longo de toda a jornada."
    )

    # ── Ofensiva Diária (Streak) Automatizado (Supabase + pg_cron) ────────────
    streak_atual = models.IntegerField(
        default=0,
        verbose_name="Ofensiva Atual (Dias)",
        help_text="Dias consecutivos de estudo ativo do usuário."
    )
    maior_streak = models.IntegerField(
        default=0,
        verbose_name="Maior Ofensiva (Recorde)",
        help_text="Maior sequência de dias consecutivos já atingida."
    )
    ultimo_dia_estudado = models.DateField(
        null=True,
        blank=True,
        verbose_name="Último Dia Estudado",
        help_text="Data da última atividade válida no fuso America/Sao_Paulo."
    )
    dias_estudados_total = models.IntegerField(
        default=0,
        verbose_name="Dias Estudados no Total",
        help_text="Contagem total de dias com pelo menos uma atividade concluída."
    )

    # ── Medalhas ─────────────────────────────────────────────────────────────
    achievements = models.ManyToManyField(
        'Achievement',
        through='UserAchievement',
        related_name='usuarios',
        blank=True
    )

    # ── Timestamps ───────────────────────────────────────────────────────────
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Perfil do Usuário'
        verbose_name_plural = 'Perfis dos Usuários'

    def __str__(self):
        return f"{self.name} ({self.email})"


# ─── Achievement ─────────────────────────────────────────────────────────────

class Achievement(models.Model):
    """
    Medalha ou conquista desbloqueável pelo usuário.

    Tipos:
    - xp_tier: Conquistas por XP total acumulado (Semente, Folha, Arco, Guerreiro, Pajé, Guardião).
    - cultural: Ganhas ao completar capítulos, ler curiosidades, dominar vocabulário.
    - exploracao: Ganhas por completar trilhas de cenários específicos.

    XP tiers: Semente=0, Folha=500, Arco=1500, Guerreiro=4000, Pajé=8000, Guardião=15000.
    """
    nome = models.CharField(max_length=100, unique=True, verbose_name="Nome")
    descricao = models.TextField(verbose_name="Descrição")
    tipo = models.CharField(
        max_length=15,
        choices=TipoAchievementChoices.choices,
        default=TipoAchievementChoices.XP_TIER,
        verbose_name="Tipo"
    )
    icone = models.CharField(
        max_length=10,
        blank=True,
        verbose_name="Ícone Emoji",
        help_text="Ex: 🌱 para Semente, 🏹 para Arco"
    )
    codigo = models.SlugField(
        max_length=80,
        unique=True,
        verbose_name="Código",
        help_text="Código interno único. Ex: xp_semente, cultural_floresta"
    )
    # Para conquistas de XP: quantidade mínima de XP necessária.
    xp_necessario = models.IntegerField(
        default=0,
        verbose_name="XP Necessário",
        help_text="Para conquistas do tipo xp_tier: mínimo de XP acumulado."
    )
    # Para conquistas culturais, pode estar ligada a um Capítulo ou Trilha.
    # A lógica de desbloqueio é tratada no backend (achievement_service.py futuramente).

    class Meta:
        verbose_name = "Conquista (Achievement)"
        verbose_name_plural = "Conquistas (Achievements)"
        ordering = ['xp_necessario', 'nome']

    def __str__(self):
        return f"{self.icone} {self.nome}"


class UserAchievement(models.Model):
    """Relação Many-to-Many entre UserProfile e Achievement com data de conquista."""
    user = models.ForeignKey(UserProfile, on_delete=models.CASCADE)
    achievement = models.ForeignKey(Achievement, on_delete=models.CASCADE)
    conquistada_em = models.DateTimeField(auto_now_add=True, verbose_name="Conquistada em")

    class Meta:
        verbose_name = "Conquista do Usuário"
        verbose_name_plural = "Conquistas dos Usuários"
        unique_together = ('user', 'achievement')

    def __str__(self):
        return f"{self.user.name} desbloqueou '{self.achievement.nome}'"


# ─── UserLesson ──────────────────────────────────────────────────────────────

class UserLesson(models.Model):
    """
    Rastreia o progresso do usuário em cada Lição da Trilha.
    Status: BLOQUEADA → DISPONÍVEL → EM_ANDAMENTO → CONCLUÍDA.
    """
    usuario = models.ForeignKey(
        UserProfile,
        on_delete=models.CASCADE,
        related_name='progresso_licoes'
    )
    licao = models.ForeignKey(
        'trilha.Licao',
        on_delete=models.CASCADE,
        related_name='progressos_usuarios'
    )
    status = models.CharField(
        max_length=15,
        choices=[
            ('bloqueada', 'Bloqueada'),
            ('disponivel', 'Disponível'),
            ('em_andamento', 'Em Andamento'),
            ('concluida', 'Concluída'),
        ],
        default='bloqueada',
        db_index=True,
        verbose_name="Status"
    )
    # Percentual de conclusão (0-100), para caso o usuário saia no meio da lição.
    completion_percentage = models.FloatField(
        default=0.0,
        verbose_name="Percentual de Conclusão"
    )
    # Taxa de acerto dos exercícios desta lição (0.0 a 1.0).
    accuracy = models.FloatField(
        default=0.0,
        verbose_name="Taxa de Acerto"
    )
    earned_xp = models.IntegerField(
        default=0,
        verbose_name="XP Ganho nesta Lição"
    )
    iniciada_em = models.DateTimeField(null=True, blank=True, verbose_name="Iniciada em")
    concluida_em = models.DateTimeField(null=True, blank=True, db_index=True, verbose_name="Concluída em")

    class Meta:
        verbose_name = "Progresso na Lição"
        verbose_name_plural = "Progressos nas Lições"
        unique_together = ('usuario', 'licao')
        indexes = [
            models.Index(fields=['usuario', 'status']),
            models.Index(fields=['usuario', 'concluida_em']),
        ]

    def __str__(self):
        return f"{self.usuario.name} — {self.licao.titulo} [{self.status}]"


# ─── VocabularyProgress (SM-2) ────────────────────────────────────────────────

class VocabularyProgress(models.Model):
    """
    Rastreia o progresso de memorização de cada VocabularyItem por usuário.
    Implementa o algoritmo de Revisão Espaçada SM-2.

    Como funciona:
    - O usuário revisa palavras.
    - Se acertar: o intervalo até a próxima revisão aumenta (ease_factor > 2.5).
    - Se errar: o intervalo diminui e a palavra é revisada em breve.
    - next_review: próximo datetime em que a palavra deve ser revisada.
    """
    usuario = models.ForeignKey(
        UserProfile,
        on_delete=models.CASCADE,
        related_name='progresso_vocabulario'
    )
    item = models.ForeignKey(
        'trilha.VocabularyItem',
        on_delete=models.CASCADE,
        related_name='progressos_usuarios'
    )
    # SM-2: número de repetições consecutivas corretas.
    repetitions = models.IntegerField(default=0)
    # SM-2: fator de facilidade (default 2.5). Cresce com acertos, cai com erros.
    ease_factor = models.FloatField(default=2.5)
    # SM-2: intervalo atual em dias até a próxima revisão.
    interval_days = models.IntegerField(default=1)
    # Data/hora da próxima revisão.
    next_review = models.DateTimeField(default=timezone.now)
    # Última vez que o item foi revisado.
    last_reviewed = models.DateTimeField(null=True, blank=True)

    class Meta:
        verbose_name = "Progresso de Vocabulário"
        verbose_name_plural = "Progressos de Vocabulário"
        unique_together = ('usuario', 'item')

    def __str__(self):
        return f"{self.usuario.name} — {self.item.palavra_tupi} (próxima: {self.next_review.date()})"


# ─── FilaExercicioUsuario ─────────────────────────────────────────────────────

class FilaExercicioUsuario(models.Model):
    """
    Buffer de exercícios no dispositivo do usuário.
    Evita atrasos por conexões lentas, permitindo operação offline.
    """
    usuario = models.ForeignKey(
        'UserProfile',
        on_delete=models.CASCADE,
        related_name='fila_exercicios'
    )
    content_type = models.ForeignKey(ContentType, on_delete=models.CASCADE)
    object_id = models.PositiveIntegerField()
    exercicio = GenericForeignKey('content_type', 'object_id')

    status = models.CharField(
        max_length=20,
        choices=StatusFilaChoices.choices,
        default=StatusFilaChoices.NA_FILA,
        help_text="Status de sincronização com o aparelho"
    )
    ordem_apresentacao = models.IntegerField(
        help_text="Ordem que o exercício deve aparecer no app"
    )
    data_baixado = models.DateTimeField(null=True, blank=True)
    data_conclusao = models.DateTimeField(null=True, blank=True)

    class Meta:
        verbose_name = 'Fila de Exercício do Usuário'
        verbose_name_plural = 'Filas de Exercícios dos Usuários'
        ordering = ['ordem_apresentacao']
        unique_together = ('usuario', 'content_type', 'object_id')

    def __str__(self):
        return f"Fila de {self.usuario.name} - {self.exercicio} ({self.get_status_display()})"

    def marcar_como_baixado(self):
        self.status = StatusFilaChoices.BAIXADO
        self.data_baixado = timezone.now()
        self.save()

    def marcar_como_concluido(self):
        self.status = StatusFilaChoices.CONCLUIDO
        self.data_conclusao = timezone.now()
        self.save()


# ─── DailyStudyLog ────────────────────────────────────────────────────────────

class DailyStudyLog(models.Model):
    """
    Registro diário de atividades de estudo do usuário para cálculo de estatísticas
    100% autênticas (ritmo semanal, calendário de atividade, tempo e precisão).
    """
    user = models.ForeignKey(
        UserProfile,
        on_delete=models.CASCADE,
        related_name='daily_study_logs',
        verbose_name="Usuário"
    )
    data = models.DateField(
        verbose_name="Data da Atividade",
        help_text="Data no fuso horário America/Sao_Paulo"
    )
    xp_ganho = models.IntegerField(default=0, verbose_name="XP Ganho no Dia")
    licoes_concluidas = models.IntegerField(default=0, verbose_name="Lições Concluídas")
    exercicios_respondidos = models.IntegerField(default=0, verbose_name="Exercícios Respondidos")
    exercicios_corretos = models.IntegerField(default=0, verbose_name="Exercícios Corretos")
    tempo_estudo_segundos = models.IntegerField(default=0, verbose_name="Tempo de Estudo (Segundos)")

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Log Diário de Estudo'
        verbose_name_plural = 'Logs Diários de Estudo'
        unique_together = ('user', 'data')
        indexes = [
            models.Index(fields=['user', '-data'], name='idx_dailylog_user_data_desc'),
        ]
        db_table = 'users_daily_study_log'

    def __str__(self):
        return f"{self.user.name} - {self.data}: {self.xp_ganho} XP ({self.licoes_concluidas} lições)"