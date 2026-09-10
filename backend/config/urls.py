# urls.py do projeto
# URLS-001: prefixo /api/v1/ adicionado para versionamento de API
from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.http import JsonResponse
from django.urls import include, path


def ping(request):
    return JsonResponse({"status": "ok"})

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/health/', ping, name='health-check'),
    path('api/v1/', include('users.urls')),
    path('api/v1/', include('nivelamento.urls')),
    path('api/v1/', include('trilha.urls')),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)