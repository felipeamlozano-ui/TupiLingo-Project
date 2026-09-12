"""
Models da Jornada Histórica do TupiLingo.

Hierarquia:
    VarianteTupi → TrilhaHistorica → Capitulo (+ Scenario) → Licao → StoryBlock/Exercicio/VocabularyItem

O conteúdo é totalmente administrado pelo painel Django Admin.
O Flutter renderiza dinamicamente a partir desses modelos via API.
"""

from django.db import models


# ─── Choices ─────────────────────────────────────────────────────────────────

class TipoStoryBlockChoices(models.TextChoices):
    STORY = 'story', 'Narrativa'
    CURIOSITY = 'curiosity', 'Curiosidade Cultural'
    DIALOGUE = 'dialogue', 'Diálogo'
    IMAGE = 'image', 'Imagem'
    AUDIO = 'audio', 'Áudio'
    VOCABULARY = 'vocabulary', 'Vocabulário'


class TipoExercicioChoices(models.TextChoices):
    ESCOLHA_MULTIPLA = 'escolha_multipla', 'Múltipla Escolha'
    COMPLETAR = 'completar', 'Completar Lacunas'
    ASSOCIACAO = 'associacao', 'Associação de Pares'
    AUDIO = 'audio', 'Reconhecimento de Áudio'
    TRADUCAO = 'traducao', 'Tradução Livre'


class DificuldadeChoices(models.TextChoices):
    FACIL = 'facil', 'Fácil'
    MEDIA = 'media', 'Média'
    DIFICIL = 'dificil', 'Difícil'


class StatusLicaoChoices(models.TextChoices):
    BLOQUEADA = 'bloqueada', 'Bloqueada'
    DISPONIVEL = 'disponivel', 'Disponível'
    EM_ANDAMENTO = 'em_andamento', 'Em Andamento'
    CONCLUIDA = 'concluida', 'Concluída'


# ─── VarianteTupi ─────────────────────────────────────────────────────────────

class VarianteTupi(models.Model):
    """
    Representa uma variante/idioma da família Tupi-Guarani.
    Ex: Tupi Antigo, Nheengatu, Guarani Mbya.
    """
    nome = models.CharField(
        max_length=100,
        unique=True,
        verbose_name="Nome da Variante",
        help_text="Ex: Tupi Antigo, Nheengatu, Guarani Mbya"
    )
    codigo = models.SlugField(
        max_length=50,
        unique=True,
        verbose_name="Código Único",
        help_text="Ex: tupi, tupi_contemporaneo, tupinamba. Usado internamente e no RAG."
    )
    descricao = models.TextField(
        blank=True,
        verbose_name="Descrição",
        help_text="Contexto histórico e cultural desta variante."
    )
    icone = models.CharField(
        max_length=10,
        blank=True,
        default='🌿',
        verbose_name="Ícone Emoji",
        help_text="Emoji representativo, ex: 🌿 ou 🏹"
    )
    ativo = models.BooleanField(
        default=True,
        verbose_name="Ativo",
        help_text="Desativar oculta a variante do app sem excluí-la."
    )
    ordem = models.PositiveSmallIntegerField(
        default=0,
        verbose_name="Ordem de Exibição",
        help_text="Ordem que aparece na tela de seleção."
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Variante Tupi"
        verbose_name_plural = "Variantes Tupi"
        ordering = ['ordem', 'nome']

    def __str__(self):
        return f"{self.icone} {self.nome}"


# ─── TrilhaHistorica ──────────────────────────────────────────────────────────

class TrilhaHistorica(models.Model):
    """
    A campanha narrativa completa de uma VarianteTupi.
    Uma variante pode ter apenas uma trilha principal (expandível no futuro).
    """
    variante = models.OneToOneField(
        VarianteTupi,
        on_delete=models.CASCADE,
        related_name='trilha',
        verbose_name="Variante"
    )
    titulo = models.CharField(max_length=200, verbose_name="Título")
    subtitulo = models.CharField(
        max_length=300,
        blank=True,
        verbose_name="Subtítulo / Slogan"
    )
    publicada = models.BooleanField(
        default=False,
        verbose_name="Publicada",
        help_text="Somente trilhas publicadas aparecem no app."
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Trilha Histórica"
        verbose_name_plural = "Trilhas Históricas"

    def __str__(self):
        return f"{self.titulo} ({self.variante.nome})"


# ─── Scenario ─────────────────────────────────────────────────────────────────

class Scenario(models.Model):
    """
    Cenário visual/sonoro associado a um Capitulo.
    Define o background, os sons ambientes e a paleta de cores do mapa.
    O Flutter consome esses dados para criar a atmosfera imersiva.
    """
    nome = models.CharField(max_length=100, verbose_name="Nome do Cenário")
    background_image = models.ImageField(
        upload_to='scenarios/backgrounds/',
        null=True, blank=True,
        verbose_name="Imagem de Fundo",
        help_text="Imagem de fundo do mapa interativo para este capítulo."
    )
    ambient_audio = models.FileField(
        upload_to='scenarios/audio/',
        null=True, blank=True,
        verbose_name="Áudio Ambiente",
        help_text="Sons de fundo como floresta, rio, pássaros..."
    )
    # Paleta armazenada como JSON: {"primary": "#hex", "secondary": "#hex", "accent": "#hex"}
    palette = models.JSONField(
        default=dict,
        blank=True,
        verbose_name="Paleta de Cores",
        help_text='JSON com cores do tema. Ex: {"primary": "#0E5D4E", "secondary": "#D08A45"}'
    )

    class Meta:
        verbose_name = "Cenário"
        verbose_name_plural = "Cenários"

    def __str__(self):
        return self.nome


# ─── Capitulo ─────────────────────────────────────────────────────────────────

class Capitulo(models.Model):
    """
    Grande período histórico da TrilhaHistorica.
    Ex: "Cap. I - O Nascimento dos Povos Tupis", "Cap. II - A Vida nas Aldeias".
    """
    trilha = models.ForeignKey(
        TrilhaHistorica,
        on_delete=models.CASCADE,
        related_name='capitulos',
        verbose_name="Trilha"
    )
    scenario = models.ForeignKey(
        Scenario,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='capitulos',
        verbose_name="Cenário"
    )
    titulo = models.CharField(max_length=200, verbose_name="Título")
    descricao = models.TextField(blank=True, verbose_name="Descrição Narrativa")
    numero = models.PositiveSmallIntegerField(
        verbose_name="Número do Capítulo",
        help_text="Ordem sequencial dentro da trilha."
    )
    publicado = models.BooleanField(default=False, db_index=True, verbose_name="Publicado")

    class Meta:
        verbose_name = "Capítulo"
        verbose_name_plural = "Capítulos"
        ordering = ['trilha', 'numero']
        unique_together = ('trilha', 'numero')

    def __str__(self):
        return f"Cap. {self.numero}: {self.titulo}"


# ─── Licao ────────────────────────────────────────────────────────────────────

class Licao(models.Model):
    """
    Um pequeno episódio narrativo dentro de um Capítulo.
    Ex: 'Chegada à Aldeia', 'Conhecendo o Pajé'.
    Representa um ponto interativo no Mapa da Home.
    """
    capitulo = models.ForeignKey(
        Capitulo,
        on_delete=models.CASCADE,
        related_name='licoes',
        verbose_name="Capítulo"
    )
    titulo = models.CharField(max_length=200, verbose_name="Título da Lição")
    descricao = models.CharField(
        max_length=300,
        blank=True,
        verbose_name="Descrição curta",
        help_text="Aparece no pop-up do mapa antes de começar."
    )
    numero = models.PositiveSmallIntegerField(
        verbose_name="Número da Lição",
        help_text="Ordem dentro do capítulo."
    )
    xp_base = models.PositiveSmallIntegerField(
        default=20,
        verbose_name="XP Base",
        help_text="XP concedido ao concluir esta lição sem erros."
    )
    # Posição visual no mapa (porcentagem do espaço disponível, 0-100)
    pos_x = models.FloatField(
        default=50.0,
        verbose_name="Posição X no mapa (%)",
        help_text="Posição horizontal (0=esquerda, 100=direita) no cenário."
    )
    pos_y = models.FloatField(
        default=50.0,
        verbose_name="Posição Y no mapa (%)",
        help_text="Posição vertical (0=topo, 100=fundo) no cenário."
    )
    publicada = models.BooleanField(default=False, db_index=True, verbose_name="Publicada")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Lição"
        verbose_name_plural = "Lições"
        ordering = ['capitulo', 'numero']
        unique_together = ('capitulo', 'numero')

    def __str__(self):
        return f"{self.capitulo.titulo} > Lição {self.numero}: {self.titulo}"


# ─── StoryBlock ───────────────────────────────────────────────────────────────

class StoryBlock(models.Model):
    """
    Bloco de conteúdo atômico dentro de uma Lição.
    Funciona como um 'LEGO' da narrativa: o admin monta a história combinando blocos.
    O Flutter renderiza cada bloco sequencialmente.
    """
    licao = models.ForeignKey(
        Licao,
        on_delete=models.CASCADE,
        related_name='story_blocks',
        verbose_name="Lição"
    )
    tipo = models.CharField(
        max_length=20,
        choices=TipoStoryBlockChoices.choices,
        verbose_name="Tipo de Bloco"
    )
    titulo = models.CharField(
        max_length=200,
        blank=True,
        verbose_name="Título do Bloco"
    )
    conteudo = models.TextField(
        blank=True,
        verbose_name="Conteúdo de Texto",
        help_text="Texto principal da narrativa, curiosidade ou diálogo."
    )
    midia = models.FileField(
        upload_to='storyblocks/media/',
        null=True, blank=True,
        verbose_name="Mídia",
        help_text="Imagem ou áudio anexado a este bloco."
    )
    ordem = models.PositiveSmallIntegerField(
        default=0,
        verbose_name="Ordem de Exibição"
    )
    # Metadados extras para comportamentos especiais no Flutter (e.g., personagem no diálogo)
    extra = models.JSONField(
        default=dict,
        blank=True,
        verbose_name="Dados Extras",
        help_text='JSON com dados complementares. Ex: {"personagem": "Pajé", "lado": "esquerda"}'
    )
    # XP bônus por exploração (ex: ler uma curiosidade)
    xp_bonus = models.PositiveSmallIntegerField(
        default=0,
        verbose_name="XP Bônus",
        help_text="XP adicional concedido ao usuário por explorar este bloco."
    )

    class Meta:
        verbose_name = "Bloco de História"
        verbose_name_plural = "Blocos de História"
        ordering = ['licao', 'ordem']

    def __str__(self):
        return f"{self.licao.titulo} — [{self.get_tipo_display()}] ordem {self.ordem}"


# ─── VocabularyItem ───────────────────────────────────────────────────────────

class VocabularyItem(models.Model):
    """
    Palavra do vocabulário ensinada dentro de uma Lição.
    Utilizada tanto nos StoryBlocks quanto no sistema de Revisão Espaçada .
    """
    licao = models.ForeignKey(
        Licao,
        on_delete=models.CASCADE,
        related_name='vocabulary',
        verbose_name="Lição"
    )
    palavra_tupi = models.CharField(max_length=200, verbose_name="Palavra em Tupi")
    traducao_pt = models.CharField(max_length=200, verbose_name="Tradução em Português")
    transliteracao = models.CharField(
        max_length=200,
        blank=True,
        verbose_name="Transliteração Fonética",
        help_text="Como pronunciar. Ex: 'tsu-PÃ'"
    )
    audio = models.FileField(
        upload_to='vocabulary/audio/',
        null=True, blank=True,
        verbose_name="Áudio de Pronúncia"
    )
    exemplo_tupi = models.CharField(
        max_length=400,
        blank=True,
        verbose_name="Frase de Exemplo (Tupi)"
    )
    exemplo_pt = models.CharField(
        max_length=400,
        blank=True,
        verbose_name="Frase de Exemplo (Português)"
    )
    ordem = models.PositiveSmallIntegerField(default=0, verbose_name="Ordem")
    categoria = models.CharField(
        max_length=100,
        default='geral',
        verbose_name="Categoria Lexical",
        help_text="Ex: fauna, flora, natureza, mitologia, corpo, geral."
    )
    classe_gramatical = models.CharField(
        max_length=100,
        default='substantivo',
        verbose_name="Classe Gramatical",
        help_text="Ex: substantivo, verbo, adjetivo, advérbio."
    )

    class Meta:
        verbose_name = "Item de Vocabulário"
        verbose_name_plural = "Itens de Vocabulário"
        ordering = ['licao', 'ordem']

    def __str__(self):
        return f"{self.palavra_tupi} → {self.traducao_pt}"


# ─── Exercicio (Base Abstrata) ────────────────────────────────────────────────

class ExercicioBase(models.Model):
    """
    Molde abstrato para os exercícios interativos.
    Sempre vinculado a uma Lição e, opcionalmente, a um StoryBlock específico.
    A resposta é sempre validada no BACKEND via validation_service.
    """
    licao = models.ForeignKey(
        Licao,
        on_delete=models.CASCADE,
        related_name='%(class)ss',
        verbose_name="Lição"
    )
    story_block = models.ForeignKey(
        StoryBlock,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='%(class)ss',
        verbose_name="Bloco de História",
        help_text="Se preenchido, este exercício aparece dentro daquele bloco específico."
    )
    enunciado = models.CharField(max_length=500, verbose_name="Enunciado")
    explicacao = models.TextField(
        blank=True,
        verbose_name="Explicação",
        help_text="Exibida após o usuário responder. Explica a resposta correta com contexto cultural."
    )
    dificuldade = models.CharField(
        max_length=10,
        choices=DificuldadeChoices.choices,
        default=DificuldadeChoices.FACIL,
        verbose_name="Dificuldade"
    )
    pontos_base = models.PositiveSmallIntegerField(
        default=10,
        verbose_name="Pontos Base (XP)"
    )
    ordem = models.PositiveSmallIntegerField(
        default=0,
        verbose_name="Ordem na Lição"
    )
    midia = models.FileField(
        upload_to='exercicios/media/',
        null=True, blank=True,
        verbose_name="Mídia de Apoio",
        help_text="Imagem ou áudio de apoio ao enunciado."
    )

    class Meta:
        abstract = True
        ordering = ['licao', 'ordem']

    def __str__(self):
        return f"[{self.licao.titulo}] {self.enunciado[:50]}..."


# ─── Tipos Concretos de Exercício ─────────────────────────────────────────────

class ExercicioEscolha(ExercicioBase):
    """
    Questão de múltipla escolha.
    opcoes: lista de strings ["Karai", "Tupã", "Mbya", "Jaguara"]
    resposta_correta: índice inteiro (0-based) da opção correta.
    """
    opcoes = models.JSONField(
        verbose_name="Opções",
        help_text='Lista de strings. Ex: ["Karai", "Tupã", "Mbya", "Jaguara"]'
    )
    resposta_correta = models.PositiveSmallIntegerField(
        verbose_name="Índice da Resposta Correta",
        help_text="Índice 0-based da opção correta. Ex: 1 → segunda opção."
    )

    class Meta:
        verbose_name = "Exercício de Múltipla Escolha"
        verbose_name_plural = "Exercícios de Múltipla Escolha"


class ExercicioCompletar(ExercicioBase):
    """
    Exercício de completar lacunas.
    texto_com_lacunas: usa ___ para marcar as lacunas. Ex: "Tupã é o ___ do trovão."
    respostas_corretas: lista de strings, uma por lacuna, na ordem de aparição.
    A validação usa unaccent + levenshtein para tolerância a typos.
    """
    texto_com_lacunas = models.TextField(
        verbose_name="Texto com Lacunas",
        help_text="Use ___ para marcar cada lacuna. Ex: 'Tupã é o ___ do trovão.'"
    )
    respostas_corretas = models.JSONField(
        verbose_name="Respostas Corretas",
        help_text='Lista de strings. Ex: ["deus"] para a lacuna acima.'
    )
    tolerancia_levenshtein = models.PositiveSmallIntegerField(
        default=2,
        verbose_name="Tolerância a Erros (Levenshtein)",
        help_text="Distância máxima permitida. 0=exato, 1=1 erro, 2=2 erros."
    )

    class Meta:
        verbose_name = "Exercício de Completar"
        verbose_name_plural = "Exercícios de Completar"


class ExercicioAssociacao(ExercicioBase):
    """
    Exercício de associar pares (ex: palavra Tupi ↔ tradução).
    coluna_esquerda: lista de strings (itens a serem associados).
    coluna_direita: lista de strings (destinos).
    associacao_correta: dict {indice_esq: indice_dir}.
    """
    coluna_esquerda = models.JSONField(
        verbose_name="Coluna da Esquerda",
        help_text='Lista de strings. Ex: ["Tupã", "Mboi"]'
    )
    coluna_direita = models.JSONField(
        verbose_name="Coluna da Direita",
        help_text='Lista de strings. Ex: ["Deus do trovão", "Serpente"]'
    )
    associacao_correta = models.JSONField(
        verbose_name="Associação Correta",
        help_text='Dict índice→índice. Ex: {"0": "0", "1": "1"}'
    )

    class Meta:
        verbose_name = "Exercício de Associação"
        verbose_name_plural = "Exercícios de Associação"


# ─── Modelo Unificado de Exercício (Supabase-friendly) ────────────────────────

class Exercicio(models.Model):
    """
    Modelo concreto e unificado de Exercício para o TupiLingo.
    Armazenado na tabela 'trilha_exercicio' no Supabase.
    Centraliza todos os tipos de exercícios (múltipla escolha, completar lacunas, associação),
    facilitando o gerenciamento direto por desenvolvedores no Table Editor do Supabase.
    """
    licao = models.ForeignKey(
        Licao,
        on_delete=models.CASCADE,
        related_name='exercicios',
        verbose_name="Lição"
    )
    story_block = models.ForeignKey(
        StoryBlock,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='exercicios',
        verbose_name="Bloco de História",
        help_text="Se preenchido, este exercício aparece dentro daquele bloco específico."
    )
    tipo = models.CharField(
        max_length=30,
        choices=TipoExercicioChoices.choices,
        verbose_name="Tipo de Exercício",
        help_text="escolha_multipla, completar ou associacao."
    )
    enunciado = models.CharField(max_length=500, verbose_name="Enunciado")
    explicacao = models.TextField(
        blank=True,
        verbose_name="Explicação",
        help_text="Exibida após o usuário responder. Explica a resposta correta com contexto cultural."
    )
    dificuldade = models.CharField(
        max_length=10,
        choices=DificuldadeChoices.choices,
        default=DificuldadeChoices.FACIL,
        verbose_name="Dificuldade"
    )
    pontos_base = models.PositiveSmallIntegerField(
        default=10,
        verbose_name="Pontos Base (XP)"
    )
    ordem = models.PositiveSmallIntegerField(
        default=0,
        verbose_name="Ordem na Lição"
    )
    midia = models.FileField(
        upload_to='exercicios/media/',
        null=True, blank=True,
        verbose_name="Mídia de Apoio",
        help_text="Imagem ou áudio de apoio ao enunciado."
    )

    # ── Campos Específicos: Múltipla Escolha ──
    opcoes = models.JSONField(
        null=True, blank=True,
        verbose_name="Opções de Múltipla Escolha",
        help_text='Lista de strings. Ex: ["Kauê", "Pirá", "Tupã", "Taba"]'
    )
    resposta_correta = models.PositiveSmallIntegerField(
        null=True, blank=True,
        verbose_name="Índice da Resposta Correta",
        help_text="Índice 0-based da opção correta. Ex: 0 para a primeira."
    )

    # ── Campos Específicos: Completar Lacunas ──
    texto_com_lacunas = models.TextField(
        null=True, blank=True,
        verbose_name="Texto com Lacunas",
        help_text="Use ___ para marcar cada lacuna. Ex: 'Ao avistar um amigo: \"___!\"'"
    )
    respostas_corretas = models.JSONField(
        null=True, blank=True,
        verbose_name="Respostas Corretas (Lacunas)",
        help_text='Lista de strings com respostas aceitas. Ex: ["Kauê"]'
    )
    tolerancia_levenshtein = models.PositiveSmallIntegerField(
        default=2,
        null=True, blank=True,
        verbose_name="Tolerância a Erros (Levenshtein)",
        help_text="Distância máxima permitida para typos. 0=exato, 1=1 erro, 2=2 erros."
    )

    # ── Campos Específicos: Associação de Pares ──
    coluna_esquerda = models.JSONField(
        null=True, blank=True,
        verbose_name="Coluna da Esquerda",
        help_text='Lista de strings. Ex: ["Kauê", "Kunhã", "Taba"]'
    )
    coluna_direita = models.JSONField(
        null=True, blank=True,
        verbose_name="Coluna da Direita",
        help_text='Lista de strings. Ex: ["Aldeia", "Olá", "Mulher"]'
    )
    associacao_correta = models.JSONField(
        null=True, blank=True,
        verbose_name="Associação Correta",
        help_text='Dict índice->índice. Ex: {"0": "1", "1": "2", "2": "0"}'
    )

    class Meta:
        db_table = 'trilha_exercicio'
        verbose_name = "Exercício Unificado"
        verbose_name_plural = "Exercícios Unificados"
        ordering = ['licao', 'ordem']

    def __str__(self):
        return f"[{self.licao.titulo} | {self.get_tipo_display()}] {self.enunciado[:40]}..."


# ─── UserChestReward ──────────────────────────────────────────────────────────

class UserChestReward(models.Model):
    """
    Rastreia os baús culturais de capítulo coletados pelo usuário.
    Garante que cada marco (milestone) de baú só possa ser coletado uma única vez.
    """
    user = models.ForeignKey(
        'users.UserProfile',
        on_delete=models.CASCADE,
        related_name='chests_coletados',
        verbose_name="Usuário"
    )
    capitulo = models.ForeignKey(
        Capitulo,
        on_delete=models.CASCADE,
        related_name='chests_coletados',
        verbose_name="Capítulo"
    )
    milestone_index = models.IntegerField(default=1, verbose_name="Índice do Marco na Trilha")
    recompensa_xp = models.IntegerField(default=75, verbose_name="XP da Recompensa")
    recompensa_conchas = models.IntegerField(default=50, verbose_name="Conchas da Recompensa")
    coletado_em = models.DateTimeField(auto_now_add=True, verbose_name="Coletado em")

    class Meta:
        db_table = 'trilha_userchestreward'
        verbose_name = "Baú Coletado pelo Usuário"
        verbose_name_plural = "Baús Coletados pelos Usuários"
        unique_together = ('user', 'capitulo', 'milestone_index')
        indexes = [
            models.Index(fields=['user', 'capitulo'], name='idx_userchest_user_cap'),
        ]

    def __str__(self):
        return f"{self.user.name} - Cap {self.capitulo.numero} (Marco {self.milestone_index})"
