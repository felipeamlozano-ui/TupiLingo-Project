"""
Instância unificada do Celery para tarefas em background do TupiLingo.
Reexporta a aplicação central configurada em config.celery.
"""

from config.celery import app

__all__ = ["app"]
