# urls.py do app users
from django.urls import path
from . import views

urlpatterns = [
    path('auth/check-user', views.check_user, name='check_user'),
    path('auth/register-user', views.register_user, name='register_user'),
    path('auth/update-level', views.update_level, name='update_level'),
]