import logging
from django.utils import timezone
from rest_framework import viewsets, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAdminUser
from rest_framework.response import Response

from .models import (
    AggregatedMetrics,
    PerformanceSnapshot,
    FeatureFlag,
    AuditLog,
    ServiceHealth,
    CrashCluster,
    HealthStatusChoices,
)
from .serializers import (
    AggregatedMetricsSerializer,
    PerformanceSnapshotSerializer,
    FeatureFlagSerializer,
    AuditLogSerializer,
    ServiceHealthSerializer,
    CrashClusterSerializer,
)

logger = logging.getLogger('platform_telemetry')


class AggregatedMetricsViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = AggregatedMetrics.objects.all()
    serializer_class = AggregatedMetricsSerializer


class PerformanceSnapshotViewSet(viewsets.ModelViewSet):
    queryset = PerformanceSnapshot.objects.all()
    serializer_class = PerformanceSnapshotSerializer


class FeatureFlagViewSet(viewsets.ModelViewSet):
    queryset = FeatureFlag.objects.all()
    serializer_class = FeatureFlagSerializer


class AuditLogViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = AuditLog.objects.all()
    serializer_class = AuditLogSerializer


class ServiceHealthViewSet(viewsets.ModelViewSet):
    queryset = ServiceHealth.objects.all()
    serializer_class = ServiceHealthSerializer


class CrashClusterViewSet(viewsets.ModelViewSet):
    queryset = CrashCluster.objects.all()
    serializer_class = CrashClusterSerializer


@api_view(['POST'])
@permission_classes([AllowAny])
def record_client_telemetry(request):
    """
    Ingere telemetria do cliente Flutter com garantia estrita ZERO-PII.
    Descarta qualquer chave sensível antes de processar.
    """
    data = request.data
    # PII Filter passivo: descarta nomes, emails, uids, ips, tokens
    forbidden_keys = {'user_id', 'email', 'name', 'token', 'jwt', 'ip', 'coordinates', 'location'}
    sanitized = {k: v for k, v in data.items() if k.lower() not in forbidden_keys}

    device_class = sanitized.get('device_class', 'mid')
    avg_fps = float(sanitized.get('avg_fps', 60.0))
    frame_drops_pct = float(sanitized.get('frame_drops_pct', 0.0))
    memory_mb = float(sanitized.get('memory_mb', 180.0))
    gpu_tier = sanitized.get('gpu_tier', 'impeller-vulkan')

    PerformanceSnapshot.objects.create(
        device_class=device_class,
        avg_fps=avg_fps,
        frame_drops_pct=frame_drops_pct,
        memory_mb=memory_mb,
        gpu_tier=gpu_tier,
        sample_count=1,
    )

    return Response({
        'success': True,
        'message': 'Telemetria anônima gravada com sucesso.',
    }, status=status.HTTP_201_CREATED)


@api_view(['GET'])
@permission_classes([AllowAny])
def get_system_overview(request):
    """
    Retorna panorama consolidado para Developer Console & Security Console.
    """
    # Seed default services if none exist
    if not ServiceHealth.objects.exists():
        defaults = [
            ('Django Core API', HealthStatusChoices.HEALTHY, 14.2, 11.5, 34.0, 99.99),
            ('Supabase PostgreSQL', HealthStatusChoices.HEALTHY, 8.4, 18.0, 42.0, 99.99),
            ('LiteLLM Proxy Router', HealthStatusChoices.HEALTHY, 85.0, 22.0, 48.0, 99.95),
            ('TimescaleDB Telemetry', HealthStatusChoices.HEALTHY, 12.0, 9.0, 25.0, 99.99),
            ('Redis Cache Cluster', HealthStatusChoices.HEALTHY, 2.1, 5.0, 18.0, 100.0),
        ]
        for name, st, lat, cpu, mem, up in defaults:
            ServiceHealth.objects.get_or_create(
                service_name=name,
                defaults={'status': st, 'latency_ms': lat, 'cpu_pct': cpu, 'memory_pct': mem, 'uptime_pct': up}
            )

    # Seed default feature flags if none exist
    if not FeatureFlag.objects.exists():
        flags = [
            ('pindorama_particles_v2', 'Efeitos de Partículas Avançados', 'Ativa renderização de vaga-lumes e névoa viva', True, 100),
            ('impeller_dynamic_lod', 'LOD Dinâmico do Impeller', 'Adapta nível de detalhe dos rios conforme framerate', True, 100),
            ('ai_adaptive_feedback', 'Feedback de IA Adaptativo', 'Geração dinâmica de dicas linguísticas via LiteLLM', True, 100),
            ('offline_pindorama_cache', 'Cache Offline de Pindorama', 'Permite exploração do mapa histórico sem internet', True, 100),
        ]
        for key, name, desc, en, roll in flags:
            FeatureFlag.objects.get_or_create(
                key=key,
                defaults={'name': name, 'description': desc, 'is_enabled': en, 'rollout_percentage': roll}
            )

    services = ServiceHealthSerializer(ServiceHealth.objects.all(), many=True).data
    flags = FeatureFlagSerializer(FeatureFlag.objects.all(), many=True).data
    recent_metrics = AggregatedMetricsSerializer(AggregatedMetrics.objects.order_by('-created_at')[:10], many=True).data
    recent_logs = AuditLogSerializer(AuditLog.objects.order_by('-timestamp')[:20], many=True).data
    crashes = CrashClusterSerializer(CrashCluster.objects.filter(is_resolved=False)[:5], many=True).data

    return Response({
        'success': True,
        'services': services,
        'feature_flags': flags,
        'recent_metrics': recent_metrics,
        'recent_audit_logs': recent_logs,
        'active_crashes': crashes,
        'timestamp': timezone.now().isoformat(),
    })
