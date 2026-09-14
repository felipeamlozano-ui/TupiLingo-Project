import hashlib
import json
from django.db import models


class WorldStatusChoices(models.TextChoices):
    DRAFT = 'draft', 'Rascunho'
    PREVIEW = 'preview', 'Homologação'
    PUBLISHED = 'published', 'Publicado'
    ARCHIVED = 'archived', 'Arquivado'


class WorldMap(models.Model):
    name = models.CharField(max_length=150, default='Pindorama Histórico')
    version = models.CharField(max_length=50, default='1.0.0')
    status = models.CharField(
        max_length=20,
        choices=WorldStatusChoices.choices,
        default=WorldStatusChoices.DRAFT,
    )
    width = models.FloatField(default=10000.0)
    height = models.FloatField(default=10000.0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-updated_at']

    def __str__(self):
        return f"{self.name} v{self.version} ({self.status})"


class WorldVersion(models.Model):
    world_map = models.ForeignKey(WorldMap, on_delete=models.CASCADE, related_name='versions')
    version_tag = models.CharField(max_length=50)
    commit_message = models.TextField(default='Atualização do mundo')
    author_role = models.CharField(max_length=100, default='Content Editor')
    snapshot_data = models.JSONField(help_text='JSON completo contendo todas as entidades da versão')
    diff_hash = models.CharField(max_length=64, blank=True)
    is_rollback_target = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def save(self, *args, **kwargs):
        if not self.diff_hash:
            data_str = json.dumps(self.snapshot_data, sort_keys=True)
            self.diff_hash = hashlib.sha256(data_str.encode('utf-8')).hexdigest()
        super().save(*args, **kwargs)

    def __str__(self):
        return f"Version {self.version_tag} ({self.diff_hash[:8]})"


class Territory(models.Model):
    world_map = models.ForeignKey(WorldMap, on_delete=models.CASCADE, related_name='territories', null=True, blank=True)
    slug = models.SlugField(max_length=100, unique=True)
    name = models.CharField(max_length=200)
    tupi_name = models.CharField(max_length=200)
    historical_period = models.CharField(max_length=100, default='Século XVI')
    primary_dialect = models.CharField(max_length=100, default='Tupi Clássico')
    biome = models.CharField(max_length=50, default='mataAtlantica')
    completion_xp = models.IntegerField(default=350)
    center_x = models.FloatField(default=5000.0)
    center_y = models.FloatField(default=5000.0)
    polygon_points = models.JSONField(default=list, help_text='Lista de [x, y] definindo a fronteira geográfica')
    is_unlocked = models.BooleanField(default=True)
    order_index = models.IntegerField(default=0)

    class Meta:
        ordering = ['order_index', 'name']

    def __str__(self):
        return f"{self.name} ({self.tupi_name})"


class Village(models.Model):
    territory = models.ForeignKey(Territory, on_delete=models.CASCADE, related_name='villages', null=True, blank=True)
    slug = models.SlugField(max_length=100, unique=True)
    name = models.CharField(max_length=200)
    tupi_name = models.CharField(max_length=200)
    x = models.FloatField(default=5000.0)
    y = models.FloatField(default=5000.0)
    evolution_stage = models.IntegerField(default=2, help_text='0: Oculta, 1: Descoberta, 2: Explorada, 3: Dominada, 4/5: Histórica/Viva')
    resident_count = models.IntegerField(default=250)
    dialect_variant = models.CharField(max_length=100, default='Tupi Antigo')
    leader_name = models.CharField(max_length=150, default='Cacique Ancestral')
    historical_context = models.TextField(blank=True)
    has_boss_challenge = models.BooleanField(default=False)
    is_unlocked = models.BooleanField(default=True)
    active_epochs = models.JSONField(default=list, help_text='Lista de IDs das épocas históricas visíveis')

    class Meta:
        ordering = ['name']

    def __str__(self):
        return f"{self.tupi_name} / {self.name}"


class River(models.Model):
    slug = models.SlugField(max_length=100, unique=True)
    name = models.CharField(max_length=200)
    tupi_name = models.CharField(max_length=200)
    spring_x = models.FloatField(default=4000.0)
    spring_y = models.FloatField(default=4500.0)
    estuary_x = models.FloatField(default=6000.0)
    estuary_y = models.FloatField(default=5500.0)
    control_points = models.JSONField(default=list, help_text='Array de segmentos Bézier cúbicos com largura dinâmica')
    max_width = models.FloatField(default=35.0)
    flow_speed = models.FloatField(default=1.0)

    def __str__(self):
        return f"Rio {self.name} ({self.tupi_name})"


class Trail(models.Model):
    slug = models.SlugField(max_length=100, unique=True)
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    waypoints = models.JSONField(default=list, help_text='Lista ordenada de coordenadas [x, y]')
    is_discovered = models.BooleanField(default=True)
    color_hex = models.CharField(max_length=10, default='#E5A93C')
    stroke_width = models.FloatField(default=2.5)
    historical_period = models.CharField(max_length=100, default='Pré-1500')

    def __str__(self):
        return f"Trilha: {self.name}"


class TimelineEpoch(models.Model):
    slug = models.SlugField(max_length=50, unique=True)
    label = models.CharField(max_length=50)
    title = models.CharField(max_length=200)
    description = models.TextField()
    order_index = models.IntegerField(default=0)
    active_territory_slugs = models.JSONField(default=list)
    active_alliance_slugs = models.JSONField(default=list)

    class Meta:
        ordering = ['order_index']

    def __str__(self):
        return f"Época {self.label}: {self.title}"


class HistoricalOverlay(models.Model):
    slug = models.SlugField(max_length=100, unique=True)
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    overlay_type = models.CharField(max_length=50, default='alliance')
    epoch = models.ForeignKey(TimelineEpoch, on_delete=models.CASCADE, related_name='overlays', null=True, blank=True)
    polygon_points = models.JSONField(default=list)
    base_color_hex = models.CharField(max_length=10, default='#E53935')

    def __str__(self):
        return f"Overlay: {self.title}"


class Quest(models.Model):
    slug = models.SlugField(max_length=100, unique=True)
    title = models.CharField(max_length=200)
    description = models.TextField()
    is_main = models.BooleanField(default=True)
    village = models.ForeignKey(Village, on_delete=models.CASCADE, related_name='quests', null=True, blank=True)
    target_x = models.FloatField(default=5000.0)
    target_y = models.FloatField(default=5000.0)
    reward_xp = models.IntegerField(default=150)

    def __str__(self):
        return f"Quest: {self.title} ({'+%d XP' % self.reward_xp})"


class NPC(models.Model):
    name = models.CharField(max_length=150)
    indigenous_nation = models.CharField(max_length=100)
    epoch = models.CharField(max_length=50, default='1554')
    lore = models.TextField()
    dialogue_greeting = models.CharField(max_length=255, default='Kauê!')
    village = models.ForeignKey(Village, on_delete=models.SET_NULL, null=True, blank=True, related_name='npcs')

    def __str__(self):
        return f"{self.name} ({self.indigenous_nation})"


class CulturalArtifact(models.Model):
    slug = models.SlugField(max_length=100, unique=True)
    title = models.CharField(max_length=200)
    artifact_name = models.CharField(max_length=200)
    tupi_lore = models.TextField()
    village = models.ForeignKey(Village, on_delete=models.SET_NULL, null=True, blank=True, related_name='artifacts')
    xp_bonus = models.IntegerField(default=100)

    def __str__(self):
        return f"Artefato: {self.title}"
