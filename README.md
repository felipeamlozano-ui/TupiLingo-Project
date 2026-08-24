# 🦜 TupiLingo

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Django-092E20?style=for-the-badge&logo=django&logoColor=white" alt="Django" />
  <img src="https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python" />
  <img src="https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white" alt="Supabase" />
  <img src="https://img.shields.io/badge/AI_&_RAG-FF6F00?style=for-the-badge&logo=google&logoColor=white" alt="AI & RAG" />
</div>

<br/>

<div align="center">
  <strong>Um aplicativo inteligente e moderno para nivelamento e aprendizado de idiomas, alimentado por Inteligência Artificial (RAG) e construído com as tecnologias mais robustas do mercado.</strong>
</div>

<br/>

## 📖 Sobre o Projeto

O **TupiLingo** é uma plataforma completa (Mobile + API) focada em proporcionar uma experiência fluida e inteligente aos usuários. O sistema utiliza **Inteligência Artificial (Google GenAI e ChromaDB)** e processamento de documentos (PDFs) para realizar o *nivelamento* dinâmico dos estudantes, utilizando técnicas avançadas de RAG (*Retrieval-Augmented Generation*). 

A interface mobile foi cuidadosamente desenhada em **Flutter**, proporcionando acesso via OTP, recuperação de senhas, criação de contas e uma experiência nativa.

---

## ✨ Funcionalidades Principais

### 📱 Frontend (Flutter)
- **Autenticação Segura:** Login, Registro e recuperação de senha.
- **Validação Inteligente:** Confirmação de identidade via **OTP (One-Time Password)**.
- **Experiência Nativa:** Layout responsivo, interativo e fluido para Android e iOS.
- **Integração com Supabase:** Gerenciamento em tempo real da sessão do usuário.

### ⚙️ Backend (Django + IA)
- **API RESTful:** Construída com Django REST Framework (DRF) para comunicação ágil.
- **Inteligência Artificial Avançada:** Integração com **Google GenAI**.
- **Motor de Nivelamento (RAG):** Leitura de PDFs (`PyPDF2`), vetorização com **ChromaDB** e análises heurísticas.
- **Banco de Dados Seguro:** Conexão robusta utilizando PostgreSQL/Supabase e SQLite local para vetores.
- **Rate Limiting:** Proteção de rotas da API contra abusos.

---

## 🛠️ Tecnologias Utilizadas

### Frontend
* **Flutter** & **Dart**
* `supabase_flutter` (Autenticação e BaaS)
* `http` (Comunicação com a API REST)
* `flutter_dotenv` (Gestão de variáveis de ambiente)

### Backend
* **Python** & **Django** 
* **Django REST Framework** (DRF)
* **Google GenAI** & **DuckDuckGo Search** (Modelos Generativos e Pesquisas)
* **ChromaDB** (Banco de dados vetorial para RAG)
* **Supabase** & **PyJWT** (Autenticação JWT)
* **PyPDF2** (Processamento de documentos)

---

## 🚀 Como Executar o Projeto Localmente

### Pré-requisitos
Certifique-se de ter instalado em sua máquina:
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (versão `^3.12.2` ou superior)
- [Python](https://www.python.org/downloads/) (versão `3.10+`)
- Conta no [Supabase](https://supabase.com/) configurada.

---

### 1. Configurando o Backend (API)

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

# Crie o arquivo .env (veja a seção Variáveis de Ambiente)
# Execute as migrações e inicie o servidor
python manage.py migrate
python manage.py runserver
