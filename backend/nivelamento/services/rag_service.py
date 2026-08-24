import os
import json
import time
import logging
from django.conf import settings
from duckduckgo_search import DDGS

from google import genai
from google.genai import types
import groq

from nivelamento.services.vector_db import SQLiteVectorDB

logger = logging.getLogger("nivelamento.rag")


class LocalEmbedder:
    """Gera embeddings localmente via CPU (processador offline)."""

    def __init__(self):
        try:
            from sentence_transformers import SentenceTransformer
            self.model = SentenceTransformer('all-MiniLM-L6-v2')
            self.dim = 384
            logger.info("Modelo de IA Local carregado com sucesso no RAG.")
        except Exception as e:
            logger.error(f"Erro ao carregar modelo local: {e}")
            self.model = None

    def embed(self, texts: list[str]) -> list[list[float]]:
        if not self.model or not texts:
            return [[0.0] * 384 for _ in texts]
        
        try:
            embeddings = self.model.encode(texts, convert_to_numpy=True)
            return embeddings.tolist()
        except Exception as e:
            logger.warning(f"[Embedder] Falha local: {e}")
            return [[0.0] * 384 for _ in texts]

    def embed_one(self, text: str) -> list[float]:
        result = self.embed([text])
        return result[0] if result else [0.0] * 384


# Instancia global do banco de dados vetorial (SQLite puro)
_db: SQLiteVectorDB | None = None

def get_db() -> SQLiteVectorDB:
    global _db
    if _db is None:
        db_path = settings.BASE_DIR / "vector_store.db"
        _db = SQLiteVectorDB(str(db_path))
    return _db


# Instancia global do embedder local
_embedder: LocalEmbedder | None = None

def get_embedder() -> LocalEmbedder | None:
    global _embedder
    if _embedder is None:
        _embedder = LocalEmbedder()
    return _embedder


class RAGService:
    def __init__(self):
        self.gemini_api_key = getattr(settings, "GEMINI_API_KEY", os.environ.get("GEMINI_API_KEY", ""))
        self.client = genai.Client(api_key=self.gemini_api_key) if self.gemini_api_key else None

        self.groq_api_key = getattr(settings, "GROQ_API_KEY", os.environ.get("GROQ_API_KEY", ""))
        self.groq_client = groq.Groq(api_key=self.groq_api_key) if self.groq_api_key else None

        self.model = getattr(settings, "GEMINI_MODEL", os.environ.get("GEMINI_MODEL", "gemini-2.5-flash"))

    def search_context(self, query: str, n_results: int = 5) -> str:
        embedder = get_embedder()
        db = get_db()

        if embedder:
            query_emb = embedder.embed_one(query)
            results = db.query(query_emb, n_results=n_results)
        else:
            # Sem embedder: busca por palavras-chave simples
            results = []

        if not results:
            return "Nenhum contexto encontrado nos PDFs."

        return "\n\n---\n\n".join([r["document"] for r in results])

    def generate(self, supabase_uid: str, nivel_atual: int, acertou_anterior: bool) -> dict:
        if not self.gemini_api_key:
            raise RuntimeError("GEMINI_API_KEY nao esta configurada no .env!")

        temas = {
            1: "palavras basicas do dia a dia, animais comuns",
            2: "verbos basicos, acoes",
            3: "natureza, geografia basica",
            4: "mitologia, Tupa",
            5: "historia do Brasil pre-colonial",
            6: "nomes de lugares (toponimia)",
            7: "gramatica intermediaria",
            8: "estrutura de frases complexas",
            9: "poesia e canticos",
            10: "textos historicos fluentes"
        }

        tema = temas.get(nivel_atual, "vocabulario geral")
        contexto_tupi = self.search_context(f"Tupi Guarani {tema}")

        historico = "Sem informacoes adicionais da web no momento."
        try:
            ddg_results = DDGS().text(f"Historia cultura Tupi Guarani {tema}", max_results=2)
            if ddg_results:
                historico = "\n".join([r['body'] for r in ddg_results])
        except Exception as e:
            logger.warning(f"[RAG] DuckDuckGo falhou: {e}")

        prompt = f"""Voce e um especialista e professor academico de Tupi Antigo e linguas Tupi-Guarani.
Crie um teste de nivelamento com exatamente 10 questoes de multipla escolha para o nivel {nivel_atual} de 10.
Tema da etapa: {tema}.

DIRETRIZES FUNDAMENTAIS (LEIA COM EXTREMA ATENCAO):
1. O teste e de LINGUA TUPI. Toda questao DEVE testar vocabulario, verbos ou gramatica de Tupi real.
2. E ESTRITAMENTE PROIBIDO criar enunciados onde a palavra em Tupi nao apareca e as alternativas sejam todas em portugues generico.
3. Cada questao DEVE seguir obrigatoriamente um destes dois modelos:
   - MODELO A (Tupi -> Portugues): O enunciado contextualiza brevemente um aspecto cultural e destaca a palavra Tupi entre aspas simples e pergunta seu significado. As 4 opcoes sao traducoes em portugues.
   - MODELO B (Portugues -> Tupi): O enunciado contextualiza uma acao/elemento em portugues e pergunta qual e o termo correspondente em Tupi. As 4 opcoes sao palavras autenticas em Tupi.
4. A "explicacao" deve ser CURTA (1 ou 2 frases objetivas), estritamente factual. NUNCA invente historias ficticias. PROIBIDO emojis.
5. Vocabulario autentico de Tupi Antigo: use apenas raizes e palavras consagradas na linguistica Tupi.

ESTRUTURA DE EXEMPLO ESPERADA:
{{
    "questoes": [
        {{
            "enunciado": "Nas aldeias litoraneas do seculo XVI, a agua potavel dos rios era essencial. Qual e o significado do vocabilo Tupi 'Y'?",
            "opcoes": ["Agua / Rio", "Terra / Chao", "Fogo / Calor", "Vento / Ar"],
            "resposta_correta": "Agua / Rio",
            "explicacao": "Em Tupi Antigo, 'y' significa agua, rio ou liquido."
        }}
    ]
}}

Retorne APENAS o JSON com as 10 questoes seguindo rigorosamente essas regras.
"""

        candidate_models = [
            self.model,
            "gemini-2.5-flash",
            "gemini-2.0-flash",
            "gemini-1.5-flash",
            "llama3-70b-8192",
            "llama3-8b-8192",
            "mixtral-8x7b-32768",
        ]

        last_error = None
        for model_name in candidate_models:
            try:
                logger.info(f"[RAG] Tentando modelo: {model_name}")

                is_groq = model_name in ["llama3-8b-8192", "llama3-70b-8192", "mixtral-8x7b-32768", "gemma-7b-it"]

                if is_groq:
                    if not self.groq_client:
                        continue
                    response = self.groq_client.chat.completions.create(
                        messages=[
                            {"role": "system", "content": "Voce e um academico linguista de Tupi extremamente rigoroso. Responda APENAS com JSON valido. NUNCA USE EMOJIS."},
                            {"role": "user", "content": prompt}
                        ],
                        model=model_name,
                        temperature=0.6,
                        response_format={"type": "json_object"}
                    )
                    content = response.choices[0].message.content
                else:
                    if not self.client:
                        continue
                    response = self.client.models.generate_content(
                        model=model_name,
                        contents=prompt,
                        config=types.GenerateContentConfig(
                            system_instruction="Voce e um academico linguista de Tupi extremamente rigoroso. Responda APENAS com JSON valido. NUNCA USE EMOJIS.",
                            response_mime_type="application/json",
                            temperature=0.6,
                        )
                    )
                    content = response.text

                parsed = json.loads(content)
                if isinstance(parsed, list):
                    return {"questoes": parsed}
                if isinstance(parsed, dict):
                    questoes = parsed.get("questoes") or list(parsed.values())[0]
                    if isinstance(questoes, list):
                        return {"questoes": questoes}
                return {"questoes": [parsed]}

            except Exception as e:
                logger.warning(f"[RAG] Falha no modelo {model_name}: {e}")
                last_error = e
                continue

        logger.error(f"[RAG] Todos os modelos falharam. Ultimo erro: {last_error}")
        raise RuntimeError(f"Falha ao gerar questao. Erro: {last_error}")
