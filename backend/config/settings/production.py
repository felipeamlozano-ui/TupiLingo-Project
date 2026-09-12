"""
Production settings

NOTA DOCKER: SECURE_SSL_REDIRECT está desativado propositalmente.
O TLS é terminado no Nginx (proxy reverso), que se comunica com o Gunicorn
via HTTP interno. Reativar isso causaria redirect loops infinitos.
"""
from django.core.exceptions import ImproperlyConfigured
from .base import *

DEBUG = config('DEBUG', default=False, cast=bool)

# Hosts permitidos em produção: aceita domínios configurados no .env e subdomínios do Cloudflare Quick Tunnel
_allowed_hosts_raw = config('ALLOWED_HOSTS', default='')
if _allowed_hosts_raw == '*':
    ALLOWED_HOSTS = ['127.0.0.1', 'localhost', '.trycloudflare.com']
else:
    ALLOWED_HOSTS = [s.strip() for s in _allowed_hosts_raw.split(',') if s.strip()]

# Garante que 127.0.0.1 e localhost estejam sempre presentes para healthchecks internos do Docker/dev.bat
for _h in ('127.0.0.1', 'localhost'):
    if _h not in ALLOWED_HOSTS:
        ALLOWED_HOSTS.append(_h)

# Garante suporte a qualquer subdomínio do Cloudflare Quick Tunnel (*.trycloudflare.com)
if '.trycloudflare.com' not in ALLOWED_HOSTS:
    ALLOWED_HOSTS.append('.trycloudflare.com')

# Informa ao Django que está atrás de proxy reverso / túnel com terminação TLS (Cloudflare Quick Tunnel)
# O Cloudflared envia o cabeçalho 'X-Forwarded-Proto: https'
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')

# Origens confiáveis para validação CSRF em requisições HTTPS via Cloudflare Quick Tunnel
CSRF_TRUSTED_ORIGINS = config(
    'CSRF_TRUSTED_ORIGINS',
    default='https://*.trycloudflare.com',
    cast=lambda v: [s.strip() for s in v.split(',') if s.strip()],
)
if 'https://*.trycloudflare.com' not in CSRF_TRUSTED_ORIGINS:
    CSRF_TRUSTED_ORIGINS.append('https://*.trycloudflare.com')

# CORS para requisições originadas via HTTPS no Cloudflare Quick Tunnel
CORS_ALLOWED_ORIGIN_REGEXES = [
    r'^https:\/\/.*\.trycloudflare\.com$',
]

# Headers de Segurança HTTP — SETTINGS-005
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
# SECURE_SSL_REDIRECT = True  # Desativado: TLS é terminado no túnel/Nginx, não no Django
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True

LOGGING['loggers']['nivelamento']['level'] = 'INFO'
LOGGING['loggers']['users.views']['level'] = 'INFO'

