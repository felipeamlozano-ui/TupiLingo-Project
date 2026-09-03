# urls.py do app users
from django.urls import path
from . import views

urlpatterns = [
    path('auth/check-user', views.check_user, name='check_user'),
    path('auth/register-user', views.register_user, name='register_user'),
    path('auth/update-variante', views.update_variante_ativa, name='update_variante_ativa'),
    path('auth/profile', views.get_profile, name='get_profile'),
]