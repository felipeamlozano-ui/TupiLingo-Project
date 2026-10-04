# urls.py do app users
from django.urls import path
from . import views
from . import views_auth
from . import views_proto
from . import views_store

urlpatterns = [
    # Rotas de Autenticação Central
    path('auth/login', views_auth.login_user, name='auth_login'),
    path('auth/register', views_auth.register_account, name='auth_register'),
    path('auth/recover-password', views_auth.recover_password, name='auth_recover_password'),
    path('auth/resend-code', views_auth.resend_code, name='auth_resend_code'),
    
    # Rotas de Perfil e Estado de Usuário
    path('auth/check-user', views.check_user, name='check_user'),
    path('auth/register-user', views.register_user, name='register_user'),
    path('auth/update-variante', views.update_variante_ativa, name='update_variante_ativa'),
    path('auth/profile', views.get_profile, name='get_profile'),
    path('auth/profile/proto', views_proto.get_user_profile_proto, name='get_user_profile_proto'),
    path('admin/me', views.admin_check, name='admin_check'),
    path('dashboard/stats/', views.dashboard_stats, name='dashboard_stats'),
    path('profile/', views.dashboard_stats, name='profile_stats_compat'),
    # Loja de Conchas & Cosméticos (Demanda 2)
    path('store/catalog/', views_store.get_store_catalog, name='store_catalog'),
    path('store/purchase/', views_store.purchase_cosmetic, name='store_purchase'),
    path('store/equip/', views_store.equip_cosmetic, name='store_equip'),
]