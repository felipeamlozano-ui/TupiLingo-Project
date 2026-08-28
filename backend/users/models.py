import uuid
from django.db import models
from django.utils import timezone
from django.contrib.contenttypes.models import ContentType
from django.contrib.contenttypes.fields import GenericForeignKey
class StatusFilaChoices(models.TextChoices):
    """Estado do exercício em relação ao dispositivo do usuário."""
    NA_FILA = 'na_fila', 'Na Fila'
    BAIXADO = 'baixado', 'Baixado'
    CONCLUIDO = 'concluido', 'Concluído'

    
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
    # supabase_uid é único e indexado para consultas rápidas
    supabase_uid = models.UUIDField(
        unique=True,
        db_index=True,
        help_text="UUID do usuário no Supabase Auth (campo 'sub' do JWT)",
    )
    # Garante que não haja duplicidade de emails, e indexa para consultas rápidas
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
    
    tupi_level = models.CharField(
        max_length=30,
        blank=True,
        default='',
        choices=TupiLevelChoices.choices,
        help_text="Nível de conhecimento em Tupi",
    )
    created_at = models.DateTimeField(auto_now_add=True)
   
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

    # Integração da pontuação total do usuário, que pode ser calculada a partir de medalhas e progresso em módulos (Para o futuro, pode-se criar um método que atualize a pontuação com base em medalhas e progresso)
    pontos = models.IntegerField(default=0, help_text="Pontuação total acumulada")
    medalhas = models.ManyToManyField('Medalha', through='UsuarioMedalha', related_name='usuarios')
    modulos = models.ManyToManyField('Modulo', through='UsuarioModulo', related_name='usuarios_progresso')


class Modulo(models.Model):
    titulo = models.CharField(max_length=255, null=False, blank=False, verbose_name="titulo")
    descricao = models.CharField(max_length=255, verbose_name='descricao')
    dificuldade = models.IntegerField(default=10, verbose_name="dificuldade")
class UserModulo(models.Model):
    user = models.ForeignKey(UserProfile, on_delete=models.CASCADE, verbose_name="usuario")
    modulo = models.ForeignKey(Modulo, on_delete=models.CASCADE, verbose_name="modulo")
    bloqueado = models.BooleanField(default=True, verbose_name="bloqueado")
    
    class Meta:
        verbose_name = 'Modulo do Usuario'
        verbose_name_plural = 'Modulos do Usuario'

class Medalha(models.Model):
    nome = models.CharField(max_length=255, verbose_name="nome")
    descricao = models.CharField(max_length=255, verbose_name="descricao")
    icone = models.CharField(max_length=255, verbose_name="icone")
    codigo = models.CharField(max_length=255, verbose_name="codigo")

    def __str__(self):
        return self.nome

    class Meta:
        verbose_name = "Medalha"
        verbose_name_plural = "Medalhas"

class UserMedalha(models.Model):
    user = models.ForeignKey(UserProfile, on_delete=models.CASCADE, verbose_name="usuario")
    medalha = models.ForeignKey(Medalha, on_delete=models.CASCADE, verbose_name="medalha")
    dataConquista = models.DateTimeField(editable=False, auto_now=True, verbose_name="data conquista")

    class Meta:
        verbose_name = "Usuario Medalha"
        verbose_name_plural = "Usuario Medalhas"

class ExercicioBase(models.Model):
    """Molde abstrato para os exercícios curados da trilha de aprendizagem."""
    modulo = models.ForeignKey(Modulo, on_delete=models.CASCADE, related_name='%(class)ss')
    enunciado = models.CharField(max_length=255, verbose_name="enunciado")
    pontos = models.IntegerField(default=10)

    class Meta:
        abstract = True

    def __str__(self):
        return f"{self.modulo.titulo} - {self.enunciado[:30]}..."
    
class ExercicioEscolha(ExercicioBase):
    opcoes = models.JSONField(null=False, blank=False, verbose_name="opcoes")
    respostaCorreta = models.IntegerField(null=False, verbose_name="resposta correta")

    class Meta:
        verbose_name = "Exercicio Escolha"
        verbose_name_plural = "Exercicios Escolha"

class ExercicioCompletar(ExercicioBase):
    textoComLacunas = models.TextField(blank=False, null=False, verbose_name="texto com lacunas")
    respostasCorretas = models.JSONField(blank=False, null=False, verbose_name="respostas corretas")

    class Meta:
        verbose_name = "Exercicio Completar"
        verbose_name_plural = "Exercicios Completar"

class ExercicioAssociacao(ExercicioBase):
    colunaEsquerda = models.JSONField(blank=False, null=False, verbose_name="coluna esquerda")
    colunaDireita = models.JSONField(blank=False, null=False, verbose_name="coluna direita")
    associacaoCorreta = models.JSONField(blank=False, null=False, verbose_name="associacao correta")

    class Meta:
        verbose_name = "Exercicio Associacao"
        verbose_name_plural = "Exercicios Associacao"
class ExercicioCompletar(ExercicioBase):
    texto_com_lacunas = models.TextField(help_text="Texto contendo marcadores para as lacunas")
    respostas_corretas = models.JSONField(help_text="Lista de palavras esperadas nas lacunas")
# Essa classe é utilizada para a IA gerar a questão, aqui é apenas visual
# class QuestaoSchema(BaseModel):
#     enunciado: str = Field(description="Enunciado da questão")
#     contexto: Optional[str] = Field(None, description="Contexto extra ou trecho base")
#     alternativas: List[Alternativa] = Field(description="Lista de alternativas da questão")
#     resposta_correta: str = Field(description="Letra correspondente à resposta correta")
#     explicacao: str = Field(description="Explicação da resposta")
#     dificuldade: str = Field(description="Dificuldade da questão")
#     categoria: str = Field(description="Categoria gramatical ou semântica (ex: Verbos, Vocabulário)")
#     idioma: str = Field(default="tupi", description="Idioma alvo da questão")
class FilaExercicioUsuario(models.Model):
    # Classe para controlar a fila de exercícios no buffer do dispositivo (Evita atrasos devido a conexões lentas)
    usuario = models.ForeignKey(
        'UserProfile',
        on_delete=models.CASCADE,
        related_name='fila_exercicios'
    )

    # Lembrar de definir contenttype na hora de realizar essa consulta
    content_type = models.ForeignKey(ContentType, on_delete=models.CASCADE)
    object_id = models.PositiveIntegerField()
    
    exercicio = GenericForeignKey('content_type', 'object_id') # Mudar depois que definir a classe exercicio

    status = models.CharField(
        max_length=20,
        choices=StatusFilaChoices.choices,
        default=StatusFilaChoices.NA_FILA,
        help_text="Status de sincronização com o aparelho"
    )
    ordem_apresentacao = models.IntegerField(
        help_text="Ordem que o exercicio deve aparecer no app" 

        # Definir após criação da classe exercicio

    )
    data_baixado = models.DateTimeField(null=True, blank=True)
    data_conclusao = models.DateTimeField(null=True, blank=True)

    class Meta:
        verbose_name = 'Fila de Exercício do Usuário'
        verbose_name_plural = 'Filas de Exercícios dos Usuários'
        # Garante a ordem correta quando o app solicitar a fila
        ordering = ['ordem_apresentacao'] 
        # Evita que o mesmo exercício entre na fila do usuário duas vezes
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