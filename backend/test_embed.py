import os
import sys

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.development')

import django
django.setup()

print("Django setup done")

from nivelamento.services.rag_service import db
try:
    print('Testing Gemini Embedding...')
    db.upsert(['test_1'], ['Este e um texto de teste para ver se o embedding funciona.'], [{'file': 'test'}])
    print('Sucesso!')
except Exception as e:
    print('ERRO:', e)
