"""
Production settings

NOTA DOCKER: SECURE_SSL_REDIRECT está desativado propositalmente.
O TLS é terminado no Nginx (proxy reverso), que se comunica com o Gunicorn
via HTTP interno. Reativar isso causaria redirect loops infinitos.
"""
from django.core.exceptions import ImproperlyConfigured

from .base import *

DEBUG = config('DEBUG', default=False, cast=bool)

# Forçar ALLOWED_HOSTS explícito em produção — falha explicitamente se não configurado ou contiver '*'
ALLOWED_HOSTS = config(
    'ALLOWED_HOSTS',
    default='',
    cast=lambda v: [s.strip() for s in v.split(',') if s.strip()],
)
if not ALLOWED_HOSTS or '*' in ALLOWED_HOSTS:
    raise ImproperlyConfigured("ALLOWED_HOSTS deve conter domínios explícitos em produção (não pode ser vazio ou '*')!")

# Headers de Segurança HTTP — SETTINGS-005
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
# SECURE_SSL_REDIRECT = True  # Desativado: TLS é terminado no Nginx, não no Django
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True

LOGGING['loggers']['nivelamento']['level'] = 'INFO'
LOGGING['loggers']['users.views']['level'] = 'INFO'
