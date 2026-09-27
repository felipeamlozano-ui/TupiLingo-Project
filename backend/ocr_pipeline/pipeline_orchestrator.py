"""
Orquestrador do Pipeline de OCR (Fase 0 e Fase 1).
Integra os workers modulares:
  - QualityWorker (Fase 0: Profiler + Score calibrado)
  - PreprocessingWorker (Deskew + Sauvola bleed-through + Lanczos)
  - LayoutWorker (XY-Cut 2 colunas)
  - OCRWorker (Dual-engine Tesseract + RapidOCR com votação e NFC)
  - LexiconWorker (SymSpell com salvaguarda Tupi)
  - ConfidenceWorker (Grafo de confiança composto + auditoria)
  - ChunkWorker (Chunking consciente de dicionário com herança de lema)
"""
import time
from pathlib import Path

from PIL import Image

from .chunk_worker import ChunkWorker
from .confidence_worker import ConfidenceWorker
from .layout_worker import LayoutWorker
from .lexicon_worker import LexiconWorker
from .models import (
    DictionaryChunk,
    OCRPageResult,
    PageAuditRecord,
    PageProfile,
    PageType,
    RoutingDecision,
)
from .ocr_worker import OCRWorker
from .preprocessing_worker import PreprocessingWorker
from .quality_worker import QualityWorker


class PipelineOrchestrator:
    def __init__(
        self,
        tupi_words_path: Path | None = None,
        lexicon_data_path: Path | None = None,
        cpu_threads: int = 4
    ):
        self.quality_worker = QualityWorker()
        self.preprocessing_worker = PreprocessingWorker()
        self.layout_worker = LayoutWorker()
        self.ocr_worker = OCRWorker(
            tupi_words_path=str(tupi_words_path) if tupi_words_path else None,
            cpu_threads=cpu_threads
        )
        self.lexicon_worker = LexiconWorker(
            tupi_words_file=tupi_words_path,
            lexicon_data_path=lexicon_data_path
        )
        self.confidence_worker = ConfidenceWorker()
        self.chunk_worker = ChunkWorker()

    def process_page(
        self,
        pil_img: Image.Image,
        filename: str,
        page_num: int,
        historical_ocr_conf: float | None = None,
        precisa_revisao_hist: bool = False,
        page_type: PageType = PageType.SCAN,
        dpi_effective: int = 300,
        force_phase1: bool = False
    ) -> tuple[PageProfile, OCRPageResult | None, list[DictionaryChunk], PageAuditRecord]:
        """
        Executa o pipeline completo:
          1. Fase 0: Document Profiler + Quality Score Engine.
          2. Roteamento: se score < 94 ou force_phase1: aplica Fase 1.
          3. Auditoria completa gerada para cada página.
        """
        t0 = time.time()

        # ── FASE 0: PERFILAMENTO E QUALIDADE ─────────────────────────────────
        profile = self.quality_worker.profile_page(
            pil_image=pil_img,
            filename=filename,
            page_num=page_num,
            historical_ocr_conf=historical_ocr_conf,
            precisa_revisao_hist=precisa_revisao_hist,
            page_type=page_type,
            dpi_effective=dpi_effective,
            use_cache=True
        )

        should_run_phase1 = force_phase1 or (profile.quality_score < 94.0)

        # Se for roteado para OCR rápido/padrão (score >= 94) e não for forçado
        if not should_run_phase1:
            elapsed = time.time() - t0
            audit = self.confidence_worker.build_audit_record(
                filename=filename,
                page_num=page_num,
                quality_score=profile.quality_score,
                routing_decision=profile.routing_decision.value,
                preprocessing_applied=["bypass_existing_pipeline"],
                engine_used="baseline_existing",
                confidence_before=historical_ocr_conf or profile.quality_score,
                confidence_after=historical_ocr_conf or profile.quality_score,
                agreement_rate=1.0,
                lexical_corrections_count=0,
                dictionary_entries_found=0,
                chunks_generated=0,
                needs_manual_review=profile.routing_decision == RoutingDecision.FASE1_REVISAO,
                sanity_status="valido_pass_through",
                elapsed_seconds=elapsed
            )
            return profile, None, [], audit

        # ── FASE 1: PIPELINE REFORÇADO ENXUTO ────────────────────────────────
        # 1. Pré-processamento e restauração geométrica / bleed-through
        preproc_img, preproc_ops, preproc_meta = self.preprocessing_worker.process(
            pil_img,
            has_bleed_through=profile.has_bleed_through
        )

        # 2. Segmentação de Layout e ordem de leitura (XY-Cut para dicionários)
        layout_blocks = self.layout_worker.analyze_and_segment(
            preproc_img,
            num_columns=profile.num_columns
        )

        # 3. Reconhecimento OCR por bloco
        accumulated_text_parts = []
        block_confs = []
        block_agreements = []
        engines_used = set()

        for sub_img, bbox, block_type in layout_blocks:
            # Motor 1: Tesseract com vocabulário Tupi
            tess_txt, tess_conf, tess_min, _ = self.ocr_worker.run_tesseract(sub_img)
            # Motor 2: RapidOCR com threads CPU limitadas
            rapid_txt, rapid_conf, rapid_min, _ = self.ocr_worker.run_rapidocr(sub_img)

            # Votação e reconciliação
            voted_txt, voted_conf, agree_rate, winner_eng, prov = self.ocr_worker.vote_and_reconcile(
                tess_txt, tess_conf, rapid_txt, rapid_conf
            )

            if voted_txt.strip():
                accumulated_text_parts.append(voted_txt)
                block_confs.append(voted_conf)
                block_agreements.append(agree_rate)
                engines_used.add(winner_eng)

        full_raw_text = "\n\n".join(accumulated_text_parts)
        mean_ocr_conf = float(sum(block_confs) / max(len(block_confs), 1))
        mean_agree_rate = float(sum(block_agreements) / max(len(block_agreements), 1))

        # 4. Correção Léxica Restrita com Salvaguarda Tupi
        text_before_lex, text_after_lex, corrections = self.lexicon_worker.correct_text(full_raw_text)

        # 5. Grafo de Confiança Composto e Sanidade
        composite_conf, needs_review, sanity_status, conf_details = self.confidence_worker.compute_composite_confidence(
            ocr_confidence=mean_ocr_conf,
            agreement_rate=mean_agree_rate,
            text=text_after_lex
        )

        # 6. Chunking Consciente de Estrutura de Dicionário
        chunks = self.chunk_worker.chunk_text(
            text=text_after_lex,
            filename=filename,
            page_num=page_num
        )

        dict_entries_count = sum(1 for c in chunks if c.headword is not None)

        # 7. Auditoria Completa
        elapsed = time.time() - t0
        audit = self.confidence_worker.build_audit_record(
            filename=filename,
            page_num=page_num,
            quality_score=profile.quality_score,
            routing_decision=profile.routing_decision.value,
            preprocessing_applied=preproc_ops,
            engine_used="+".join(sorted(engines_used)) if engines_used else "none",
            confidence_before=historical_ocr_conf or profile.quality_score,
            confidence_after=composite_conf,
            agreement_rate=mean_agree_rate,
            lexical_corrections_count=len(corrections),
            dictionary_entries_found=dict_entries_count,
            chunks_generated=len(chunks),
            needs_manual_review=needs_review or profile.routing_decision == RoutingDecision.FASE1_REVISAO,
            sanity_status=sanity_status,
            elapsed_seconds=elapsed
        )

        ocr_result = OCRPageResult(
            filename=filename,
            page_num=page_num,
            text_raw=full_raw_text,
            text_cleaned=text_after_lex,
            text_before_lexicon=text_before_lex,
            text_after_lexicon=text_after_lex,
            mean_confidence=composite_conf,
            min_confidence=min(block_confs) if block_confs else 0.0,
            engine_primary="+".join(sorted(engines_used)) if engines_used else "tesseract",
            engine_secondary="rapidocr" if "rapidocr" in engines_used else None,
            agreement_rate=mean_agree_rate,
            corrections_applied=corrections,
            reading_order_blocks=len(layout_blocks),
            layout_type=f"{profile.num_columns}_columns",
            audit_trail=conf_details
        )

        return profile, ocr_result, chunks, audit
