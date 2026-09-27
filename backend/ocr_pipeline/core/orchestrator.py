"""
Orquestrador Principal da Pipeline Forense v3.0 — TupiLingo.

Integração de ponta a ponta dos 12 motores forenses:
1. Telemetria e Monitoramento de Memória (ResourceMonitor)
2. Gerenciamento de Checkpoints e Rollback (CheckpointManager & RollbackManager)
3. Diagnóstico Forense Multi-Dimensão (ForensicDiagnosticEngine)
4. Pré-processamento Multi-Branch (MultiBranchPreprocessingEngine)
5. Análise de Layout Estrutural (ForensicLayoutEngine)
6. Super-Resolução Seletiva (ForensicSuperResolutionEngine)
7. Ensemble de Motores OCR (ForensicEnsembleEngine)
8. Votação Ponderada por Token (ForensicTokenVotingEngine)
9. Fusão de Confiança Multi-Fator (ForensicConfidenceFusionEngine)
10. Correção Léxica com Salvaguarda Tupi (ForensicLexicalEngine)
11. Validador RAG Zero Alucinação (RAGValidator)
12. Exportação Arquivística Multi-Formato (ForensicMultiExporter)
"""

from __future__ import annotations

import gc
import logging
import time
from collections.abc import Generator
from pathlib import Path

import numpy as np
from PIL import Image
from pydantic import BaseModel

from ocr_pipeline.confidence_engine.confidence_fusion import (
    ForensicConfidenceFusionEngine,
)
from ocr_pipeline.confidence_engine.token_voting import ForensicTokenVotingEngine
from ocr_pipeline.core.checkpoint_manager import CheckpointManager
from ocr_pipeline.core.config import GLOBAL_CONFIG, ForensePipelineConfig
from ocr_pipeline.core.metrics import ResourceMonitor
from ocr_pipeline.core.provenance import BoundingBox, TokenProvenance
from ocr_pipeline.diagnostic_engine.forensic_analyzer import (
    ForensicDiagnosticEngine,
)
from ocr_pipeline.ensemble_engine.multi_engine import (
    ForensicEnsembleEngine,
)
from ocr_pipeline.export_engine.multi_exporter import (
    ForensicExportBundle,
    ForensicMultiExporter,
)
from ocr_pipeline.layout_engine.doc_layout import ForensicLayoutEngine
from ocr_pipeline.lexical_engine.forensic_lexicon import ForensicLexicalEngine
from ocr_pipeline.preprocessing_engine.multi_branch import (
    MultiBranchPreprocessingEngine,
)
from ocr_pipeline.rag_validation_engine.rag_validator import RAGValidator
from ocr_pipeline.rollback_engine.rollback_manager import (
    IterativeRecoveryEngine,
    RollbackManager,
)
from ocr_pipeline.super_resolution_engine.tile_enhancer import (
    ForensicSuperResolutionEngine,
)

logger = logging.getLogger("ocr_pipeline.orchestrator")


class PageProcessingSummary(BaseModel):
    """Resumo de execução forense de uma página individual."""

    filename: str
    page_num: int
    duration_seconds: float
    mean_confidence: float
    tokens_count: int
    tupi_tokens_count: int
    rollbacks_count: int
    iterations_performed: int
    diagnostic_blur: float
    yellow_paper: bool
    export_bundle: ForensicExportBundle | None = None


class ForensicPipelineOrchestrator:
    """Orquestrador Central Forense TupiLingo v3.0."""

    def __init__(self, config: ForensePipelineConfig | None = None):
        self.config = config or GLOBAL_CONFIG

        # Inicialização dos 12 Motores Forenses
        self.monitor = ResourceMonitor(
            max_memory_mb=self.config.hardware.max_process_memory_mb
        )
        self.checkpoint_manager = CheckpointManager(
            db_path=self.config.checkpoints_dir / "pipeline_checkpoints.db",
            jsonl_path=self.config.checkpoints_dir / "pipeline_progress.jsonl",
        )
        self.diagnostic_engine = ForensicDiagnosticEngine()
        self.preprocessing_engine = MultiBranchPreprocessingEngine()
        self.layout_engine = ForensicLayoutEngine()
        self.super_res_engine = ForensicSuperResolutionEngine(
            tile_size=self.config.hardware.tile_size,
            overlap=self.config.hardware.tile_overlap,
        )
        self.ensemble_engine = ForensicEnsembleEngine(
            cpu_threads=self.config.hardware.cpu_threads
        )
        self.voting_engine = ForensicTokenVotingEngine()
        self.confidence_fusion = ForensicConfidenceFusionEngine()
        self.lexical_engine = ForensicLexicalEngine(
            tupi_vocab_path=self.config.tupi_words_file,
            lexicon_data_path=self.config.lexicon_data_file,
            max_edit_distance=self.config.lexical.max_edit_distance,
        )
        self.rag_validator = RAGValidator(
            vector_store_path=self.config.sqlite_db_path,
            lexicon_data_path=self.config.lexicon_data_file,
        )
        self.rollback_manager = RollbackManager(
            audit_log_path=self.config.checkpoints_dir / "forensic_audit_trail.jsonl"
        )
        self.recovery_engine = IterativeRecoveryEngine(
            rollback_manager=self.rollback_manager,
            max_iterations=self.config.max_iterative_recovery_steps,
        )
        self.exporter = ForensicMultiExporter(output_dir=self.config.exports_dir)

    def process_page(
        self,
        image_rgb: np.ndarray,
        page_num: int,
        filename: str,
        force_reprocess: bool = False,
    ) -> PageProcessingSummary:
        """
        Executa a pipeline forense completa sobre a imagem de uma única página.
        Garante isolamento de memória e checkpoints persistentes.
        """
        t0 = time.time()

        # 0. Checagem de Checkpoint (evita reprocessamento se já concluído)
        if not force_reprocess and self.checkpoint_manager.is_page_completed(filename, page_num):
            logger.info(f"Página {page_num} de {filename} já concluída no checkpoint. Pulando.")
            return PageProcessingSummary(
                filename=filename,
                page_num=page_num,
                duration_seconds=0.0,
                mean_confidence=1.0,
                tokens_count=0,
                tupi_tokens_count=0,
                rollbacks_count=0,
                iterations_performed=0,
                diagnostic_blur=0.0,
                yellow_paper=False,
            )

        pil_img = Image.fromarray(image_rgb)

        # 1. Diagnóstico Forense Completo (12 dimensões)
        diag_report = self.diagnostic_engine.analyze_image(pil_img, page_num=page_num)

        # 2. Pré-processamento Adaptativo
        primary_branch = "clahe"
        if diag_report.yellow_paper or diag_report.bleed:
            primary_branch = "sauvola"
        elif diag_report.blur_score < 0.5:
            primary_branch = "retinex"

        preprocessed_pil = self.preprocessing_engine.process_branch(pil_img, primary_branch)

        # 3. Análise de Layout
        layout_regions = self.layout_engine.analyze_layout(pil_img)

        # 4. OCR Ensemble Multi-Motor (RapidOCR + Tesseract multi-PSM)
        candidates = self.ensemble_engine.run_ensemble(
            pil_img=preprocessed_pil,
            psms=self.config.ensemble.tesseract_psms,
            branch=primary_branch,
            dpi=300,
        )

        # 5. Votação de Tokens & Agrupamento
        voted_tokens: list[TokenProvenance] = []
        raw_words: list[str] = []

        # Separar candidatos individuais ou em linha
        for cand in candidates:
            # Tokenizar o texto reconhecido pelo motor
            words = cand.text.split()
            if not words:
                continue

            # Distribuir bboxes aproximados para cada palavra ao longo da largura da linha
            line_w = cand.bbox.x2 - cand.bbox.x1
            word_w = max(1, line_w // max(len(words), 1))

            for w_idx, w_text in enumerate(words):
                w_x1 = cand.bbox.x1 + (w_idx * word_w)
                w_x2 = min(cand.bbox.x2, w_x1 + word_w)
                w_bbox = BoundingBox(x1=w_x1, y1=cand.bbox.y1, x2=w_x2, y2=cand.bbox.y2)

                tok_dict = {
                    "text": w_text,
                    "confidence": cand.confidence,
                    "engine": cand.engine,
                }
                w_text_voted, w_conf_voted, w_eng, _ = self.voting_engine.vote_on_candidates(
                    [tok_dict]
                )

                tok_prov = TokenProvenance(
                    raw_text=w_text_voted,
                    cleaned_text=w_text_voted,
                    confidence_raw=float(w_conf_voted),
                    confidence_fused=float(w_conf_voted),
                    engine_origin=w_eng,
                    bbox=w_bbox,
                    dpi=cand.dpi,
                    preprocessing_branch=primary_branch,
                )
                voted_tokens.append(tok_prov)
                raw_words.append(w_text_voted)

        # 6. Correção Léxica Forense e Salvaguarda Tupi
        full_raw_text = " ".join(raw_words)
        token_confs = [t.confidence_raw for t in voted_tokens]
        lex_result = self.lexical_engine.process_text(
            full_raw_text, token_confidences=token_confs
        )

        # 7. Validação RAG Zero Alucinação
        corrected_words = [w for w in lex_result.corrected_text.split() if w]
        rag_results = self.rag_validator.validate_page_tokens(corrected_words)

        # 8. Fusão de Confiança & Rollback Invariante
        final_provenance_tokens: list[TokenProvenance] = []
        rollbacks_in_page = len(lex_result.corrections_rolled_back)

        for idx, tok in enumerate(voted_tokens):
            cw = corrected_words[idx] if idx < len(corrected_words) else tok.cleaned_text
            rag_res = rag_results[idx] if idx < len(rag_results) else None
            rag_score = rag_res.rag_confidence_score if rag_res else 0.50

            # Fusão Composta
            fused_score = (
                self.confidence_fusion.fuse_confidence(
                    ocr_conf=(
                        tok.confidence_raw * 100.0
                        if tok.confidence_raw <= 1.0
                        else tok.confidence_raw
                    ),
                    visual_conf=85.0 if diag_report.blur_score >= 0.5 else 65.0,
                    lexical_conf=95.0 if tok.cleaned_text == cw else 85.0,
                    rag_conf=rag_score * 100.0,
                )
                / 100.0
            )

            # Rollback Gate para Invariantes
            final_word, final_conf, was_rolled_back = self.rollback_manager.evaluate_and_enforce(
                original_token=tok.cleaned_text,
                proposed_token=cw,
                conf_before=tok.confidence_raw,
                conf_after=fused_score,
                page_num=page_num,
                engine=tok.engine_origin,
                bbox=tok.bbox,
            )
            if was_rolled_back:
                rollbacks_in_page += 1

            tok.cleaned_text = final_word
            tok.confidence_fused = final_conf
            tok.rag_verified = rag_res.exists_in_corpus if rag_res else False
            tok.is_rollback = was_rolled_back
            final_provenance_tokens.append(tok)

        # 9. Geração de Visual (Heatmap Forense)
        tok_dicts = [
            {"bbox": t.bbox, "confidence": t.confidence_fused * 100.0}
            for t in final_provenance_tokens
        ]
        heatmap_pil = self.confidence_fusion.generate_confidence_heatmap(
            pil_img=pil_img,
            tokens=tok_dicts,
        )
        heatmap_path = self.config.exports_dir / f"page_{page_num:04d}_heatmap.png"
        heatmap_pil.save(str(heatmap_path))

        # 10. Exportação Multi-Formato Arquivística
        final_transcription = " ".join([t.cleaned_text for t in final_provenance_tokens])
        diag_meta = {
            "blur_score": diag_report.blur_score,
            "skew_angle": diag_report.skew_angle,
            "yellow_paper": diag_report.yellow_paper,
            "bleed": diag_report.bleed,
            "ink_loss": diag_report.ink_loss,
        }
        export_bundle = self.exporter.export_all(
            page_num=page_num,
            transcription_text=final_transcription,
            tokens=final_provenance_tokens,
            diagnostic_meta=diag_meta,
        )

        duration = time.time() - t0
        mean_conf = (
            float(np.mean([t.confidence_fused for t in final_provenance_tokens]))
            if final_provenance_tokens
            else 0.0
        )

        # 11. Salvar Checkpoint Persistente
        self.checkpoint_manager.record_page(
            filename=filename,
            page_num=page_num,
            status="completed",
            metrics={
                "duration_seconds": duration,
                "mean_confidence": mean_conf,
                "tokens_count": len(final_provenance_tokens),
                "tupi_tokens": lex_result.tupi_tokens_count,
                "rollbacks": rollbacks_in_page,
            },
        )

        # 12. Limpeza forçada de memória
        if self.config.hardware.enable_memory_cleanup:
            gc.collect()

        return PageProcessingSummary(
            filename=filename,
            page_num=page_num,
            duration_seconds=duration,
            mean_confidence=mean_conf,
            tokens_count=len(final_provenance_tokens),
            tupi_tokens_count=lex_result.tupi_tokens_count,
            rollbacks_count=rollbacks_in_page,
            iterations_performed=1,
            diagnostic_blur=diag_report.blur_score,
            yellow_paper=diag_report.yellow_paper,
            export_bundle=export_bundle,
        )

    def process_pdf(
        self,
        pdf_path: Path,
        max_pages: int | None = None,
        start_page: int = 1,
    ) -> Generator[PageProcessingSummary, None, None]:
        """
        Processa um PDF histórico por streaming de páginas (sem carregar PDF inteiro na RAM).
        """
        import fitz

        doc = fitz.open(pdf_path)
        total_pages = len(doc)
        filename = pdf_path.name
        end_page = min(total_pages, start_page + max_pages - 1) if max_pages else total_pages

        for p_idx in range(start_page - 1, end_page):
            page_num = p_idx + 1
            page = doc.load_page(p_idx)
            zoom = 300.0 / 72.0
            mat = fitz.Matrix(zoom, zoom)
            pix = page.get_pixmap(matrix=mat, alpha=False)

            img = np.frombuffer(pix.samples, dtype=np.uint8).reshape(pix.height, pix.width, 3)

            summary = self.process_page(img, page_num=page_num, filename=filename)
            yield summary

            del pix
            del img
            if self.config.hardware.enable_memory_cleanup:
                gc.collect()

        doc.close()
