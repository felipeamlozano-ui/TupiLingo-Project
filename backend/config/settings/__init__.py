"""
Settings routing — suporta tanto DJANGO_SETTINGS_MODULE quanto a flag PRODUCTION.
No Docker, usamos: DJANGO_SETTINGS_MODULE=config.settings.production
Localmente (Windows), usamos: PRODUCTION=False no .env
"""
import os

from decouple import config

# Suporte a DJANGO_SETTINGS_MODULE (Docker/Gunicorn) OU flag PRODUCTION (.env local)
_dsm = os.environ.get('DJANGO_SETTINGS_MODULE', '')
if _dsm == 'config.settings.production' or config('PRODUCTION', default=False, cast=bool):
    from .production import *
else:
    from .development import *
