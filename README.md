# 🦜 TupiLingo

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Django-092E20?style=for-the-badge&logo=django&logoColor=white" alt="Django" />
  <img src="https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python" />
  <img src="https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white" alt="Supabase" />
  <img src="https://img.shields.io/badge/AI_&_RAG-FF6F00?style=for-the-badge&logo=google&logoColor=white" alt="AI & RAG" />
  <img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker" />
</div>

<br/>

<div align="center">
  <strong>Um aplicativo inteligente e moderno para nivelamento e aprendizado de idiomas, alimentado por Inteligência Artificial (RAG) e construído com as tecnologias mais robustas do mercado.</strong>
</div>

<br/>

<details>
  <summary><b>Conteúdo</b></summary>
  <ol>
    <li><a href="#-sobre-o-projeto">Sobre o Projeto</a></li>
    <li><a href="#-funcionalidades-principais">Funcionalidades Principais</a></li>
    <li><a href="#-tecnologias-utilizadas">Tecnologias Utilizadas</a></li>
    <li><a href="#-estrutura-do-projeto">Estrutura do Projeto</a></li>
    <li><a href="#-variáveis-de-ambiente">Variáveis de Ambiente</a></li>
    <li><a href="#-como-executar-o-projeto-localmente">Como Executar o Projeto Localmente</a>
      <ul>
        <li><a href="#pré-requisitos">Pré-requisitos</a></li>
        <li><a href="#1-configurando-o-backend-api">Backend (API)</a></li>
        <li><a href="#2-configurando-o-frontend-mobile">Frontend (Mobile)</a></li>
      </ul>
    </li>
    <li><a href="#-contribuindo">Contribuindo</a></li>
    <li><a href="#-licença">Licença</a></li>
  </ol>
</details>

<br/>

## 📖 Sobre o Projeto

O **TupiLingo** é uma plataforma completa (Mobile + API) focada em proporcionar uma experiência fluida e inteligente aos usuários que desejam aprender idiomas (especialmente a língua Tupi Guarani de forma interativa e gamificada).

O sistema utiliza **Inteligência Artificial (Google GenAI)** e processamento de documentos (PDFs) para realizar o *nivelamento* dinâmico dos estudantes, utilizando técnicas avançadas de RAG (*Retrieval-Augmented Generation*).

A interface mobile foi cuidadosamente desenhada em **Flutter**, proporcionando acesso via OTP, recuperação de senhas, criação de contas e uma experiência nativa impecável.

---

## ✨ Funcionalidades Principais

### 📱 Frontend (Flutter)
- **Autenticação Segura:** Login, Registro e recuperação de senha.
- **Validação Inteligente:** Confirmação de identidade via **OTP (One-Time Password)**.
- **Experiência Nativa:** Layout responsivo, interativo e fluido para Android e iOS.
- **Integração com Supabase:** Gerenciamento em tempo real da sessão do usuário.
- **Injeção Segura:** Variáveis de ambiente configuradas com `flutter_dotenv` (apenas em dev) para não expor credenciais em produção.

### ⚙️ Backend (Django + IA)
- **API RESTful:** Construída com Django REST Framework (DRF) para comunicação ágil e estruturada.
- **Inteligência Artificial Avançada:** Integração com **Google GenAI** e LiteLLM para geração de conteúdo.
- **Motor de Nivelamento (RAG):** Leitura de PDFs (`PyPDF2`), vetorização inteligente usando **FastEmbed** e integração nativa com o banco de dados vetorial.
- **Banco de Dados Seguro:** Conexão robusta utilizando PostgreSQL/Supabase.
- **Rate Limiting & Resiliência:** Proteção de rotas da API contra abusos usando `django-ratelimit`, tarefas assíncronas com Celery/Redis e retentativas com Tenacity.

---

## 🛠️ Tecnologias Utilizadas

### Frontend
- **Framework:** Flutter & Dart (SDK `^3.12.2`)
- **Backend as a Service:** Supabase (Autenticação e BaaS) através do pacote `supabase_flutter`
- **Networking:** `http`
- **Gerenciamento de Configuração:** `flutter_dotenv`

### Backend
- **Linguagem & Framework:** Python 3.10+ & Django (Core 5.1)
- **API:** Django REST Framework (DRF)
- **IA & RAG:** Google GenAI, OpenAI, LiteLLM, DuckDuckGo Search, PyPDF2, FastEmbed, Rank BM25
- **Banco de Dados:** Supabase, PostgreSQL (`psycopg2-binary`)
- **Infraestrutura e Ferramentas:** Docker, Gunicorn, Celery, Redis, Pydantic, python-decouple
- **Observabilidade:** OpenTelemetry e Prometheus

---

## 📂 Estrutura do Projeto

```bash
.
├── backend/                  # API Django e serviços de IA
│   ├── app/                  # Regras de negócio, serviços e IA
│   ├── config/               # Configurações do Django (desenvolvimento e produção)
│   ├── docker/               # Arquivos e scripts Docker
│   ├── nivelamento/          # Módulo do motor RAG e processamento de PDFs
│   ├── trilha/               # Módulo de trilhas de aprendizado
│   └── users/                # Gerenciamento de usuários
├── frontend/                 # Aplicativo Mobile em Flutter
│   └── tupi_lingo/           # Código-fonte principal do Flutter
│       ├── lib/              # Telas, widgets e lógica
│       └── assets/           # Imagens e fontes
├── supabase/                 # Configurações adicionais para Supabase (se houver)
└── README.md
```

---

## 🔐 Variáveis de Ambiente

Para o projeto funcionar corretamente, você precisa configurar os arquivos de variáveis de ambiente.

### Backend (`backend/.env`)
Crie um arquivo `.env` na raiz da pasta `backend/` com as seguintes chaves sugeridas:

```env
# Configurações do Django
DEBUG=True
PRODUCTION=False
SECRET_KEY=sua-chave-secreta-do-django

# Configurações do Supabase / Banco de Dados
SUPABASE_URL=sua-url-do-supabase
SUPABASE_KEY=sua-anon-key-do-supabase
DATABASE_URL=postgres://usuario:senha@host:porta/banco

# Chaves de API (IA)
GEMINI_API_KEY=sua-chave-do-google-genai
```

### Frontend (`frontend/tupi_lingo/.env`)
Crie um arquivo `.env` na pasta `frontend/tupi_lingo/` para o ambiente de desenvolvimento:

```env
SUPABASE_URL=sua-url-do-supabase
SUPABASE_ANON_KEY=sua-anon-key-do-supabase
```
> **Nota:** Em produção, utilize `--dart-define` no comando de build para injetar as variáveis de forma segura sem `flutter_dotenv`.

---

## 🚀 Como Executar o Projeto Localmente

### Pré-requisitos
Certifique-se de ter instalado em sua máquina:
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (versão `^3.12.2` ou superior)
- [Python](https://www.python.org/downloads/) (versão `3.10+`)
- [Docker](https://docs.docker.com/get-docker/) & [Docker Compose](https://docs.docker.com/compose/install/) (Opcional, porém recomendado para o backend)
- Conta no [Supabase](https://supabase.com/) configurada.

---

### 1. Configurando o Backend (API)

Você pode rodar o backend localmente com Python ou através do Docker.

#### Opção A: Usando Python (Local)

```bash
# Navegue até a pasta do backend
cd backend

# Crie e ative um ambiente virtual (Windows)
python -m venv venv
venv\Scripts\activate

# Crie e ative um ambiente virtual (Linux/Mac)
python3 -m venv venv
source venv/bin/activate

# Instale as dependências
pip install -r requirements.txt

# Configure o arquivo .env conforme a seção anterior

# Execute as migrações do banco de dados
python manage.py migrate

# Inicie o servidor de desenvolvimento
python manage.py runserver
```

#### Opção B: Usando Docker

```bash
# Navegue até a pasta do backend
cd backend

# Certifique-se de que o .env está configurado

# Inicie os serviços usando Docker Compose
docker-compose -f docker-compose.dev.yml up --build
```
A API estará disponível em `http://localhost:8000`.

---

### 2. Configurando o Frontend (Mobile)

```bash
# Navegue até a pasta do projeto Flutter
cd frontend/tupi_lingo

# Instale as dependências
flutter pub get

# Configure o arquivo .env com suas chaves do Supabase

# Execute o aplicativo em um emulador ou dispositivo conectado
flutter run
```

---

## 🤝 Contribuindo

Contribuições são sempre bem-vindas! Se você deseja contribuir com o TupiLingo:

1. Faça um **Fork** do projeto
2. Crie uma branch para sua feature (`git checkout -b feature/MinhaFeature`)
3. Faça o commit de suas mudanças (`git commit -m 'feat: Adiciona uma nova funcionalidade X'`)
4. Faça o push para a branch (`git push origin feature/MinhaFeature`)
5. Abra um **Pull Request**

---

## 📄 Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) (se aplicável) para mais detalhes.

<br/>
<div align="center">
  Desenvolvido com 💚 para revolucionar o aprendizado de idiomas.
</div>
