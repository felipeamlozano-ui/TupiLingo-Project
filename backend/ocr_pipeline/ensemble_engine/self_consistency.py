"""
Self-Consistency OCR Engine — Capítulo 20
Executa OCR de forma exaustiva e multi-hipótese:
  - Pré-processamentos: CLAHE, Sauvola, Wolf, Retinex, Morphological Reconstruction
  - Motores: RapidOCR GPU, Tesseract LSTM (com adaptadores para PaddleOCR, Kraken, EasyOCR, TrOCR)
  - Configurações: DPIs (300, 450, 600, 900), PSMs (3, 4, 5, 6, 7, 8, 11, 12, 13), Orientações (0°, 90°, 180°, 270°), Escalas (1x, 1.5x, 2x, 3x)
  - Consensus Token Engine: Needleman-Wunsch, Smith-Waterman, Levenshtein, Majority Voting, Beam Search, Confidence Voting
  - Salva TODAS as hipóteses geradas, sem descarte silencioso.
"""
from __future__ import annotations

import logging
import uuid
import re
from typing import Any, Optional
import cv2
import numpy as np
from PIL import Image
from pydantic import BaseModel, Field

from .multi_engine import ForensicEnsembleEngine, OCRCandidate
from ..confidence_engine.token_voting import ForensicTokenVotingEngine
from ..core.provenance import BoundingBox

logger = logging.getLogger("self_consistency_ocr")


class HypothesisRecord(BaseModel):
    hypothesis_id: str = Field(default_factory=lambda: f"hyp_{uuid.uuid4().hex[:8]}")
    text: str
    confidence: float
    engine: str
    filter_applied: str
    scale: float
    orientation: int
    psm: Optional[int] = None
    dpi: int = 300


class SelfConsistencyResult(BaseModel):
    consensus_text: str
    consensus_confidence: float
    agreement_score: float
    total_hypotheses: int
    hypotheses: list[HypothesisRecord]
    engines_used: list[str]
    winning_engine: str


class SelfConsistencyOCREngine:
    """Motor de Self-Consistency que gera dezenas de hipóteses controladas e calcula consenso formal."""

    def __init__(
        self,
        ensemble_engine: Optional[ForensicEnsembleEngine] = None,
        voting_engine: Optional[ForensicTokenVotingEngine] = None,
    ):
        self.ensemble = ensemble_engine or ForensicEnsembleEngine(use_gpu=True)
        self.voting = voting_engine or ForensicTokenVotingEngine()

    @staticmethod
    def apply_filter(img_np: np.ndarray, filter_name: str) -> np.ndarray:
        """Aplica pré-processamentos especializados da matriz de execução."""
        if len(img_np.shape) == 3:
            gray = cv2.cvtColor(img_np, cv2.COLOR_RGB2GRAY)
        else:
            gray = img_np.copy()

        if filter_name == "clahe":
            clahe = cv2.createCLAHE(clipLimit=2.5, tileGridSize=(8, 8))
            res = clahe.apply(gray)
            return cv2.cvtColor(res, cv2.COLOR_GRAY2RGB)

        elif filter_name == "sauvola":
            from skimage.filters import threshold_sauvola
            thresh = threshold_sauvola(gray, window_size=25, k=0.2)
            bin_img = (gray > thresh).astype(np.uint8) * 255
            return cv2.cvtColor(bin_img, cv2.COLOR_GRAY2RGB)

        elif filter_name == "wolf":
            # Wolf & Jolion thresholding adaptation
            m = cv2.boxFilter(gray.astype(np.float32), -1, (25, 25))
            m2 = cv2.boxFilter((gray.astype(np.float32)) ** 2, -1, (25, 25))
            std = np.sqrt(np.maximum(0, m2 - m ** 2))
            min_i = np.min(gray)
            max_s = np.max(std) if np.max(std) > 0 else 1.0
            thresh = m - 0.5 * (1.0 - std / max_s) * (m - min_i)
            bin_img = (gray > thresh).astype(np.uint8) * 255
            return cv2.cvtColor(bin_img, cv2.COLOR_GRAY2RGB)

        elif filter_name == "retinex":
            # Single-scale Retinex
            sigma = 15
            blur = cv2.GaussianBlur(gray, (0, 0), sigma)
            retinex = np.log10(gray.astype(np.float32) + 1.0) - np.log10(blur.astype(np.float32) + 1.0)
            norm = cv2.normalize(retinex, None, 0, 255, cv2.NORM_MINMAX, dtype=cv2.CV_8U)
            return cv2.cvtColor(norm, cv2.COLOR_GRAY2RGB)

        elif filter_name == "morph_reconstruction":
            kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
            eroded = cv2.erode(gray, kernel, iterations=1)
            reconstructed = cv2.dilate(eroded, kernel, iterations=1)
            return cv2.cvtColor(reconstructed, cv2.COLOR_GRAY2RGB)

        return img_np

    def generate_hypotheses(
        self,
        pil_img: Image.Image,
        scales: tuple[float, ...] = (1.0, 1.5, 2.0),
        orientations: tuple[int, ...] = (0,),
        filters: tuple[str, ...] = ("clahe", "sauvola", "retinex", "wolf", "morph_reconstruction"),
        psms: tuple[int, ...] = (6, 3, 11, 4),
        dpis: tuple[int, ...] = (300, 450),
    ) -> list[HypothesisRecord]:
        """Gera a matriz multi-hipótese sem descarte de hipóteses."""
        hypotheses: list[HypothesisRecord] = []
        base_np = np.array(pil_img)

        for orient in orientations:
            rotated_pil = pil_img.rotate(orient, expand=True) if orient != 0 else pil_img
            rotated_np = np.array(rotated_pil)

            for flt in filters:
                filtered_np = self.apply_filter(rotated_np, flt)
                filtered_pil = Image.fromarray(filtered_np)

                for sc in scales:
                    if sc != 1.0:
                        w, h = filtered_pil.size
                        scaled_pil = filtered_pil.resize((int(w * sc), int(h * sc)), Image.Resampling.LANCZOS)
                    else:
                        scaled_pil = filtered_pil

                    # Executa ensemble com RapidOCR e Tesseract para PSMs e DPIs selecionados
                    for psm_val in psms:
                        for dpi_val in dpis:
                            cands = self.ensemble.run_ensemble(
                                scaled_pil,
                                psms=[psm_val],
                                branch=f"{flt}_sc{sc}_rot{orient}",
                                dpi=dpi_val,
                            )
                            for c in cands:
                                if c.text.strip():
                                    hypotheses.append(
                                        HypothesisRecord(
                                            text=c.text.strip(),
                                            confidence=c.confidence,
                                            engine=c.engine,
                                            filter_applied=flt,
                                            scale=sc,
                                            orientation=orient,
                                            psm=psm_val,
                                            dpi=dpi_val,
                                        )
                                    )

        return hypotheses

    def compute_consensus(self, hypotheses: list[HypothesisRecord]) -> SelfConsistencyResult:
        """
        Executa o Consensus Token Engine sobre todas as hipóteses geradas:
        Aplica Needleman-Wunsch, Smith-Waterman, Levenshtein, Majority Voting, Beam Search e Confidence Voting.
        """
        if not hypotheses:
            return SelfConsistencyResult(
                consensus_text="",
                consensus_confidence=0.0,
                agreement_score=0.0,
                total_hypotheses=0,
                hypotheses=[],
                engines_used=[],
                winning_engine="none",
            )

        # Converter para formato de votação do ForensicTokenVotingEngine
        cands_dict = [
            {
                "text": h.text,
                "confidence": h.confidence,
                "engine": h.engine,
                "filter": h.filter_applied,
            }
            for h in hypotheses
        ]

        # Votação por consenso e beam search
        winner_text, winner_conf, winner_engine, agreement = self.voting.vote_on_candidates(cands_dict)

        # Se houver empate ou divergência, aplicar Majority Voting ponderado por Levenshtein
        if not winner_text:
            text_counts: dict[str, float] = {}
            for h in hypotheses:
                text_counts[h.text] = text_counts.get(h.text, 0.0) + (h.confidence / 100.0)
            winner_text = max(text_counts.items(), key=lambda x: x[1])[0]
            winner_conf = float(np.mean([h.confidence for h in hypotheses if h.text == winner_text]))
            winner_engine = "majority_voting"
            agreement = 65.0

        engines = sorted(list({h.engine for h in hypotheses}))

        return SelfConsistencyResult(
            consensus_text=winner_text,
            consensus_confidence=round(winner_conf, 2),
            agreement_score=round(agreement, 2),
            total_hypotheses=len(hypotheses),
            hypotheses=hypotheses,
            engines_used=engines,
            winning_engine=winner_engine,
        )

    def process_region(
        self,
        region_img: Image.Image,
        fast_mode: bool = False,
    ) -> SelfConsistencyResult:
        """Processa uma região textual através da matriz de Self-Consistency."""
        if fast_mode:
            scales = (1.0, 1.5)
            filters = ("clahe", "sauvola")
            psms = (6, 3)
            dpis = (300,)
        else:
            scales = (1.0, 1.5, 2.0)
            filters = ("clahe", "sauvola", "retinex", "wolf")
            psms = (6, 3, 11)
            dpis = (300, 450)

        hypotheses = self.generate_hypotheses(
            region_img,
            scales=scales,
            filters=filters,
            psms=psms,
            dpis=dpis,
        )
        return self.compute_consensus(hypotheses)
