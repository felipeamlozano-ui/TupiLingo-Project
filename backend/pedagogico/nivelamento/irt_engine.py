"""
TupiLingo — Motor de Nivelamento Adaptativo TRI (Item Response Theory - Modelo 3PL)
Substitui o antigo questionário estático de 10 perguntas por um Teste Adaptativo Computadorizado (CAT).
Características:
  - Modelo 3PL: Discriminação (a), Dificuldade (b) e Pseudo-chance (c).
  - Ponto de partida calibrado por autodeclaração prévia (Iniciante, Intermediário, Avançado).
  - Seleção por Máxima Informação de Fisher adaptativa ao theta corrente.
  - Critério de Parada Dinâmico: SE < 0.30 ou Máximo de Itens (15-20).
  - Detecção de Inconsistência e Chute.
  - Mapeamento determinístico de Theta -> Capítulo de Entrada na Trilha Única.
"""

from __future__ import annotations

import json
import math
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

BASE_DIR = Path(__file__).resolve().parent
ITEM_BANK_FILE = BASE_DIR / "item_bank_irt.json"
MAPPING_FILE = BASE_DIR / "theta_chapter_mapping.json"

SCALING_D = 1.702


class IRTEngine:
    def __init__(self, item_bank_path: Path = ITEM_BANK_FILE, mapping_path: Path = MAPPING_FILE):
        self.item_bank_path = item_bank_path
        self.mapping_path = mapping_path
        self.items_by_id: Dict[str, Dict[str, Any]] = {}
        self.items_by_variant: Dict[str, List[Dict[str, Any]]] = {}
        self.mapping_config: Dict[str, Any] = {}
        self._load_data()

    def _load_data(self) -> None:
        if self.item_bank_path.exists():
            with open(self.item_bank_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                for it in data.get("items", []):
                    self.items_by_id[it["id"]] = it
                    var = it["variante"]
                    self.items_by_variant.setdefault(var, []).append(it)

        if self.mapping_path.exists():
            with open(self.mapping_path, "r", encoding="utf-8") as f:
                self.mapping_config = json.load(f)

    @staticmethod
    def probability_3pl(theta: float, a: float, b: float, c: float) -> float:
        """Calcula a probabilidade de acerto P(theta) pelo modelo logístico de 3 parâmetros."""
        exponent = -SCALING_D * a * (theta - b)
        # Proteção contra overflow/underflow
        if exponent > 40.0:
            p_star = 0.0
        elif exponent < -40.0:
            p_star = 1.0
        else:
            p_star = 1.0 / (1.0 + math.exp(exponent))
        return c + (1.0 - c) * p_star

    @classmethod
    def fisher_information(cls, theta: float, a: float, b: float, c: float) -> float:
        """Calcula a Informação de Fisher I(theta) para um item específico."""
        p = cls.probability_3pl(theta, a, b, c)
        q = 1.0 - p
        if p <= c or q <= 0.0:
            return 0.0
        p_star = (p - c) / (1.0 - c)
        num = (SCALING_D * a) ** 2 * q * (p_star ** 2)
        return num / p

    @classmethod
    def test_information(cls, theta: float, items: List[Dict[str, Any]]) -> float:
        """Informação total do teste no theta especificado."""
        return sum(
            cls.fisher_information(
                theta,
                it.get("param_a", 1.2),
                it.get("param_b", 0.0),
                it.get("param_c", 0.25)
            )
            for it in items
        )

    @classmethod
    def standard_error(cls, theta: float, administered_items: List[Dict[str, Any]]) -> float:
        """Calcula o Erro Padrão da estimativa de habilidade: SE(theta) = 1 / sqrt(I(theta))."""
        info = cls.test_information(theta, administered_items)
        if info <= 0.0001:
            return 1.5
        return 1.0 / math.sqrt(info)

    @staticmethod
    def initialize_theta_from_self_declaration(declaration: str) -> Tuple[float, float]:
        """
        Define a estimativa inicial theta_0 e sua incerteza inicial
        com base na autodeclaração do usuário (Iniciante, Intermediário, Avançado).
        """
        d = str(declaration).lower().strip()
        if "avanc" in d:
            return 1.5, 1.0
        elif "inter" in d:
            return 0.0, 1.0
        else:  # iniciante (default seguro)
            return -1.5, 1.0

    def select_next_item(
        self,
        current_theta: float,
        variant: str,
        administered_item_ids: Set[str],
        category_counts: Optional[Dict[str, int]] = None
    ) -> Optional[Dict[str, Any]]:
        """
        Seleciona adaptativamente o próximo item que maximiza a Informação de Fisher
        no theta corrente, garantindo amostragem equilibrada de categorias.
        """
        pool = self.items_by_variant.get(variant, [])
        candidates = [it for it in pool if it["id"] not in administered_item_ids]
        if not candidates:
            return None

        cat_counts = category_counts or {}

        def item_score(it: Dict[str, Any]) -> float:
            info = self.fisher_information(
                current_theta,
                it.get("param_a", 1.2),
                it.get("param_b", 0.0),
                it.get("param_c", 0.25)
            )
            cat = it.get("categoria", "geral")
            # Bonifica categorias ainda sub-amostradas
            cat_penalty = cat_counts.get(cat, 0) * 0.15
            return info - cat_penalty

        return max(candidates, key=item_score)

    def estimate_ability_eap(
        self,
        responses: List[Dict[str, Any]],
        prior_mean: float = 0.0,
        prior_sd: float = 1.0,
        quadrature_points: int = 41
    ) -> Tuple[float, float]:
        """
        Estimação de Habilidade por Máxima Verossimilhança Bayesiana (EAP - Expected A Posteriori).
        Utiliza quadratura gaussiana de -4.0 a +4.0.
        Retorna (theta_estimado, erro_padrao).
        """
        if not responses:
            return prior_mean, prior_sd

        # Pontos de quadratura de -4.0 a +4.0
        min_theta = -4.0
        max_theta = 4.0
        step = (max_theta - min_theta) / (quadrature_points - 1)
        thetas = [min_theta + i * step for i in range(quadrature_points)]

        # Pesos da priori normal
        prior_weights = [
            (1.0 / (prior_sd * math.sqrt(2 * math.pi))) * math.exp(-0.5 * ((t - prior_mean) / prior_sd) ** 2)
            for t in thetas
        ]

        posteriors = []
        for t, prior in zip(thetas, prior_weights):
            log_lik = 0.0
            for r in responses:
                item_id = r["item_id"]
                is_correct = bool(r.get("is_correct", False))
                it = self.items_by_id.get(item_id, {})
                a = it.get("param_a", 1.2)
                b = it.get("param_b", 0.0)
                c = it.get("param_c", 0.25)
                p = self.probability_3pl(t, a, b, c)
                log_lik += math.log(max(1e-10, p if is_correct else (1.0 - p)))

            lik = math.exp(max(-100.0, log_lik))
            posteriors.append(lik * prior)

        sum_post = sum(posteriors)
        if sum_post <= 0.0:
            return prior_mean, prior_sd

        # Média e desvio a posteriori
        theta_eap = sum(t * post for t, post in zip(thetas, posteriors)) / sum_post
        var_eap = sum(((t - theta_eap) ** 2) * post for t, post in zip(thetas, posteriors)) / sum_post
        se_eap = math.sqrt(max(0.01, var_eap))

        return round(theta_eap, 3), round(se_eap, 3)

    def check_stopping_criteria(
        self,
        current_se: float,
        num_items: int,
        se_threshold: float = 0.30,
        max_items: int = 15,
        min_items: int = 5
    ) -> bool:
        """Determina se o teste adaptativo deve ser encerrado."""
        if num_items >= max_items:
            return True
        if num_items >= min_items and current_se < se_threshold:
            return True
        return False

    def detect_inconsistency(self, responses: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Detecta aberrações e padrões de chute:
        Ex: Acerto em itens muito difíceis (b > 1.5) somado a erros em itens básicos (b < -1.5).
        """
        hard_correct = 0
        easy_incorrect = 0

        for r in responses:
            it = self.items_by_id.get(r["item_id"], {})
            b = it.get("param_b", 0.0)
            is_correct = bool(r.get("is_correct", False))
            if b >= 1.2 and is_correct:
                hard_correct += 1
            if b <= -1.2 and not is_correct:
                easy_incorrect += 1

        is_suspect = (hard_correct >= 2 and easy_incorrect >= 2)
        return {
            "is_suspected_cheating": is_suspect,
            "hard_correct_count": hard_correct,
            "easy_incorrect_count": easy_incorrect,
            "flag": "OUTLIER_FIT" if is_suspect else "NORMAL"
        }

    def map_theta_to_entry_chapter(self, theta: float) -> Dict[str, Any]:
        """Mapeia theta contínuo [-3.0, +3.0] para o capítulo de entrada na trilha."""
        ranges = self.mapping_config.get("ranges", [])
        for r in ranges:
            if r["theta_min"] <= theta < r["theta_max"]:
                return {
                    "theta": theta,
                    "entry_chapter": r["entry_chapter"],
                    "nivel_descritivo": r["nivel_descritivo"],
                    "subtitulo": r["subtitulo"],
                    "is_advanced_queue": r["entry_chapter"] > 20
                }

        # Fallback para limites
        if theta >= 2.75:
            return {
                "theta": theta,
                "entry_chapter": 21,
                "nivel_descritivo": "Intermediário Avançado (Fila Futura)",
                "subtitulo": "Conteúdo futuro além do capítulo 20",
                "is_advanced_queue": True
            }
        else:
            return {
                "theta": theta,
                "entry_chapter": 1,
                "nivel_descritivo": "Iniciante Absoluto",
                "subtitulo": "Capítulo 1: O Despertar na Aldeia",
                "is_advanced_queue": False
            }
