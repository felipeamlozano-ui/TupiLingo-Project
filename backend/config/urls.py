# urls.py do projeto
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('users.urls')), # O caminho deve estar aqui!
    path('', include('nivelamento.urls')),
]