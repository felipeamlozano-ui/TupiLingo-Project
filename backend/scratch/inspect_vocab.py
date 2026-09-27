import os
import sys
from dotenv import load_dotenv

load_dotenv('backend/.env')
sys.path.insert(0, os.path.abspath('backend'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.development')

import django
django.setup()

from trilha.models import VarianteTupi, TrilhaHistorica, Capitulo, Licao, VocabularyItem

print("Variantes in DB:")
for v in VarianteTupi.objects.all():
    print(f"  ID: {v.id}, Codigo: '{v.codigo}', Nome: '{v.nome}', Ativo: {v.ativo}")
    total_vocab = VocabularyItem.objects.filter(licao__capitulo__trilha__variante=v).count()
    print(f"    Total VocabularyItems: {total_vocab}")

total_all_vocab = VocabularyItem.objects.count()
print(f"\nTotal VocabularyItems in DB: {total_all_vocab}")

# Let's inspect some vocabulary items
for item in VocabularyItem.objects.all()[:15]:
    licao = item.licao
    cap = licao.capitulo
    trilha = cap.trilha
    var = trilha.variante
    print(f"[{var.codigo}] Cap {cap.numero} L{licao.numero} ({item.categoria}): {item.palavra_tupi} = {item.traducao_pt}")
