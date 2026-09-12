# 🌐 Guia de Configuração: Cloudflare Quick Tunnel (trycloudflare.com)

Para validar o aplicativo com usuários externos (em redes móveis 4G/5G ou Wi-Fi de terceiros) enquanto o backend roda no seu computador, o TupiLingo utiliza o **Cloudflare Quick Tunnel (`trycloudflare.com`)**.

---

## ⚡ Por que Cloudflare Quick Tunnel?

- **100% Gratuito e Ilimitado**: Sem expiração de 60 minutos (como o Pinggy) e sem limites rígidos de banda/sessão (como o Ngrok gratuito).
- **Sem necessidade de conta ou domínio próprio**: Gera um subdomínio HTTPS seguro automaticamente (ex: `https://xxxx.trycloudflare.com`).
- **Automação Completa no `dev.bat`**: O executável oficial `cloudflared.exe` é baixado e gerenciado automaticamente pelo script.

---

## 🚀 Como Funciona no `dev.bat` (Opção 3)

O menu `[3] Modo Producao Real` oferece duas rotinas:

### [1] Subir Produção + Túnel + Build APK de Release
1. **Verificação & Download**: Garante que `tools\cloudflared.exe` esteja disponível (baixa direto do GitHub se necessário).
2. **Subida do Túnel & Captura da URL**: Abre o túnel em janela dedicada e captura automaticamente a URL gerada (ou solicita confirmação/input).
3. **Gestão Crítica de RAM (7.3GB)**: Interrompe temporariamente os contêineres Docker antes de iniciar a compilação do Flutter/Gradle para evitar estouro de memória na máquina host.
4. **Compilação do APK Release**:
   ```cmd
   flutter build apk --release --dart-define-from-file=.env --dart-define=API_URL=%CLOUDFLARE_URL%
   ```
5. **Reinício do Backend em Produção**: Sobe os contêineres Docker em modo de produção real (Gunicorn WSGI com 2 workers/2 threads, Redis e Supabase, `DEBUG=False`).
6. **Resumo Operacional**: Exibe a URL pública ativa e o caminho do APK gerado (`frontend\tupi_lingo\build\app\outputs\flutter-apk\app-release.apk`).

### [2] Subir Apenas Backend + Túnel
- Sobe diretamente o backend em modo de produção e o túnel Cloudflare sem recompilar o Flutter.
- Ideal para quando os testadores já possuem o APK instalado no celular.

---

## 🔒 Configurações do Django (`production.py`)

As seguintes configurações garantem o funcionamento correto com qualquer subdomínio do Cloudflare Quick Tunnel:

1. **Hosts Permitidos (`ALLOWED_HOSTS`)**:
   ```python
   ALLOWED_HOSTS = ['127.0.0.1', 'localhost', '.trycloudflare.com']
   ```
   *O prefixo `.` aceita qualquer subdomínio temporário gerado pelo Quick Tunnel.*

2. **Origens CSRF Confiáveis (`CSRF_TRUSTED_ORIGINS`)**:
   ```python
   CSRF_TRUSTED_ORIGINS = ['https://*.trycloudflare.com']
   ```

3. **Proxy Reverso com Terminação TLS**:
   ```python
   SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
   ```
   *Permite ao Django identificar requisições HTTPS encaminhadas pelo túnel Cloudflare.*
