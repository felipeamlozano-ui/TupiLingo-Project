from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    AggregatedMetricsViewSet,
    PerformanceSnapshotViewSet,
    FeatureFlagViewSet,
    AuditLogViewSet,
    ServiceHealthViewSet,
    CrashClusterViewSet,
    record_client_telemetry,
    get_system_overview,
)

router = DefaultRouter()
router.register(r'metrics', AggregatedMetricsViewSet, basename='metrics')
router.register(r'snapshots', PerformanceSnapshotViewSet, basename='snapshot')
router.register(r'flags', FeatureFlagViewSet, basename='flag')
router.register(r'audit-logs', AuditLogViewSet, basename='audit-log')
router.register(r'health', ServiceHealthViewSet, basename='health')
router.register(r'crashes', CrashClusterViewSet, basename='crash')

urlpatterns = [
    path('record/', record_client_telemetry, name='record-telemetry'),
    path('overview/', get_system_overview, name='system-overview'),
    path('', include(router.urls)),
]
