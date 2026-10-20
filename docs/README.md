# TupiLingo • Estrutura de Publicação Web e Landing Page

Este diretório (`docs/`) e o diretório `landing-page/` foram estruturados para viabilizar tanto o deploy contínuo via **GitHub Pages** (seja pela raiz de branch `/docs` ou via GitHub Actions) quanto testes locais do aplicativo diretamente no navegador, sem necessidade de instalação do APK Android.

---

## 📂 Arquitetura de Pastas

```text
docs/ (ou landing-page/)
├── index.html         # Landing page institucional com moldura interativa (iframe)
├── styles.css         # Folha de estilos oficial com tema indígena e animações
├── script.js          # Lógica do simulador, fullscreen, touch gate e métricas
├── app-release.apk    # APK local para download direto
├── assets/            # Imagens, mockups e logotipo oficial do TupiLingo
│   ├── logo.png
│   ├── screen_trilha.png
│   └── ...
└── app/               # Saída compilada do Flutter Web (HTML5 CanvasKit Wasm)
    ├── index.html     # Ponto de entrada com <base href="./">
    ├── flutter.js
    ├── flutter_bootstrap.js
    ├── main.dart.js
    ├── canvaskit/
    └── assets/
```

---

## 🚀 Como Atualizar a Versão Web após Modificações no Flutter

Quando você alterar o código do aplicativo Flutter em `frontend/tupi_lingo/` e desejar publicar a nova versão na web:

1. **Compilar a versão Web com base relativa**:
   ```bash
   cd frontend/tupi_lingo
   flutter build web --base-href ./ --release
   ```
   *(A flag `--base-href ./` garante que o app encontre seus scripts e CanvasKit em qualquer subdiretório ou GitHub Pages).*

2. **Copiar os arquivos gerados para a pasta `app/`**:
   No Windows (PowerShell):
   ```powershell
   # Atualiza a pasta docs/app (GitHub Pages /docs)
   Copy-Item -Recurse -Force build\web\* ..\..\docs\app\
   
   # Atualiza a pasta landing-page/app (GitHub Actions)
   Copy-Item -Recurse -Force build\web\* ..\..\landing-page\app\
   ```

3. **Verificação do `<base href="./">`**:
   O arquivo `web/index.html` já está configurado com `<base href="./">`, garantindo que a aplicação funcione em qualquer caminho relativo ou subdomínio.

---

## 🌐 Arquitetura Web Autônoma e Adaptativa

A aplicação Flutter foi desacoplada do iframe embutido e agora opera como uma aplicação web completa e autônoma:
- **Redirecionamento Direto**: O botão "Testar no Navegador" no Hero e na Navbar abre diretamente `./app/` em tela cheia (`target="_blank"`).
- **Layout Adaptativo**:
  - Telas largas ($\ge 800\text{ px}$): Exibe menu lateral tátil (Sidebar) e oculta a barra inferior. O conteúdo central da trilha é contido em largura máxima de 700 px.
  - Telas menores ($< 800\text{ px}$): Mantém navegação móvel tradicional via barra inferior.
- **Atalhos de Teclado Físico**: Teclas `1` a `4` para seleção de alternativas nas lições e tecla `Enter` para validação e avanço imediato.
- **PWA (Progressive Web App)**: Totalmente instalável via Chrome/Edge desktop e mobile através do `manifest.json`.

---

## 📱 Recursos de UX e Distribuição

1. **Call to Action Duplo**:
   - `Testar no Navegador`: Abre a aplicação web Flutter completa e responsiva em tela cheia (`./app/`).
   - `Baixar APK (.apk)`: Baixa a versão nativa compilada para dispositivos Android.
2. **Acesso Online (GitHub Pages)**:
   - Landing Page Oficial: `https://felipeamlozano-ui.github.io/TupiLingo-Project/`
   - Aplicativo Web Autônomo: `https://felipeamlozano-ui.github.io/TupiLingo-Project/app/`

3. **Ambiente de Teste Local (Opcional)**:
   - Para testar localmente no seu computador antes de publicar, execute a Opção 5 do `dev.bat` ou execute um servidor HTTP (`python -m http.server 8080`).

