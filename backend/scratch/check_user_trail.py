import os, sys
sys.stdout.reconfigure(encoding='utf-8')
sys.path.insert(0, r'c:\Users\Felipe\Desktop\TupiLingo\backend')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.development')
import django
django.setup()

from users.models import UserProfile
from trilha.models import VarianteTupi
from users.services.progress_service import ProgressService

u = UserProfile.objects.get(id=4)
print(f"User 4 email: {u.email}, variante_ativa: {u.variante_ativa}")

for v in VarianteTupi.objects.filter(ativo=True):
    res = ProgressService.get_trail_structure_with_progression(u, v)
    print(f"=== VARIANTE {v.id} ({v.codigo} - {v.nome}) ===")
    for cap in res.get('capitulos', []):
        print(f"  Capitulo {cap.get('numero')} ({cap.get('titulo')}):")
        for lic in cap.get('licoes', []):
            print(f"    Licao {lic.get('id')} (num={lic.get('numero')}, {lic.get('titulo')}): status={lic.get('status')}")
