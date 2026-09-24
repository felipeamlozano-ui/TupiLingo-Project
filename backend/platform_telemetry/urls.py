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
    request_dev_otp,
    verify_dev_otp,
    check_dev_session_status,
    revoke_dev_session_view,
    ping_presence,
    toggle_feature_flag,
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
    path('auth/otp/request/', request_dev_otp, name='request-dev-otp'),
    path('auth/otp/verify/', verify_dev_otp, name='verify-dev-otp'),
    path('auth/otp/check-session/', check_dev_session_status, name='check-dev-session'),
    path('auth/otp/revoke-session/', revoke_dev_session_view, name='revoke-dev-session'),
    path('presence/ping/', ping_presence, name='ping-presence'),
    path('flags/toggle/', toggle_feature_flag, name='toggle-feature-flag'),
    path('', include(router.urls)),
]
