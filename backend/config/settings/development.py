"""
Development settings
"""
from .base import *

DEBUG = config('DEBUG', default=True, cast=bool)

# Desenvolvimento local: permite qualquer porta do localhost e da LAN Wi-Fi.
# A regex 192\.168\.\d+\.\d+ cobre o range RFC-1918 usado pela Opção 3 do dev.bat
# (simulação de produção via Wi-Fi — flutter run --release --dart-define=API_URL=http://<IP>:8000).
CORS_ALLOWED_ORIGIN_REGEXES = [
    r'^http://localhost:\d+$',
    r'^http://127\.0\.0\.1:\d+$',
    r'^http://10\.0\.2\.2:\d+$',           # Emulador Android (AVD)
    r'^http://192\.168\.\d+\.\d+:\d+$',    # Rede LAN Wi-Fi local (Opção 3 do dev.bat)
    r'^http://10\.\d+\.\d+\.\d+:\d+$',     # Redes corporativas 10.x.x.x
]

LOGGING['loggers']['nivelamento']['level'] = 'DEBUG'
LOGGING['loggers']['users.views']['level'] = 'DEBUG'
