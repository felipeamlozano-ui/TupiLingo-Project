# urls.py do projeto
# URLS-001: prefixo /api/v1/ adicionado para versionamento de API
from django.contrib import admin
from django.urls import path, include
from django.http import JsonResponse

def ping(request):
    return JsonResponse({"status": "ok"})

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/health/', ping, name='health-check'),
    path('api/v1/', include('users.urls')),
    path('api/v1/', include('nivelamento.urls')),
]