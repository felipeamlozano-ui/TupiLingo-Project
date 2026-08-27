import logging
from typing import List
from pydantic import BaseModel, Field

from app.core.config import settings
from app.ai.fallback import FallbackOrchestrator
from app.ai.router import ModelRouter
from app.ai.cache import prompt_cache
from app.ai.schemas import QuestaoSchema
from nivelamento.services.vector_db import SQLiteVectorDB # Manter compatibilidade com DB local até Chroma
from app.ai.knowledge_graph import get_graph

logger = logging.getLogger(__name__)

class ExameSchema(BaseModel):
    """Schema Pydantic contendo as 10 questões"""
    questoes: List[QuestaoSchema] = Field(description="Lista com exatamente 10 questões de nivelamento")

_db_instance = None
_embedder_instance = None

def get_db():
    global _db_instance
    if _db_instance is None:
        _db_instance = SQLiteVectorDB("vector_store.db")
    return _db_instance

def get_embedder():
    global _embedder_instance
    if _embedder_instance is None:
        try:
            from sentence_transformers import SentenceTransformer
            _embedder_instance = SentenceTransformer('all-MiniLM-L6-v2')
        except Exception as e:
            logger.error(f"Erro ao carregar embedder: {e}")
    return _embedder_instance

class RAGService:
    """
    Serviço RAG especializado para Tupi (ADR-009).
    Utiliza orquestração de IA e fallback, eliminando lógica de providers hardcoded.
    """
    
    def __init__(self):
        # A compatibilidade com vector_db local se mantém até migração total para Chroma
        self.db = get_db()
        self.embedder = get_embedder()

    def _get_embedding(self, text: str) -> List[float]:
        if not self.embedder:
            return [0.0] * 384
        return self.embedder.encode([text], convert_to_numpy=True)[0].tolist()

    def search_context(self, query: str, n_results: int = 5) -> str:
        """
        Recupera contexto histórico/gramatical usando GraphRAG (Grafo de Conhecimento).
        """
        query_emb = self._get_embedding(query)
        
        graph = get_graph()
        # Busca no grafo as informações conectadas
        context_str = graph.search_subgraph(query_emb, top_k=n_results, neighbors=1)
        
        return context_str

    def generate(self, nivel_atual: int) -> dict:
        """
        Gera 10 questões para o nível atual usando a arquitetura AI.
        """
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
        contexto_tupi = self.search_context(f"Tupi Guarani {tema}", n_results=settings.RAG_TOP_K)

        prompt = f"""Você é um especialista e professor acadêmico de Tupi Antigo e línguas Tupi-Guarani.
Crie um teste de nivelamento com exatamente 10 questões de múltipla escolha para o nível CEFR-Tupi {nivel_atual} de 10.
Tema da etapa: {tema}.

Contexto Tupi Recuperado:
{contexto_tupi}

DIRETRIZES FUNDAMENTAIS (LEIA COM EXTREMA ATENÇÃO):
1. O teste é de LÍNGUA TUPI. Toda questão DEVE testar vocabulário, verbos ou gramática de Tupi real.
2. É ESTRITAMENTE PROIBIDO criar enunciados onde a palavra em Tupi não apareça e as alternativas sejam todas em português genérico.
3. Se o contexto recuperado disser "Nenhum contexto", não invente histórias. Fique estritamente na base linguística conhecida do Tupi.
4. A "explicacao" deve ser CURTA, baseada no contexto. PROIBIDO emojis.
"""

        # 1. Verifica Cache Semântico
        # Usamos uma string genérica do modelo "any" para check de cache de nível
        cached = prompt_cache.get(prompt, "nivelamento_cache")
        if cached:
            logger.info("Retornando questões via Prompt Cache Semântico.")
            return self._shuffle_questions(cached)

        # 2. Seleciona Roteamento Dinâmico (ADR-008)
        # Contexto é curto aqui, usamos roteamento balanceado ou rápido
        model_chain = ModelRouter.get_chain_for_task(task_type="balanced", context_length=len(prompt))

        # 3. Executa via Fallback Orquestrador
        logger.info(f"Iniciando geração de {len(model_chain)} modelos em cadeia de fallback.")
        try:
            exame_estruturado: ExameSchema = FallbackOrchestrator.execute_with_fallback(
                prompt=prompt,
                schema=ExameSchema,
                chain=model_chain,
                temperature=0.6
            )
            
            result_dict = exame_estruturado.model_dump()
            
            # 4. Salva no Cache (antes de embaralhar para manter versão original)
            prompt_cache.set(prompt, "nivelamento_cache", result_dict)
            
            return self._shuffle_questions(result_dict)

        except Exception as e:
            logger.error(f"Geração RAG falhou completamente: {e}")
            raise RuntimeError(f"Falha ao gerar questão Tupi: {e}")

    def _shuffle_questions(self, result_dict: dict) -> dict:
        import random
        import copy
        
        # Faz uma cópia para não alterar a referência do cache em memória
        shuffled_dict = copy.deepcopy(result_dict)
        
        for q in shuffled_dict.get("questoes", []):
            alternativas = q.get("alternativas", [])
            correct_letter = q.get("resposta_correta")
            
            correct_text = ""
            for alt in alternativas:
                if alt.get("letra") == correct_letter:
                    correct_text = alt.get("texto")
                    break
                    
            random.shuffle(alternativas)
            
            letras = ["A", "B", "C", "D", "E"]
            for idx, alt in enumerate(alternativas):
                new_letter = letras[idx] if idx < len(letras) else str(idx)
                alt["letra"] = new_letter
                if alt.get("texto") == correct_text:
                    q["resposta_correta"] = new_letter
                    
        return shuffled_dict
