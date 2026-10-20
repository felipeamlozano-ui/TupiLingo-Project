import sys
import json
import urllib.request

SUPABASE_URL = "https://pcquxppvheodcrdkwqhh.supabase.co"
SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBjcXV4cHB2aGVvZGNyZGt3cWhoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTgyNjgxOCwiZXhwIjoyMDkxNDAyODE4fQ.G56e6fSVK1hY4POKgpXWNJQWf9xk7GPoXxMjcoU9-Mg"

def publish_tunnel(url: str):
    url = url.strip().rstrip('/')
    if not url.startswith('http'):
        print(f"[!] URL invalida: {url}")
        return False

    payload = json.dumps({"url": url}).encode('utf-8')
    endpoint = f"{SUPABASE_URL}/storage/v1/object/public-config/tunnel_url.json"
    
    req = urllib.request.Request(
        endpoint,
        data=payload,
        headers={
            "apikey": SERVICE_KEY,
            "Authorization": f"Bearer {SERVICE_KEY}",
            "Content-Type": "application/json",
            "x-upsert": "true"
        },
        method="POST"
    )
    
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            if resp.status in (200, 201):
                print(f"[OK] URL do Cloudflare Tunnel publicada com sucesso no Supabase: {url}")
                return True
            else:
                print(f"[!] Resposta inesperada do Supabase: {resp.status}")
                return False
    except Exception as e:
        print(f"[!] Falha ao sincronizar com Supabase: {e}")
        return False

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Uso: python publish_tunnel.py <CLOUDFLARE_URL>")
        sys.exit(1)
    success = publish_tunnel(sys.argv[1])
    sys.exit(0 if success else 1)
