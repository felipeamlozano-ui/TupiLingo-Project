# urls.py do app users
from django.urls import path
from . import views
from . import views_proto

urlpatterns = [
    path('auth/check-user', views.check_user, name='check_user'),
    path('auth/register-user', views.register_user, name='register_user'),
    path('auth/update-variante', views.update_variante_ativa, name='update_variante_ativa'),
    path('auth/profile', views.get_profile, name='get_profile'),
    path('auth/profile/proto', views_proto.get_user_profile_proto, name='get_user_profile_proto'),
    path('admin/me', views.admin_check, name='admin_check'),
    path('dashboard/stats/', views.dashboard_stats, name='dashboard_stats'),
    path('profile/', views.dashboard_stats, name='profile_stats_compat'),
]