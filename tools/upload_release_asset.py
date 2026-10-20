import os
import sys
import json
import subprocess
import urllib.request
import urllib.error

REPO = "felipeamlozano-ui/TupiLingo-Project"
RELEASE_TAG = "v1.0.0-preview"

def get_github_token():
    try:
        p = subprocess.Popen(['git', 'credential', 'fill'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        out, err = p.communicate('protocol=https\nhost=github.com\n\n')
        for line in out.splitlines():
            if line.startswith('password='):
                return line.split('=', 1)[1].strip()
    except Exception as e:
        print(f"[!] Erro ao obter credenciais do Git: {e}")
    return os.environ.get("GITHUB_TOKEN")

def update_release_asset(apk_path: str):
    token = get_github_token()
    if not token:
        print("[ERRO] Token do GitHub nao encontrado via Git Credential Manager ou GITHUB_TOKEN!")
        sys.exit(1)

    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "TupiLingo-Release-Uploader"
    }

    print(f"[*] Localizando release '{RELEASE_TAG}' no repositorio {REPO}...")
    release_url = f"https://api.github.com/repos/{REPO}/releases/tags/{RELEASE_TAG}"
    req = urllib.request.Request(release_url, headers=headers)
    try:
        with urllib.request.urlopen(req) as res:
            release = json.loads(res.read().decode())
    except urllib.error.HTTPError as e:
        print(f"[ERRO] Falha ao buscar release: {e.code} - {e.read().decode()}")
        sys.exit(1)

    release_id = release["id"]
    upload_url_template = release["upload_url"] # e.g. https://uploads.github.com/.../assets{?name,label}
    upload_base = upload_url_template.split("{")[0]
    print(f"[OK] Release encontrada: ID={release_id}, Nome='{release.get('name')}'")

    filename = os.path.basename(apk_path)
    # Verifica se o asset ja existe para deletar a versao antiga
    for asset in release.get("assets", []):
        if asset["name"] == filename:
            asset_id = asset["id"]
            print(f"[*] Removendo asset antigo '{filename}' (ID: {asset_id})...")
            del_url = f"https://api.github.com/repos/{REPO}/releases/assets/{asset_id}"
            del_req = urllib.request.Request(del_url, headers=headers, method="DELETE")
            try:
                with urllib.request.urlopen(del_req) as del_res:
                    print(f"[OK] Asset antigo removido ({del_res.status}).")
            except urllib.error.HTTPError as e:
                print(f"[AVISO] Nao foi possivel remover asset antigo: {e.code}")

    # Upload do novo asset
    file_size = os.path.getsize(apk_path)
    print(f"[*] Fazendo upload de '{filename}' ({file_size / (1024*1024):.2f} MB)...")

    upload_url = f"{upload_base}?name={filename}"
    with open(apk_path, "rb") as f:
        apk_data = f.read()

    upload_headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/vnd.android.package-archive",
        "Content-Length": str(file_size),
        "User-Agent": "TupiLingo-Release-Uploader"
    }

    upload_req = urllib.request.Request(upload_url, data=apk_data, headers=upload_headers, method="POST")
    try:
        with urllib.request.urlopen(upload_req) as upload_res:
            result = json.loads(upload_res.read().decode())
            download_url = result.get("browser_download_url")
            print(f"\n[SUCESSO] APK enviado para o GitHub Releases!")
            print(f"  URL de Download Oficial: {download_url}")
            print(f"  Tamanho: {result.get('size')} bytes")
            return download_url
    except urllib.error.HTTPError as e:
        print(f"[ERRO] Falha no upload: {e.code} - {e.read().decode()}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python upload_release_asset.py <caminho_para_apk>")
        sys.exit(1)
    apk = sys.argv[1]
    if not os.path.exists(apk):
        print(f"[ERRO] Arquivo APK nao encontrado: {apk}")
        sys.exit(1)
    update_release_asset(apk)
