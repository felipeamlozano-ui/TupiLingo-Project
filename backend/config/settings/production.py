"""
Production settings

NOTA DOCKER: SECURE_SSL_REDIRECT está desativado propositalmente.
O TLS é terminado no Nginx (proxy reverso), que se comunica com o Gunicorn
via HTTP interno. Reativar isso causaria redirect loops infinitos.
"""
from .base import *

DEBUG = config('DEBUG', default=False, cast=bool)

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
