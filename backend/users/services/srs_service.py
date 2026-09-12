"""
Serviço de Repetição Espaçada (SRS) e Mapeamento de Fraquezas do TupiLingo.

Cruza o histórico de respostas do usuário (erros do tipo 'wrong' e 'almost'
gerados pela tolerância do pg_trgm e SM-2) para identificar os termos de
vocabulário que mais necessitam de revisão imediata e reforço pedagógico.
"""

from __future__ import annotations

import logging
from typing import Any

from app.services.supabase_service import supabase_service
from trilha.models import VocabularyItem
from users.models import HistoricoResposta, VocabularyProgress

logger = logging.getLogger("users.services.srs_service")


class SRSService:
    """Gerencia a extração inteligente das palavras de maior dificuldade do aluno."""

    @classmethod
    def obter_palavras_fracas_usuario(
        cls,
        user_id: int,
        variante_id: int | None = None,
        limite: int = 3,
    ) -> list[dict[str, Any]]:
        """
        Retorna os N itens de vocabulário mais críticos para o usuário.
        1. Consulta a RPC get_user_weakest_vocabulary / View de fraquezas no Supabase.
        2. Complementa com HistoricoResposta local (status 'wrong' ou 'almost').
        3. Se insuficiente, complementa com VocabularyProgress (menor ease_factor).
        4. Fallback de segurança: busca termos da variante ativa para garantir N itens.
        """
        palavras_encontradas: list[dict[str, Any]] = []
        palavras_set: set[str] = set()

        # 1. Tentativa via Supabase RPC (View de fraquezas)
        try:
            rpc_res = supabase_service.rpc(
                "get_user_weakest_vocabulary",
                {"p_user_id": user_id, "p_limit": limite},
            )
            if rpc_res and isinstance(rpc_res, list):
                for item in rpc_res:
                    palavra = str(item.get("palavra_tupi", "")).strip()
                    if palavra and palavra.lower() not in palavras_set:
                        palavras_set.add(palavra.lower())
                        palavras_encontradas.append({
                            "palavra_tupi": palavra,
                            "traducao_pt": item.get("traducao_pt") or "",
                            "categoria": item.get("categoria") or "geral",
                            "total_erros": item.get("total_erros") or 1,
                        })
        except Exception as exc:
            logger.debug("[SRSService] RPC get_user_weakest_vocabulary indisponível: %s", exc)

        # 2. Se faltam itens, consulta Django ORM HistoricoResposta
        if len(palavras_encontradas) < limite:
            try:
                from django.db.models import Count, Max
                historico_qs = (
                    HistoricoResposta.objects.filter(
                        user_id=user_id,
                        status__in=["wrong", "almost"],
                    )
                    .values("palavra_tupi", "traducao_pt")
                    .annotate(
                        total_erros=Count("id"),
                        ultimo_erro=Max("created_at"),
                    )
                    .order_by("-total_erros", "-ultimo_erro")
                )

                for row in historico_qs:
                    palavra = str(row["palavra_tupi"]).strip()
                    if palavra and palavra.lower() not in palavras_set:
                        palavras_set.add(palavra.lower())
                        palavras_encontradas.append({
                            "palavra_tupi": palavra,
                            "traducao_pt": row.get("traducao_pt") or "",
                            "categoria": "geral",
                            "total_erros": row["total_erros"],
                        })
                    if len(palavras_encontradas) >= limite:
                        break
            except Exception as exc:
                logger.debug("[SRSService] Consulta local HistoricoResposta falhou: %s", exc)

        # 3. Se ainda faltam itens, consulta SM-2 VocabularyProgress
        if len(palavras_encontradas) < limite:
            try:
                sm2_qs = (
                    VocabularyProgress.objects.filter(usuario_id=user_id)
                    .select_related("item")
                    .order_by("ease_factor", "repetitions")
                )
                for prog in sm2_qs:
                    item_obj = prog.item
                    palavra = item_obj.palavra_tupi.strip()
                    if palavra and palavra.lower() not in palavras_set:
                        palavras_set.add(palavra.lower())
                        palavras_encontradas.append({
                            "palavra_tupi": palavra,
                            "traducao_pt": item_obj.traducao_pt,
                            "categoria": item_obj.categoria or "geral",
                            "total_erros": 1,
                        })
                    if len(palavras_encontradas) >= limite:
                        break
            except Exception as exc:
                logger.debug("[SRSService] Consulta VocabularyProgress falhou: %s", exc)

        # 4. Fallback garantidor: seleciona vocabulário padrão da variante
        if len(palavras_encontradas) < limite:
            try:
                vocab_qs = VocabularyItem.objects.all()
                if variante_id:
                    vocab_qs = vocab_qs.filter(
                        licao__capitulo__trilha__variante_id=variante_id
                    )
                for item_obj in vocab_qs[:(limite - len(palavras_encontradas) + 3)]:
                    palavra = item_obj.palavra_tupi.strip()
                    if palavra and palavra.lower() not in palavras_set:
                        palavras_set.add(palavra.lower())
                        palavras_encontradas.append({
                            "palavra_tupi": palavra,
                            "traducao_pt": item_obj.traducao_pt,
                            "categoria": item_obj.categoria or "geral",
                            "total_erros": 0,
                        })
                    if len(palavras_encontradas) >= limite:
                        break
            except Exception as exc:
                logger.debug("[SRSService] Fallback padrão de vocabulário falhou: %s", exc)

        return palavras_encontradas[:limite]
