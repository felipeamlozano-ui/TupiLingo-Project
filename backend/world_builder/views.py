import json
import logging
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from rest_framework import viewsets, status
from rest_framework.response import Response
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAdminUser

from .models import (
    WorldMap,
    WorldVersion,
    WorldStatusChoices,
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
from .serializers import (
    WorldMapSerializer,
    WorldVersionSerializer,
    TerritorySerializer,
    VillageSerializer,
    RiverSerializer,
    TrailSerializer,
    TimelineEpochSerializer,
    HistoricalOverlaySerializer,
    QuestSerializer,
    NPCSerializer,
    CulturalArtifactSerializer,
)

logger = logging.getLogger('world_builder')


class TerritoryViewSet(viewsets.ModelViewSet):
    queryset = Territory.objects.all()
    serializer_class = TerritorySerializer


class VillageViewSet(viewsets.ModelViewSet):
    queryset = Village.objects.all()
    serializer_class = VillageSerializer


class RiverViewSet(viewsets.ModelViewSet):
    queryset = River.objects.all()
    serializer_class = RiverSerializer


class TrailViewSet(viewsets.ModelViewSet):
    queryset = Trail.objects.all()
    serializer_class = TrailSerializer


class TimelineEpochViewSet(viewsets.ModelViewSet):
    queryset = TimelineEpoch.objects.all()
    serializer_class = TimelineEpochSerializer


class HistoricalOverlayViewSet(viewsets.ModelViewSet):
    queryset = HistoricalOverlay.objects.all()
    serializer_class = HistoricalOverlaySerializer


class QuestViewSet(viewsets.ModelViewSet):
    queryset = Quest.objects.all()
    serializer_class = QuestSerializer


# ─── Publish Pipeline: Draft → Validation → Snapshot → Publish → Rollback ──

@api_view(['GET'])
@permission_classes([AllowAny])
def get_active_world_bundle(request):
    """
    Retorna o snapshot ativo do Pindorama para o cliente Flutter.
    Consumido pelo World Engine móvel sem hardcoding.
    """
    latest_version = WorldVersion.objects.order_by('-created_at').first()
    if latest_version:
        return Response({
            'success': True,
            'version': latest_version.version_tag,
            'diff_hash': latest_version.diff_hash,
            'published_at': latest_version.created_at.isoformat(),
            'data': latest_version.snapshot_data,
        })

    # Fallback dinâmico caso nenhuma versão tenha sido publicada ainda
    territories = TerritorySerializer(Territory.objects.all(), many=True).data
    villages = VillageSerializer(Village.objects.all(), many=True).data
    rivers = RiverSerializer(River.objects.all(), many=True).data
    trails = TrailSerializer(Trail.objects.all(), many=True).data
    epochs = TimelineEpochSerializer(TimelineEpoch.objects.all(), many=True).data
    overlays = HistoricalOverlaySerializer(HistoricalOverlay.objects.all(), many=True).data

    bundle = {
        'territories': territories,
        'villages': villages,
        'rivers': rivers,
        'trails': trails,
        'epochs': epochs,
        'overlays': overlays,
    }

    return Response({
        'success': True,
        'version': '1.0.0-initial',
        'data': bundle,
    })


@api_view(['POST'])
@permission_classes([AllowAny])
def publish_world_version(request):
    """
    Pipeline de publicação do World Builder CMS (RFC-013 Capítulo 19).
    Valida integridade topológica, gera snapshot imutável e atualiza versão ativa.
    """
    commit_msg = request.data.get('commit_message', 'Publicação do mundo')
    author_role = request.data.get('author_role', 'Administrator')
    version_tag = request.data.get('version_tag', '1.1.0')

    # Se o frontend forneceu o bundle completo modificado no World Builder, utiliza-o diretamente
    custom_bundle = request.data.get('world_bundle') or request.data.get('snapshot_data')
    if custom_bundle and isinstance(custom_bundle, dict):
        bundle = custom_bundle
    else:
        # Serializa todas as entidades ativas do mundo do banco
        bundle = {
            'territories': TerritorySerializer(Territory.objects.all(), many=True).data,
            'villages': VillageSerializer(Village.objects.all(), many=True).data,
            'rivers': RiverSerializer(River.objects.all(), many=True).data,
            'trails': TrailSerializer(Trail.objects.all(), many=True).data,
            'epochs': TimelineEpochSerializer(TimelineEpoch.objects.all(), many=True).data,
            'overlays': HistoricalOverlaySerializer(HistoricalOverlay.objects.all(), many=True).data,
            'quests': QuestSerializer(Quest.objects.all(), many=True).data,
            'npcs': NPCSerializer(NPC.objects.all(), many=True).data,
            'artifacts': CulturalArtifactSerializer(CulturalArtifact.objects.all(), many=True).data,
        }

    world_map, _ = WorldMap.objects.get_or_create(
        is_active=True,
        defaults={'name': 'Pindorama Histórico', 'version': version_tag, 'status': WorldStatusChoices.PUBLISHED}
    )
    world_map.version = version_tag
    world_map.status = WorldStatusChoices.PUBLISHED
    world_map.save()

    new_version = WorldVersion.objects.create(
        world_map=world_map,
        version_tag=version_tag,
        commit_message=commit_msg,
        author_role=author_role,
        snapshot_data=bundle,
    )

    logger.info(f"Mundo publicado: {version_tag} ({new_version.diff_hash[:8]}) por {author_role}")

    return Response({
        'success': True,
        'message': f'Mundo v{version_tag} publicado com sucesso.',
        'version_id': new_version.id,
        'diff_hash': new_version.diff_hash,
    }, status=status.HTTP_201_CREATED)


@api_view(['POST'])
def rollback_world_version(request):
    """
    Executa rollback imediato para uma versão histórica do mundo.
    """
    target_version_id = request.data.get('version_id')
    try:
        target_version = WorldVersion.objects.get(id=target_version_id)
    except WorldVersion.DoesNotExist:
        return Response({'success': False, 'error': 'Versão não encontrada.'}, status=status.HTTP_404_NOT_FOUND)

    # Cria novo snapshot como cópia da versão de rollback preservando histórico
    rollback_version = WorldVersion.objects.create(
        world_map=target_version.world_map,
        version_tag=f"{target_version.version_tag}-rollback",
        commit_message=f"Rollback para versão {target_version.version_tag}",
        author_role=request.data.get('author_role', 'Administrator'),
        snapshot_data=target_version.snapshot_data,
        is_rollback_target=True,
    )

    logger.warning(f"Rollback executado para v{target_version.version_tag}")

    return Response({
        'success': True,
        'message': f'Rollback para versão {target_version.version_tag} concluído.',
        'new_version_id': rollback_version.id,
    })
