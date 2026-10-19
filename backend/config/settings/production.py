"""
Production settings

NOTA DOCKER: SECURE_SSL_REDIRECT está desativado propositalmente.
O TLS é terminado no Nginx (proxy reverso), que se comunica com o Gunicorn
via HTTP interno. Reativar isso causaria redirect loops infinitos.
"""
from django.core.exceptions import ImproperlyConfigured
from .base import *

DEBUG = config('DEBUG', default=False, cast=bool)

import re

# Hosts permitidos em produção: aceita domínios configurados no .env
_allowed_hosts_raw = config('ALLOWED_HOSTS', default='')
if _allowed_hosts_raw == '*':
    ALLOWED_HOSTS = ['127.0.0.1', 'localhost']
else:
    ALLOWED_HOSTS = [s.strip() for s in _allowed_hosts_raw.split(',') if s.strip()]

# Garante que 127.0.0.1 e localhost estejam sempre presentes para healthchecks internos do Docker/dev.bat
for _h in ('127.0.0.1', 'localhost'):
    if _h not in ALLOWED_HOSTS:
        ALLOWED_HOSTS.append(_h)

# Adiciona host específico de Cloudflare Tunnel apenas se configurado explicitamente no ambiente
CLOUDFLARE_TUNNEL_DOMAIN = config('CLOUDFLARE_TUNNEL_DOMAIN', default='').strip()
if CLOUDFLARE_TUNNEL_DOMAIN:
    cf_host = CLOUDFLARE_TUNNEL_DOMAIN.replace('https://', '').replace('http://', '').strip('/')
    if cf_host and cf_host not in ALLOWED_HOSTS:
        ALLOWED_HOSTS.append(cf_host)

# Informa ao Django que está atrás de proxy reverso / túnel com terminação TLS
# O Cloudflared envia o cabeçalho 'X-Forwarded-Proto: https'
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')

# Origens confiáveis para validação CSRF
CSRF_TRUSTED_ORIGINS = config(
    'CSRF_TRUSTED_ORIGINS',
    default='',
    cast=lambda v: [s.strip() for s in v.split(',') if s.strip()],
)
if CLOUDFLARE_TUNNEL_DOMAIN:
    cf_origin = f"https://{CLOUDFLARE_TUNNEL_DOMAIN.replace('https://', '').replace('http://', '').strip('/')}"
    if cf_origin not in CSRF_TRUSTED_ORIGINS:
        CSRF_TRUSTED_ORIGINS.append(cf_origin)

# CORS para requisições em produção
CORS_ALLOWED_ORIGIN_REGEXES = []
if CLOUDFLARE_TUNNEL_DOMAIN:
    cf_clean = CLOUDFLARE_TUNNEL_DOMAIN.replace('https://', '').replace('http://', '').strip('/')
    CORS_ALLOWED_ORIGIN_REGEXES.append(rf'^https:\/\/{re.escape(cf_clean)}$')

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

