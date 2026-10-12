"""
Models do sistema de Nivelamento Adaptativo (TRI).

MUDANÇA CRÍTICA: O TestAttempt agora é isolado por VarianteTupi.
Cada usuário faz o teste de nivelamento uma vez por variante/língua.
A constraint unique_together('user', 'variante') garante isso.

O teste de uma variante não impacta o nível de outra.
"""

from django.db import models
from users.models import UserProfile


class TestAttempt(models.Model):
    """
    Resultado do teste de nivelamento de um usuário para uma Variante Tupi específica.

    Regra de Negócio:
    - Um usuário só pode fazer o teste UMA VEZ por variante.
    - Ao trocar de variante, se ainda não tiver teste para aquela variante,
      o fluxo de nivelamento será acionado automaticamente.
    - O campo `calculated_level` atualiza o nível do usuário para AQUELA variante.
    """
    user = models.ForeignKey(
        UserProfile,
        on_delete=models.CASCADE,
        related_name="test_attempts"
    )
    variante = models.ForeignKey(
        'trilha.VarianteTupi',
        on_delete=models.CASCADE,
        related_name="test_attempts",
        verbose_name="Variante Tupi",
        help_text="Variante (língua) para a qual este teste foi realizado.",
        null=True,
        blank=True,
    )
    timestamp = models.DateTimeField(auto_now_add=True)
    calculated_level = models.IntegerField(
        verbose_name="Nível Calculado (1-10)"
    )
    calculated_theta = models.FloatField(
        default=0.0,
        verbose_name="Theta TRI",
        help_text="Parâmetro de habilidade estimado pelo algoritmo TRI."
    )
    is_suspected_cheating = models.BooleanField(
        default=False,
        verbose_name="Suspeita de Chute",
        help_text="Flagado quando o algoritmo detecta padrão de respostas aleatórias."
    )

    class Meta:
        verbose_name = "Tentativa de Nivelamento"
        verbose_name_plural = "Tentativas de Nivelamento"
        # CONSTRAINT CRÍTICA: um teste por usuário por variante.
        unique_together = ('user', 'variante')

    def __str__(self):
        return (
            f"{self.user.name} | {self.variante.nome} "
            f"— Nível {self.calculated_level}"
        )


class AnswerItem(models.Model):
    """
    Resposta individual de uma questão dentro de um TestAttempt.
    Armazena os parâmetros TRI para calibração futura do modelo.
    """
    attempt = models.ForeignKey(
        TestAttempt,
        on_delete=models.CASCADE,
        related_name="answers"
    )
    question_hash = models.CharField(
        max_length=255,
        verbose_name="Hash da Questão",
        help_text="Identificador da questão gerada (primeiros 250 chars do hash)."
    )
    question_text = models.TextField(verbose_name="Texto da Questão")
    selected_letter = models.CharField(max_length=1, verbose_name="Letra Selecionada")
    is_correct = models.BooleanField(verbose_name="Está Correta")
    time_taken_seconds = models.FloatField(verbose_name="Tempo de Resposta (s)")

    # Parâmetros TRI (Item Response Theory)
    param_a = models.FloatField(default=1.2, verbose_name="Parâmetro A (Discriminação)")
    param_b = models.FloatField(default=0.0, verbose_name="Parâmetro B (Dificuldade)")
    param_c = models.FloatField(default=0.25, verbose_name="Parâmetro C (Chute)")

    class Meta:
        verbose_name = "Resposta de Questão"
        verbose_name_plural = "Respostas de Questões"

    def __str__(self):
        return f"Resposta {self.question_hash[:8]}... — Correta: {self.is_correct}"


class UserVarianteLevel(models.Model):
    """
    Armazena o nível atual de um usuário em cada variante que já estudou.
    Atualizado ao final do TestAttempt ou via update_level API.

    Isso permite que o usuário tenha, por exemplo:
    - Nível 7 em Tupi Antigo
    - Nível 2 em Nheengatu (ainda em nivelamento)
    """
    user = models.ForeignKey(
        UserProfile,
        on_delete=models.CASCADE,
        related_name="niveis_por_variante"
    )
    variante = models.ForeignKey(
        'trilha.VarianteTupi',
        on_delete=models.CASCADE,
        related_name="niveis_usuarios"
    )
    nivel = models.IntegerField(
        default=1,
        verbose_name="Nível (1-10)"
    )
    current_theta = models.FloatField(
        default=0.0,
        verbose_name="Theta Habilidade TRI",
        help_text="Habilidade psicométrica contínua do usuário [-3.0 a +3.0]."
    )
    current_se = models.FloatField(
        default=1.0,
        verbose_name="Erro Padrão SE",
        help_text="Erro padrão da estimativa de habilidade."
    )
    calibracoes_count = models.PositiveIntegerField(
        default=0,
        verbose_name="Total de Calibrações"
    )
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Nível do Usuário por Variante"
        verbose_name_plural = "Níveis dos Usuários por Variante"
        unique_together = ('user', 'variante')

    def __str__(self):
        return f"{self.user.name} | {self.variante.nome}: Nível {self.nivel} (θ={self.current_theta:.2f}, SE={self.current_se:.2f})"


class BirdbrainCalibrationLog(models.Model):
    """
    Registro histórico e auditável de cada calibração psicométrica (BirdBrain TRI EAP)
    executada após conclusão de lições ou testes.
    """
    user = models.ForeignKey(
        UserProfile,
        on_delete=models.CASCADE,
        related_name="birdbrain_calibration_logs"
    )
    variante = models.ForeignKey(
        'trilha.VarianteTupi',
        on_delete=models.CASCADE,
        related_name="birdbrain_calibration_logs"
    )
    licao = models.ForeignKey(
        'trilha.Licao',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="birdbrain_logs"
    )
    old_theta = models.FloatField()
    new_theta = models.FloatField()
    old_se = models.FloatField()
    new_se = models.FloatField()
    delta = models.FloatField()
    accuracy_pct = models.FloatField(default=0.0)
    items_count = models.PositiveIntegerField(default=0)
    old_nivel = models.IntegerField(default=1)
    new_nivel = models.IntegerField(default=1)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Log de Calibração BirdBrain"
        verbose_name_plural = "Logs de Calibração BirdBrain"
        ordering = ['-created_at']

    def __str__(self):
        return f"[{self.created_at:%d/%m/%Y %H:%M}] {self.user.name} - Delta: {self.delta:+.3f} (Nível {self.old_nivel} -> {self.new_nivel})"
