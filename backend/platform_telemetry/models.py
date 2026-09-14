import hashlib
import json
from django.db import models
from django.utils import timezone


class HealthStatusChoices(models.TextChoices):
    HEALTHY = 'HEALTHY', 'Healthy'
    DEGRADED = 'DEGRADED', 'Degraded'
    OUTAGE = 'OUTAGE', 'Outage'


class AggregatedMetrics(models.Model):
    """
    Métricas de telemetria agregadas (RFC-013 Capítulo 20/21).
    STRICT ZERO-PII GUARANTEE: Nunca armazena IPs, UIDs, dados cadastrais ou respostas de usuários.
    """
    window_start = models.DateTimeField(default=timezone.now)
    window_end = models.DateTimeField(default=timezone.now)
    active_sessions_count = models.PositiveIntegerField(default=0)
    avg_fps = models.FloatField(default=60.0)
    avg_frame_time_ms = models.FloatField(default=16.6)
    raster_thread_time_ms = models.FloatField(default=5.2)
    ui_thread_time_ms = models.FloatField(default=6.1)
    p95_latency_ms = models.FloatField(default=120.0)
    cache_hit_rate = models.FloatField(default=0.92)
    active_biomes_count = models.PositiveIntegerField(default=1)
    quests_completed_hourly = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = 'Métrica Agregada'
        verbose_name_plural = 'Métricas Agregadas'
        ordering = ['-created_at']

    def __str__(self):
        return f"Telemetry {self.window_start.strftime('%Y-%m-%d %H:%M')} - FPS: {self.avg_fps:.1f} - Sessions: {self.active_sessions_count}"


class PerformanceSnapshot(models.Model):
    """
    Snapshot anônimo de desempenho por classe de dispositivo.
    """
    device_class = models.CharField(max_length=50, default='mid')  # 'low', 'mid', 'high', 'flagship'
    avg_fps = models.FloatField(default=60.0)
    frame_drops_pct = models.FloatField(default=0.5)
    memory_mb = models.FloatField(default=180.0)
    gpu_tier = models.CharField(max_length=100, default='impeller-vulkan')
    sample_count = models.PositiveIntegerField(default=1)
    recorded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = 'Snapshot de Desempenho'
        verbose_name_plural = 'Snapshots de Desempenho'
        ordering = ['-recorded_at']


class FeatureFlag(models.Model):
    """
    Feature Flags de Runtime para ativação dinâmica no Flutter.
    """
    key = models.CharField(max_length=100, unique=True)
    name = models.CharField(max_length=150)
    description = models.TextField(blank=True, default='')
    is_enabled = models.BooleanField(default=False)
    rollout_percentage = models.PositiveIntegerField(default=100)
    target_device_classes = models.JSONField(default=list, blank=True)
    target_app_versions = models.JSONField(default=list, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Feature Flag'
        verbose_name_plural = 'Feature Flags'
        ordering = ['key']

    def __str__(self):
        status_str = 'ON' if self.is_enabled else 'OFF'
        return f"[{status_str}] {self.key} ({self.rollout_percentage}%)"


class AuditLog(models.Model):
    """
    Trilha de auditoria imutável com encadeamento criptográfico SHA-256 (RFC-013 Capítulo 21).
    Garante compliance LGPD e integridade de alterações administrativas.
    """
    action = models.CharField(max_length=100)
    entity_type = models.CharField(max_length=100)
    entity_id = models.CharField(max_length=100, blank=True, default='')
    actor_role = models.CharField(max_length=100, default='Administrator')
    ip_hash = models.CharField(max_length=64, blank=True, default='')
    changes = models.JSONField(default=dict, blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)
    signature_hash = models.CharField(max_length=64, blank=True, default='')

    class Meta:
        verbose_name = 'Log de Auditoria'
        verbose_name_plural = 'Logs de Auditoria'
        ordering = ['-timestamp']

    def save(self, *args, **kwargs):
        if not self.signature_hash:
            prev_log = AuditLog.objects.order_by('-timestamp').first()
            prev_hash = prev_log.signature_hash if prev_log else 'GENESIS_ROOT_HASH'
            payload = f"{self.action}:{self.entity_type}:{self.entity_id}:{self.actor_role}:{json.dumps(self.changes, sort_keys=True)}:{prev_hash}"
            self.signature_hash = hashlib.sha256(payload.encode('utf-8')).hexdigest()
        super().save(*args, **kwargs)


class ServiceHealth(models.Model):
    """
    Monitor de saúde SRE para serviços essenciais (Django, Supabase, LiteLLM, Redis, TimescaleDB).
    """
    service_name = models.CharField(max_length=100, unique=True)
    status = models.CharField(
        max_length=20,
        choices=HealthStatusChoices.choices,
        default=HealthStatusChoices.HEALTHY,
    )
    latency_ms = models.FloatField(default=15.0)
    cpu_pct = models.FloatField(default=12.0)
    memory_pct = models.FloatField(default=35.0)
    uptime_pct = models.FloatField(default=99.98)
    last_heartbeat = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Saúde de Serviço'
        verbose_name_plural = 'Saúde de Serviços'
        ordering = ['service_name']

    def __str__(self):
        return f"{self.service_name} [{self.status}] ({self.latency_ms:.1f}ms)"


class CrashCluster(models.Model):
    """
    Inteligência de Falhas anônima agrupada por impressão digital de erro.
    """
    fingerprint = models.CharField(max_length=64, unique=True)
    error_type = models.CharField(max_length=150)
    exception_message = models.TextField()
    impacted_users_approx = models.PositiveIntegerField(default=1)
    occurrences_count = models.PositiveIntegerField(default=1)
    first_seen = models.DateTimeField(auto_now_add=True)
    last_seen = models.DateTimeField(auto_now=True)
    stacktrace_summary = models.TextField(blank=True, default='')
    is_resolved = models.BooleanField(default=False)

    class Meta:
        verbose_name = 'Cluster de Falha'
        verbose_name_plural = 'Clusters de Falhas'
        ordering = ['-occurrences_count', '-last_seen']

    def __str__(self):
        return f"{self.error_type} ({self.occurrences_count}x) - {'Resolvido' if self.is_resolved else 'Ativo'}"
