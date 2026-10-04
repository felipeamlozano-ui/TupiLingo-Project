# Rotas centrais da API TupiLingo
from django.contrib import admin
from django.urls import path, include
from django.http import JsonResponse
from django.conf import settings
from django.conf.urls.static import static

def ping(request):
    return JsonResponse({"status": "ok"})

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/health/', ping, name='health-check'),
    path('api/v1/', include('users.urls')),
    path('api/v1/', include('nivelamento.urls')),
    path('api/v1/', include('trilha.urls')),
    # path('api/v1/world/', include('world_builder.urls')),  # Pindorama 3D (em desenvolvimento para expansão futura)
    path('api/v1/platform/', include('platform_telemetry.urls')),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)