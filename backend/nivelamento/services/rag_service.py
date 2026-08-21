import os
import sqlite3
import json
import logging
from pathlib import Path
from django.conf import settings
from groq import Groq
from rank_bm25 import BM25Okapi

logger = logging.getLogger("nivelamento.rag")

class LocalBM25Search:
    def __init__(self):
        self.db_path = settings.BASE_DIR / 'rag_vectors.sqlite3'
        self._init_db()
        self.bm25 = None
        self.documents = []
        self._load_index()

    def _init_db(self):
        with sqlite3.connect(self.db_path) as conn:
            conn.execute('''
                CREATE TABLE IF NOT EXISTS chunks (
                    id TEXT PRIMARY KEY,
                    filename TEXT,
                    file_hash TEXT,
                    chunk_index INTEGER,
                    text TEXT
                )
            ''')

    def _load_index(self):
        with sqlite3.connect(self.db_path) as conn:
            rows = conn.execute('SELECT text FROM chunks').fetchall()
        
        self.documents = [r[0] for r in rows]
        if self.documents:
            # Tokenização simples (lowercase e split por espaços)
            tokenized_corpus = [doc.lower().split() for doc in self.documents]
            self.bm25 = BM25Okapi(tokenized_corpus)

    def upsert(self, ids, documents, metadatas):
        with sqlite3.connect(self.db_path) as conn:
            for i in range(len(ids)):
                conn.execute('''
                    INSERT OR REPLACE INTO chunks (id, filename, file_hash, chunk_index, text)
                    VALUES (?, ?, ?, ?, ?)
                ''', (
                    ids[i], 
                    metadatas[i]['filename'], 
                    metadatas[i]['file_hash'], 
                    metadatas[i]['chunk_index'], 
                    documents[i]
                ))
        # Recarrega o índice após inserir novos arquivos
        self._load_index()

    def get_existing_file_hash(self, file_hash):
        with sqlite3.connect(self.db_path) as conn:
            res = conn.execute('SELECT id FROM chunks WHERE file_hash = ? LIMIT 1', (file_hash,)).fetchone()
            return res is not None

    def query(self, query_text, n_results=3):
        if not self.bm25 or not self.documents:
            return []
        
        tokenized_query = query_text.lower().split()
        top_docs = self.bm25.get_top_n(tokenized_query, self.documents, n=n_results)
        return top_docs

db = LocalBM25Search()

from duckduckgo_search import DDGS

from google import genai
from google.genai import types

class RAGService:
    def __init__(self):
        self.gemini_api_key = getattr(settings, "GEMINI_API_KEY", os.environ.get("GEMINI_API_KEY", ""))
        self.client = genai.Client(api_key=self.gemini_api_key)
        self.model = getattr(settings, "GEMINI_MODEL", os.environ.get("GEMINI_MODEL", "gemini-3.6-flash"))

    def search_context(self, query: str, n_results: int = 3) -> str:
        results = db.query(query, n_results=n_results)
        if not results:
            return "Nenhum contexto encontrado nos PDFs."
        return "\n\n---\n\n".join(results)

    def generate(self, supabase_uid: str, nivel_atual: int, acertou_anterior: bool) -> dict:
        if not self.gemini_api_key:
            raise RuntimeError("GEMINI_API_KEY não está configurada no .env!")

        temas = {
            1: "palavras básicas do dia a dia, animais comuns",
            2: "verbos básicos, ações",
            3: "natureza, geografia básica",
            4: "mitologia, Tupã",
            5: "história do Brasil pré-colonial",
            6: "nomes de lugares (toponímia)",
            7: "gramática intermediária",
            8: "estrutura de frases complexas",
            9: "poesia e cânticos",
            10: "textos históricos fluentes"
        }
        
        tema = temas.get(nivel_atual, "vocabulário geral")
        context_query = f"Tupi Guarani {tema}"
        contexto_tupi = self.search_context(context_query)

        historico = "Sem informações adicionais da web no momento."
        try:
            ddg_results = DDGS().text(f"História cultura Tupi Guarani {tema}", max_results=2)
            if ddg_results:
                historico = "\n".join([r['body'] for r in ddg_results])
        except Exception as e:
            logger.warning(f"[RAG] DuckDuckGo falhou, usando fallback. Erro: {e}")

        prompt = f"""Você é um especialista e professor acadêmico de Tupi Antigo e línguas Tupi-Guarani.
Crie um teste de nivelamento com exatamente 10 questões de múltipla escolha para o nível {nivel_atual} de 10.
Tema da etapa: {tema}.

DIRETRIZES FUNDAMENTAIS (LEIA COM EXTREMA ATENÇÃO):
1. O teste é de LÍNGUA TUPI. Toda questão DEVE testar vocabulário, verbos ou gramática de Tupi real.
2. É ESTRITAMENTE PROIBIDO criar enunciados onde a palavra em Tupi não apareça e as alternativas sejam todas em português genérico (sem indicar o que está sendo traduzido).
3. Cada questão DEVE seguir obrigatoriamente um destes dois modelos:
   - MODELO A (Tupi -> Português): O enunciado contextualiza brevemente um aspecto cultural e destaca a palavra Tupi entre aspas simples (ex: 'arara', 'y', 'abá', 'kunhã', 'tata', 'so'ó') e pergunta seu significado. As 4 opções são traduções em português.
   - MODELO B (Português -> Tupi): O enunciado contextualiza uma ação/elemento em português e pergunta qual é o termo correspondente em Tupi. As 4 opções são palavras autênticas em Tupi.
4. A "explicacao" deve ser CURTA (1 ou 2 frases objetivas), estritamente factual, explicando a tradução direta e a etimologia da palavra Tupi. NUNCA invente histórias fictícias. PROIBIDO emojis.
5. Vocabulário autêntico de Tupi Antigo: use apenas raízes e palavras consagradas na linguística Tupi (ex: Navarro, Lemos Barbosa).

ESTRUTURA DE EXEMPLO ESPERADA:
{{
    "questoes": [
        {{
            "enunciado": "Nas aldeias litorâneas do século XVI, a água potável dos rios era essencial para a comunidade. Qual é o significado do vocábulo Tupi 'Y'?",
            "opcoes": ["Água / Rio", "Terra / Chão", "Fogo / Calor", "Vento / Ar"],
            "resposta_correta": "Água / Rio",
            "explicacao": "Em Tupi Antigo, 'y' significa água, rio ou líquido."
        }},
        {{
            "enunciado": "Os guerreiros Tupinambá utilizavam o fogo tanto para cozinhar quanto para rituais. Como se diz 'fogo' em Tupi Antigo?",
            "opcoes": ["Tata", "Yby", "Ara", "Kó"],
            "resposta_correta": "Tata",
            "explicacao": "'Tata' é o substantivo que traduz fogo ou chama em Tupi Antigo."
        }}
    ]
}}

Retorne APENAS o JSON com as 10 questões seguindo rigorosamente essas regras.
"""
        
        candidate_models = [
            self.model,
            "gemini-2.5-flash",
            "gemini-2.5-flash-lite",
            "gemini-3.5-flash",
        ]
        
        last_error = None
        for model_name in candidate_models:
            try:
                logger.info(f"[RAG] Tentando gerar questões com o modelo: {model_name}")
                response = self.client.models.generate_content(
                    model=model_name,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        system_instruction="Você é um acadêmico linguista de Tupi extremamente rigoroso e formal. Responda APENAS com JSON válido. NUNCA USE EMOJIS.",
                        response_mime_type="application/json",
                        temperature=0.6,
                    )
                )
                
                content = response.text
                parsed = json.loads(content)
                if isinstance(parsed, list):
                    return {"questoes": parsed}
                if isinstance(parsed, dict):
                    # Se vier encapsulado em chave 'questoes' ou similar
                    questoes = parsed.get("questoes") or list(parsed.values())[0]
                    if isinstance(questoes, list):
                        return {"questoes": questoes}
                return {"questoes": [parsed]}
            except Exception as e:
                logger.warning(f"[RAG] Falha no modelo {model_name}: {e}")
                last_error = e
                continue
        
        logger.error(f"[RAG] Todos os modelos do Gemini falharam. Último erro: {last_error}")
        raise RuntimeError(f"Falha ao gerar questão no Gemini. Erro: {last_error}")
