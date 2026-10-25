"""
Question Variant Engine (Motor de Variantes & Versões de Exercício)
Garante anti-repetição ativa, contextualização de cena, distratores dinâmicos
e embaralhamento com segurança criptográfica (HMAC) e calibração BirdBrain.
"""

import base64
import copy
import hashlib
import hmac
import json
import logging
import random
import time
from typing import Any, Dict, List, Optional, Tuple

from django.conf import settings
from django.utils import timezone

from trilha.models import Exercicio, ExercicioVersao, Licao
from users.models import ItemExposure, HistoricoResposta, UserProfile

logger = logging.getLogger("trilha.services.question_variant_engine")


class QuestionVariantEngine:
    TOKEN_TTL_SECONDS = 7200  # 2 horas de validade para resolver a lição

    def __init__(self, secret_key: Optional[str] = None):
        self.secret_key = (secret_key or getattr(settings, 'SECRET_KEY', 'default_secret_tupilingo')).encode('utf-8')

    # ─── Utilitários Criptográficos e de Embaralhamento ───────────────────────

    def generate_token(self, payload_dict: Dict[str, Any]) -> str:
        """Gera um token com assinatura HMAC-SHA256 à prova de adulteração."""
        data_json = json.dumps(payload_dict, separators=(',', ':'), sort_keys=True).encode('utf-8')
        b64_data = base64.urlsafe_b64encode(data_json).decode('utf-8')
        signature = hmac.new(self.secret_key, data_json, hashlib.sha256).hexdigest()
        return f"{b64_data}.{signature}"

    def verify_token(self, token: str) -> Optional[Dict[str, Any]]:
        """Verifica a integridade e expiração do token HMAC."""
        if not token or '.' not in token:
            return None
        try:
            b64_data, signature = token.split('.', 1)
            data_json = base64.urlsafe_b64decode(b64_data.encode('utf-8'))
            expected_sig = hmac.new(self.secret_key, data_json, hashlib.sha256).hexdigest()
            if not hmac.compare_digest(signature, expected_sig):
                logger.warning("Token HMAC de exercício com assinatura inválida!")
                return None
            data = json.loads(data_json.decode('utf-8'))
            if data.get('exp', 0) < time.time():
                logger.info("Token HMAC de exercício expirado.")
                return None
            return data
        except Exception as e:
            logger.error("Erro ao decodificar token HMAC de exercício: %s", e)
            return None

    @staticmethod
    def deranged_indices(n: int, rng: Optional[random.Random] = None) -> List[int]:
        """
        Gera uma permutação de 0..n-1 onde nenhum índice permanece na mesma posição
        (desarranjo/derangement estrito para n >= 2).
        """
        if n <= 1:
            return list(range(n))
        r = rng or random.Random()
        original = list(range(n))

        for _ in range(100):
            perm = list(original)
            r.shuffle(perm)
            if all(perm[i] != i for i in range(n)):
                return perm

        # Fallback determinístico de rotação circular
        shift = r.randint(1, n - 1)
        return [(i + shift) % n for i in range(n)]

    # ─── Montagem Dinâmica de Exercícios da Lição ─────────────────────────────

    def build_lesson_items(self, user: UserProfile, licao: Licao) -> List[Dict[str, Any]]:
        """
        Constrói a lista de exercícios para a lição aplicando:
        1. Seleção LRU de versão de exercício (mínimo 3 a 8 versões).
        2. Embaralhamento estável de opções e colunas de associação.
        3. Token HMAC contendo os mapeamentos inversos para verificação à prova de adulteração.
        """
        exercicios_qs = sorted(licao.exercicios.all(), key=lambda x: x.ordem)
        items: List[Dict[str, Any]] = []
        user_theta = 0.0

        profile_user = None
        if user is not None:
            from users.models import UserProfile
            if isinstance(user, UserProfile):
                profile_user = user
            elif hasattr(user, 'profile') and isinstance(user.profile, UserProfile):
                profile_user = user.profile
            else:
                user_email = getattr(user, 'email', None)
                if user_email:
                    profile_user = UserProfile.objects.filter(email=user_email).first()

        try:
            from nivelamento.models import UserVarianteLevel
            variante = licao.capitulo.trilha.variante
            if profile_user:
                lvl = UserVarianteLevel.objects.filter(user=profile_user, variante=variante).first()
                if lvl:
                    user_theta = float(lvl.current_theta)
        except Exception:
            pass

        now_ts = int(time.time())

        for ex in exercicios_qs:
            versoes = list(ex.versoes.all())
            selected_versao: Optional[ExercicioVersao] = None

            if versoes:
                # 1. Rotação LRU de Versões
                # Busca quais versões o usuário já viu recentemente
                exposures = []
                if profile_user:
                    exposures = list(
                        ItemExposure.objects.filter(user=profile_user, exercicio=ex)
                        .order_by('-shown_at')
                        .values_list('versao_id', 'shown_at')[:20]
                    )
                seen_versao_ids = {exp[0] for exp in exposures if exp[0] is not None}
                unseen_versoes = [v for v in versoes if v.id not in seen_versao_ids]

                if unseen_versoes:
                    # Entre as não vistas, escolhe a mais próxima do theta do usuário
                    unseen_versoes.sort(key=lambda v: abs(v.param_b - user_theta))
                    selected_versao = unseen_versoes[0]
                else:
                    # Se já viu todas, escolhe a vista há mais tempo (LRU)
                    last_seen_map = {}
                    for v_id, s_at in exposures:
                        if v_id not in last_seen_map:
                            last_seen_map[v_id] = s_at
                    # Ordena do mais antigo para o mais recente
                    versoes.sort(key=lambda v: last_seen_map.get(v.id, timezone.now()))
                    selected_versao = versoes[0]

            # 2. Extrai dados do exercício base ou da versão selecionada
            tipo = selected_versao.tipo if selected_versao else ex.tipo
            enunciado = selected_versao.enunciado if selected_versao else ex.enunciado
            explicacao = selected_versao.explicacao if selected_versao else ex.explicacao
            contexto_cena = selected_versao.contexto_cena if selected_versao else ""
            pontos_base = ex.pontos_base
            ordem = ex.ordem
            dificuldade = ex.dificuldade

            item_dict: Dict[str, Any] = {
                'id': ex.id,
                'tipo': tipo,
                'enunciado': enunciado,
                'explicacao': explicacao,
                'contexto_cena': contexto_cena,
                'dificuldade': dificuldade,
                'pontos_base': pontos_base,
                'ordem': ordem,
                'midia': ex.midia.url if ex.midia else None,
                'versao_id': selected_versao.id if selected_versao else None,
                'versao_numero': selected_versao.versao_numero if selected_versao else 1,
            }

            token_data: Dict[str, Any] = {
                'ex_id': ex.id,
                'versao_id': selected_versao.id if selected_versao else None,
                'tipo': tipo,
                'exp': now_ts + self.TOKEN_TTL_SECONDS,
            }

            # 3. Tratamento e Embaralhamento por Tipo de Exercício
            if tipo == 'escolha_multipla':
                opcoes_orig = []
                correta_idx = 0
                if selected_versao and selected_versao.payload:
                    opcoes_orig = list(selected_versao.payload.get('opcoes', []))
                    correta_idx = int(selected_versao.payload.get('resposta_correta', 0))
                else:
                    opcoes_orig = list(ex.opcoes or [])
                    correta_idx = int(ex.resposta_correta or 0)

                n_opts = len(opcoes_orig)
                if n_opts >= 2:
                    # Embaralha com permutação aleatória
                    perm = list(range(n_opts))
                    random.shuffle(perm)
                    # perm[new_pos] = old_pos
                    shuffled_opcoes = [opcoes_orig[perm[i]] for i in range(n_opts)]
                    new_correta_idx = perm.index(correta_idx) if correta_idx in perm else 0

                    item_dict['opcoes'] = shuffled_opcoes
                    token_data['perm_opcoes'] = perm
                    token_data['correta_orig'] = correta_idx
                    token_data['correta_shuffled'] = new_correta_idx
                else:
                    item_dict['opcoes'] = opcoes_orig
                    token_data['perm_opcoes'] = list(range(n_opts))
                    token_data['correta_orig'] = correta_idx
                    token_data['correta_shuffled'] = correta_idx

            elif tipo == 'completar':
                if selected_versao and selected_versao.payload:
                    item_dict['texto_com_lacunas'] = selected_versao.payload.get('texto_com_lacunas', '')
                    item_dict['tolerancia_levenshtein'] = selected_versao.payload.get('tolerancia_levenshtein', 2)
                    item_dict['banco_palavras'] = selected_versao.payload.get('banco_palavras', [])
                else:
                    item_dict['texto_com_lacunas'] = ex.texto_com_lacunas or ''
                    item_dict['tolerancia_levenshtein'] = ex.tolerancia_levenshtein
                    item_dict['banco_palavras'] = []

            elif tipo == 'associacao':
                col_esq = []
                col_dir = []
                assoc_orig: Dict[str, str] = {}

                if selected_versao and selected_versao.payload:
                    col_esq = list(selected_versao.payload.get('coluna_esquerda', []))
                    col_dir = list(selected_versao.payload.get('coluna_direita', []))
                    assoc_orig = dict(selected_versao.payload.get('associacao_correta', {}))
                else:
                    col_esq = list(ex.coluna_esquerda or [])
                    col_dir = list(ex.coluna_direita or [])
                    assoc_orig = dict(ex.associacao_correta or {})

                n_dir = len(col_dir)
                if n_dir >= 2:
                    # Aplica derangement estrito garantindo que a coluna direita NUNCA venha linear!
                    perm_dir = self.deranged_indices(n_dir)
                    # perm_dir[new_slot] = orig_index
                    shuffled_dir = [col_dir[perm_dir[slot]] for slot in range(n_dir)]
                    # Mapeamento reverso para validação
                    # orig_to_new[orig_idx] = new_slot
                    orig_to_new = {perm_dir[slot]: slot for slot in range(n_dir)}

                    # Nova associação esperada para a coluna direita embaralhada
                    assoc_shuffled: Dict[str, str] = {}
                    for esq_idx_str, dir_orig_idx_str in assoc_orig.items():
                        orig_idx = int(dir_orig_idx_str)
                        if orig_idx in orig_to_new:
                            assoc_shuffled[esq_idx_str] = str(orig_to_new[orig_idx])

                    item_dict['coluna_esquerda'] = col_esq
                    item_dict['coluna_direita'] = shuffled_dir
                    token_data['perm_dir'] = perm_dir
                    token_data['assoc_orig'] = assoc_orig
                    token_data['assoc_shuffled'] = assoc_shuffled
                else:
                    item_dict['coluna_esquerda'] = col_esq
                    item_dict['coluna_direita'] = col_dir
                    token_data['perm_dir'] = list(range(n_dir))
                    token_data['assoc_orig'] = assoc_orig
                    token_data['assoc_shuffled'] = assoc_orig

            # Gera token seguro para esse item
            item_dict['variant_token'] = self.generate_token(token_data)
            items.append(item_dict)

            # Registra a exposição inicial
            try:
                ItemExposure.objects.create(
                    user=user,
                    exercicio=ex,
                    versao=selected_versao,
                    shown_at=timezone.now(),
                )
            except Exception as e:
                logger.error("Falha ao registrar ItemExposure para user %s: %s", user.id, e)

        return items

    # ─── Resolução e Des-permutação de Submissão ──────────────────────────────

    def resolve_submission(
        self,
        token_str: Optional[str],
        submission_body: Dict[str, Any]
    ) -> Tuple[Dict[str, Any], Optional[ExercicioVersao], Optional[Dict[str, Any]]]:
        """
        Recebe a submissão do cliente. Se vier acompanhada de variant_token,
        desfaz as permutações para comparar de volta com o gabarito original.
        Retorna (body_normalizado, versao_ou_none, token_data_ou_none).
        """
        normalized_body = copy.deepcopy(submission_body)
        if not token_str:
            return normalized_body, None, None

        token_data = self.verify_token(token_str)
        if not token_data:
            return normalized_body, None, None

        versao_id = token_data.get('versao_id')
        versao: Optional[ExercicioVersao] = None
        if versao_id:
            versao = ExercicioVersao.objects.filter(id=versao_id).first()

        tipo = token_data.get('tipo')

        if tipo == 'escolha_multipla':
            # Cliente enviou resposta_indice baseado nas opções que viu na tela
            perm_opcoes = token_data.get('perm_opcoes', [])
            shuffled_idx = normalized_body.get('resposta_indice')
            if shuffled_idx is not None and isinstance(shuffled_idx, int) and 0 <= shuffled_idx < len(perm_opcoes):
                # Desfaz a permutação: recupera qual era o índice original daquela opção
                original_idx = perm_opcoes[shuffled_idx]
                normalized_body['resposta_indice_original'] = original_idx
                normalized_body['resposta_indice_shuffled'] = shuffled_idx

        elif tipo == 'associacao':
            # Cliente enviou associacoes: { "esq_idx": "dir_slot_shuffled" }
            perm_dir = token_data.get('perm_dir', [])
            assoc_client = normalized_body.get('associacoes', {})
            assoc_despermutada: Dict[str, str] = {}

            for esq_k, dir_slot in assoc_client.items():
                slot_int = int(dir_slot)
                if 0 <= slot_int < len(perm_dir):
                    orig_dir_idx = perm_dir[slot_int]
                    assoc_despermutada[str(esq_k)] = str(orig_dir_idx)

            normalized_body['associacoes_originais'] = assoc_despermutada
            normalized_body['associacoes_shuffled'] = assoc_client

        return normalized_body, versao, token_data
