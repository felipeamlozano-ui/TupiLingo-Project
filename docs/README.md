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
   Certifique-se de que `docs/app/index.html` contenha `<base href="./">` (o comando acima com `--base-href ./` já gera automaticamente).

---

## ⚙️ Configuração do Iframe na Landing Page

Dentro de `index.html`:
```html
<!-- Caminho relativo configurável para o build web do Flutter -->
<iframe 
  src="./app/" 
  id="tupiIframe" 
  class="simulator-iframe"
  title="Simulador Web do TupiLingo"
  allow="autoplay; fullscreen; clipboard-write; encrypted-media; camera; microphone"
  loading="lazy">
</iframe>
```
- **Localmente**: Ao rodar um servidor HTTP simples (`python -m http.server 8080`), abra `http://localhost:8080/docs/` ou `http://localhost:8080/landing-page/`.
- **Produção (GitHub Pages)**: O iframe carrega `./app/` de forma relativa, funcionando perfeitamente em domínios personalizados (`tupilingo.app`) ou em subpastas padrão do GitHub (`usuario.github.io/TupiLingo-Project/`).

---

## 📱 Recursos de UX e Mobile

1. **Call to Action Duplo**:
   - `Testar Agora no Navegador`: Rola suavemente até o simulador interativo com efeito de foco.
   - `Baixar APK (.apk)`: Baixa a versão de distribuição compilada para Android.
2. **Alternativa Mobile em Tela Cheia**:
   - Botão direto "Abrir Versão Web em Tela Cheia" abre `./app/` em nova aba, ideal para telas de celulares e tablets.
3. **Touch Gate**:
   - Em smartphones, evita conflitos de toque com o canvas do Flutter, permitindo rolagem fluida da página até que o usuário decida interagir.
4. **Modos Smartphone e Tablet**:
   - Alternância dinâmica entre proporções 9:19.5 (390×844) e Tablet/Amplo (620×860).
