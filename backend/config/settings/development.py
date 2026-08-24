"""
Development settings
"""
from .base import *

DEBUG = config('DEBUG', default=True, cast=bool)

# Desenvolvimento local: permite qualquer porta do localhost
CORS_ALLOWED_ORIGIN_REGEXES = [
    r'^http://localhost:\d+$',
    r'^http://127\.0\.0\.1:\d+$',
    r'^http://10\.0\.2\.2:\d+$',  # Emulador Android
]

LOGGING['loggers']['nivelamento']['level'] = 'DEBUG'
LOGGING['loggers']['users.views']['level'] = 'DEBUG'
