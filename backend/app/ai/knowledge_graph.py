"""
GraphRAG: Knowledge Graph builder and searcher.
Converte a base vetorial do SQLite em um Grafo NetworkX na memória RAM.
Usa similaridade semântica para criar arestas entre os chunks, imitando o raciocínio humano.
"""

import logging

import networkx as nx
import numpy as np

logger = logging.getLogger(__name__)

_kg_instance = None

class KnowledgeGraphService:
    def __init__(self, vector_db):
        self.db = vector_db
        self.graph = nx.Graph()
        self.is_built = False
        
    def build_graph(self, similarity_threshold: float = 0.6):
        """Constrói o Grafo de Conhecimento na RAM ligando chunks similares."""
        logger.info("[GraphRAG] Construindo Grafo de Conhecimento na RAM...")
        self.graph.clear()
        
        # Obtém todos os metadados (id e dados associados)
        all_metadata = self.db.get_all_metadata()
        if not all_metadata:
            logger.warning("[GraphRAG] Banco de vetores vazio. Grafo não construído.")
            return

        # Para criar as conexões semânticas, precisamos extrair do BD todos os embeddings
        with self.db._connect() as conn:
            rows = conn.execute("SELECT id, document, embedding, metadata FROM documents WHERE embedding IS NOT NULL").fetchall()
            
        nodes_data = []
        import json
        for row in rows:
            doc_id, doc, emb_json, meta_json = row
            try:
                emb = np.array(json.loads(emb_json), dtype=np.float32)
                norm = np.linalg.norm(emb)
                if norm > 0:
                    emb = emb / norm
                meta = json.loads(meta_json) if meta_json else {}
                
                # Adiciona o nó no grafo com seus dados
                self.graph.add_node(doc_id, document=doc, embedding=emb, metadata=meta)
                nodes_data.append((doc_id, emb))
            except Exception as e:
                logger.error(f"[GraphRAG] Erro ao carregar nó {doc_id}: {e}")

        # Computa a similaridade (arestas) NxN
        # Para otimização, como é um grafo de conhecimento de tamanho moderado, faremos o n^2 rápido via numpy
        if nodes_data:
            node_ids = [n[0] for n in nodes_data]
            embs_matrix = np.vstack([n[1] for n in nodes_data])
            
            # Matriz de similaridade cosseno (dot product, pois já estão normalizados)
            similarity_matrix = np.dot(embs_matrix, embs_matrix.T)
            
            edges_added = 0
            for i in range(len(node_ids)):
                for j in range(i + 1, len(node_ids)):
                    if similarity_matrix[i, j] > similarity_threshold:
                        self.graph.add_edge(node_ids[i], node_ids[j], weight=float(similarity_matrix[i, j]))
                        edges_added += 1
                        
            logger.info(f"[GraphRAG] Grafo construído com {len(self.graph.nodes)} nós e {edges_added} arestas.")
        self.is_built = True

    def search_subgraph(self, query_emb: np.ndarray, top_k: int = 3, neighbors: int = 1) -> str:
        """
        Busca o sub-grafo mais relevante:
        1. Acha os top_k nós mais similares ao query (Entry Points).
        2. Traz todos os vizinhos conectados (relacionamentos do Grafo).
        Isso retorna o conhecimento interconectado ao invés de pedaços isolados.
        """
        if not self.is_built or len(self.graph.nodes) == 0:
            return "Nenhum contexto encontrado no Grafo."
            
        query_vec = np.array(query_emb, dtype=np.float32)
        norm = np.linalg.norm(query_vec)
        if norm > 0:
            query_vec = query_vec / norm

        # 1. Encontra os Entry Points (nós vetoriais mais próximos)
        scores = {}
        for node_id, data in self.graph.nodes(data=True):
            emb = data.get('embedding')
            if emb is not None:
                scores[node_id] = float(np.dot(query_vec, emb))
                
        # Top K nós
        sorted_nodes = sorted(scores.items(), key=lambda item: item[1], reverse=True)[:top_k]
        
        # 2. Expansão pelo Grafo (Neighbors)
        selected_nodes = set()
        for node_id, score in sorted_nodes:
            if score > 0.1: # Limiar básico
                selected_nodes.add(node_id)
                # Pega os vizinhos no grafo até N hops (aqui apenas 1)
                for _ in range(neighbors):
                    neighbors_list = list(self.graph.neighbors(node_id))
                    selected_nodes.update(neighbors_list)
                    
        if not selected_nodes:
            return "Nenhum contexto relevante encontrado no Grafo."
            
        # Extrai os textos do sub-grafo
        context_parts = []
        for node_id in selected_nodes:
            doc = self.graph.nodes[node_id].get('document')
            if doc:
                context_parts.append(doc)
                
        return "\n\n---\n\n".join(context_parts)

def get_graph(rebuild: bool = False):
    global _kg_instance
    from app.ai.rag_service import get_db
    
    if _kg_instance is None or rebuild:
        _kg_instance = KnowledgeGraphService(get_db())
        _kg_instance.build_graph()
    return _kg_instance
