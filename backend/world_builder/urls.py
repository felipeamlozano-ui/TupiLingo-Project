from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    TerritoryViewSet,
    VillageViewSet,
    RiverViewSet,
    TrailViewSet,
    TimelineEpochViewSet,
    HistoricalOverlayViewSet,
    QuestViewSet,
    get_active_world_bundle,
    publish_world_version,
    rollback_world_version,
)

router = DefaultRouter()
router.register(r'territories', TerritoryViewSet, basename='territory')
router.register(r'villages', VillageViewSet, basename='village')
router.register(r'rivers', RiverViewSet, basename='river')
router.register(r'trails', TrailViewSet, basename='trail')
router.register(r'epochs', TimelineEpochViewSet, basename='epoch')
router.register(r'overlays', HistoricalOverlayViewSet, basename='overlay')
router.register(r'quests', QuestViewSet, basename='quest')

urlpatterns = [
    path('active/', get_active_world_bundle, name='active-world-bundle'),
    path('publish/', publish_world_version, name='publish-world-version'),
    path('rollback/', rollback_world_version, name='rollback-world-version'),
    path('', include(router.urls)),
]
