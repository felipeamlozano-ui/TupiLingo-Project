from rest_framework import serializers
from .models import (
    AggregatedMetrics,
    PerformanceSnapshot,
    FeatureFlag,
    AuditLog,
    ServiceHealth,
    CrashCluster,
)


class AggregatedMetricsSerializer(serializers.ModelSerializer):
    class Meta:
        model = AggregatedMetrics
        fields = '__all__'


class PerformanceSnapshotSerializer(serializers.ModelSerializer):
    class Meta:
        model = PerformanceSnapshot
        fields = '__all__'


class FeatureFlagSerializer(serializers.ModelSerializer):
    class Meta:
        model = FeatureFlag
        fields = '__all__'


class AuditLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = AuditLog
        fields = '__all__'
        read_only_fields = ('signature_hash', 'timestamp')


class ServiceHealthSerializer(serializers.ModelSerializer):
    class Meta:
        model = ServiceHealth
        fields = '__all__'


class CrashClusterSerializer(serializers.ModelSerializer):
    class Meta:
        model = CrashCluster
        fields = '__all__'
