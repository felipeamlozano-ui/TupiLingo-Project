from rest_framework import serializers
from .models import (
    WorldMap,
    WorldVersion,
    Territory,
    Village,
    River,
    Trail,
    TimelineEpoch,
    HistoricalOverlay,
    Quest,
    NPC,
    CulturalArtifact,
)


class TerritorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Territory
        fields = '__all__'


class VillageSerializer(serializers.ModelSerializer):
    class Meta:
        model = Village
        fields = '__all__'


class RiverSerializer(serializers.ModelSerializer):
    class Meta:
        model = River
        fields = '__all__'


class TrailSerializer(serializers.ModelSerializer):
    class Meta:
        model = Trail
        fields = '__all__'


class TimelineEpochSerializer(serializers.ModelSerializer):
    class Meta:
        model = TimelineEpoch
        fields = '__all__'


class HistoricalOverlaySerializer(serializers.ModelSerializer):
    class Meta:
        model = HistoricalOverlay
        fields = '__all__'


class QuestSerializer(serializers.ModelSerializer):
    class Meta:
        model = Quest
        fields = '__all__'


class NPCSerializer(serializers.ModelSerializer):
    class Meta:
        model = NPC
        fields = '__all__'


class CulturalArtifactSerializer(serializers.ModelSerializer):
    class Meta:
        model = CulturalArtifact
        fields = '__all__'


class WorldVersionSerializer(serializers.ModelSerializer):
    class Meta:
        model = WorldVersion
        fields = '__all__'


class WorldMapSerializer(serializers.ModelSerializer):
    territories = TerritorySerializer(many=True, read_only=True)

    class Meta:
        model = WorldMap
        fields = '__all__'
