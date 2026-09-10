"""
TupiLingo — Supabase Service (RFC v3.0)

Singleton thread-safe para comunicação com o Supabase/PostgreSQL.
Responsável exclusivamente por chamar a RPC ``gerar_esqueleto_quiz``
e retornar os dados lexicais determinísticos para a engine de quiz.

SLA: timeout de 2 s, sem retry (fail-fast).
"""

from __future__ import annotations

import hashlib
import json
import logging
import random
import threading
import time
from typing import Any

import httpx
from app.core.config import settings
from app.schemas.quiz import EsqueletoItem
from pydantic import ValidationError

logger = logging.getLogger(__name__)


# Exceções específicas do serviço


class SupabaseServiceError(Exception):
    """Erro genérico do SupabaseService."""


class SupabaseRPCTimeoutError(SupabaseServiceError):
    """RPC excedeu o timeout configurado."""


class SupabaseRPCError(SupabaseServiceError):
    """Erro retornado pela RPC do PostgreSQL."""


class SupabaseAuthError(SupabaseServiceError):
    """Credenciais ausentes ou inválidas."""


# Singleton


class SupabaseService:
    """
    Singleton thread-safe para o cliente HTTP do Supabase.

    Utiliza ``httpx.Client`` com connection pooling e timeout estrito de 2 s,
    garantindo que uma RPC lenta nunca bloqueie a requisição do usuário além
    do SLA definido na RFC v3.0.

    Uso::

        from app.services.supabase_service import supabase_service
        itens = supabase_service.obter_esqueleto_quiz("tupi", "fauna", 10)
    """

    _instance: SupabaseService | None = None
    _lock: threading.Lock = threading.Lock()

    def __new__(cls) -> SupabaseService:
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialized = False
        return cls._instance

    def __init__(self) -> None:
        if self._initialized:  # type: ignore[has-type]
            return
        with self._lock:
            if self._initialized:
                return
            self._setup()
            self._initialized = True

    def _setup(self) -> None:
        """Configura o cliente HTTP com connection pooling."""
        if not settings.SUPABASE_URL or not settings.SUPABASE_SERVICE_ROLE_KEY:
            raise SupabaseAuthError(
                "SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY são obrigatórios."
            )

        self._base_url = settings.SUPABASE_URL.rstrip("/")
        self._rpc_url = f"{self._base_url}/rest/v1/rpc/gerar_esqueleto_quiz"
        self._headers = {
            "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
            "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }
        # httpx.Client com pool de conexões reutilizáveis e timeout estrito
        self._client = httpx.Client(
            headers=self._headers,
            timeout=httpx.Timeout(
                connect=1.0,   # TCP handshake
                read=2.0,      # Leitura da resposta (SLA da RPC)
                write=1.0,
                pool=0.5,
            ),
            limits=httpx.Limits(
                max_connections=20,
                max_keepalive_connections=10,
                keepalive_expiry=30.0,
            ),
        )
        logger.info(
            "[SupabaseService] Cliente inicializado. RPC URL: %s", self._rpc_url
        )

    # API pública

    def obter_esqueleto_quiz(
        self,
        variante_codigo: str,
        categoria: str = "geral",
        quantidade: int = 10,
    ) -> list[EsqueletoItem]:
        """
        Chama a RPC ``gerar_esqueleto_quiz`` no Supabase e retorna a lista
        de itens lexicais validados via Pydantic.

        Args:
            variante_codigo: Código da variante (ex: ``"tupi"``). Deve corresponder
                a ``VarianteTupi.codigo`` no banco de dados.

            categoria: Categoria lexical para filtro (ex: ``"fauna"``).
            quantidade: Número de questões desejado (1–50).

        Returns:
            Lista de :class:`~app.schemas.quiz.EsqueletoItem` validados.

        Raises:
            SupabaseRPCTimeoutError: Se a RPC não responder em 2 s.
            SupabaseRPCError: Se o Supabase retornar status HTTP >= 400.
            SupabaseServiceError: Para qualquer outro erro de comunicação.
        """
        t_start = time.monotonic()
        request_id = hashlib.md5(
            f"{variante_codigo}:{categoria}:{quantidade}:{t_start}".encode()
        ).hexdigest()[:8]

        payload: dict[str, Any] = {
            "p_variante_codigo": variante_codigo,
            "p_categoria": categoria,
            "p_quantidade": quantidade,
        }

        logger.info(
            "[SupabaseService][%s] Chamando RPC gerar_esqueleto_quiz "
            "variante=%s categoria=%s quantidade=%d",
            request_id,
            variante_codigo,
            categoria,
            quantidade,
        )

        try:
            response = self._client.post(self._rpc_url, json=payload)
        except httpx.TimeoutException as exc:
            latency_ms = int((time.monotonic() - t_start) * 1000)
            logger.error(
                "[SupabaseService][%s] Timeout na RPC após %d ms: %s",
                request_id,
                latency_ms,
                exc,
            )
            raise SupabaseRPCTimeoutError(
                f"RPC gerar_esqueleto_quiz excedeu timeout de 2 s após {latency_ms} ms."
            ) from exc
        except httpx.RequestError as exc:
            logger.error(
                "[SupabaseService][%s] Erro de conexão na RPC: %s", request_id, exc
            )
            raise SupabaseServiceError(f"Erro de conexão com o Supabase: {exc}") from exc

        latency_ms = int((time.monotonic() - t_start) * 1000)

        if response.status_code >= 400:
            logger.error(
                "[SupabaseService][%s] RPC retornou HTTP %d após %d ms. Body: %s",
                request_id,
                response.status_code,
                latency_ms,
                response.text[:500],
            )
            raise SupabaseRPCError(
                f"RPC falhou com HTTP {response.status_code}: {response.text[:200]}"
            )

        logger.info(
            "[SupabaseService][%s] RPC concluída em %d ms.",
            request_id,
            latency_ms,
        )

        return self._parse_response(response.text, request_id, variante_codigo)

    # Helpers privados

    def _parse_response(
        self, raw: str, request_id: str, variante_codigo: str
    ) -> list[EsqueletoItem]:
        """
        Deserializa e valida a resposta JSON da RPC via Pydantic.

        Aceita dois formatos possíveis do Supabase:
        - Array direto: ``[{...}, ...]``
        - Objeto com chave ``data``: ``{"data": [...]}``
        """
        try:
            data: Any = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise SupabaseRPCError(
                f"Resposta da RPC não é JSON válido: {exc}"
            ) from exc

        # Normaliza o formato de saída
        if isinstance(data, dict):
            data = data.get("data", [])

        if not isinstance(data, list):
            raise SupabaseRPCError(
                f"Formato inesperado da RPC: esperado lista, recebido {type(data).__name__}."
            )

        if not data:
            logger.warning(
                "[SupabaseService][%s] RPC retornou lista vazia para variante=%s. "
                "Verifique se há VocabularyItems cadastrados.",
                request_id,
                variante_codigo,
            )
            return []

        itens: list[EsqueletoItem] = []
        for i, raw_item in enumerate(data):
            try:
                itens.append(EsqueletoItem.model_validate(raw_item))
            except ValidationError as exc:
                logger.warning(
                    "[SupabaseService][%s] Item %d inválido (ignorado): %s",
                    request_id,
                    i,
                    exc,
                )
                # Degradação graciosa: ignora itens malformados
                continue

        return itens

    def obter_chunks_rag(
        self,
        categorias: list[str] | str = "Vocabulário",
        limite: int = 3,
    ) -> list[dict[str, Any]]:
        """
        Recupera chunks autênticos do RAG (PDFs) no Supabase filtrados por categorias.
        Executa via RPC otimizada com fallback gracioso para PostgREST em caso de falha.

        Args:
            categorias: Categoria ou lista de categorias (ex: ["História", "Gramática"]).
            limite: Número máximo de chunks a recuperar (default: 3).

        Returns:
            Lista de dicionários contendo {'id', 'chunk_id', 'document_text', 'categoria'}.
        """
        t_start = time.monotonic()

        # Normaliza parâmetro para lista de strings
        if isinstance(categorias, str):
            cats_list = [categorias]
        else:
            cats_list = list(categorias) if categorias else ["Vocabulário"]

        payload: dict[str, Any] = {
            "p_categorias": cats_list,
            "p_limite": limite,
        }

        # ── 1. Tentativa Primária: Chamada RPC ────────────────────────────────
        try:
            url_rpc = f"{self._base_url}/rest/v1/rpc/obter_chunks_rag"
            response = self._client.post(url_rpc, json=payload)
            if response.status_code == 200:
                data = response.json()
                if isinstance(data, list) and data:
                    logger.info(
                        "[SupabaseService] RPC obter_chunks_rag retornou %d chunks em %d ms.",
                        len(data),
                        int((time.monotonic() - t_start) * 1000),
                    )
                    return data
        except Exception as rpc_exc:
            logger.warning(
                "[SupabaseService] Falha na RPC obter_chunks_rag (%s). Acionando fallback REST.",
                rpc_exc,
            )

        # ── 2. Fallback Secundário: Consulta Direta via PostgREST ─────────────
        try:
            cats_formatted = ",".join(f'"{c}"' for c in cats_list)
            offset_aleatorio = random.randint(0, 100)

            params = {
                "categoria": f"in.({cats_formatted})",
                "select": "id,chunk_id,document_text,categoria",
                "limit": str(limite),
                "offset": str(offset_aleatorio),
            }
            url_table = f"{self._base_url}/rest/v1/rag_document_categories"
            response = self._client.get(url_table, params=params)

            if response.status_code == 200:
                data = response.json()
                if isinstance(data, list) and data:
                    logger.info(
                        "[SupabaseService] Fallback REST retornou %d chunks em %d ms.",
                        len(data),
                        int((time.monotonic() - t_start) * 1000),
                    )
                    return data
        except Exception as rest_exc:
            logger.error("[SupabaseService] Fallback REST também falhou: %s", rest_exc)

        return []


# Instância global (lazy initialization)

supabase_service = SupabaseService()
