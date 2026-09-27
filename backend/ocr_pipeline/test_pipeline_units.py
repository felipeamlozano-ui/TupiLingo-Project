"""
Testes unitários automatizados para o pipeline modular de OCR (Fase 0 e Fase 1).
"""
import unittest
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from ocr_pipeline.cache_manager import DeterministicCacheManager
from ocr_pipeline.chunk_worker import ChunkWorker
from ocr_pipeline.layout_worker import LayoutWorker
from ocr_pipeline.lexicon_worker import LexiconWorker
from ocr_pipeline.models import RoutingDecision
from ocr_pipeline.preprocessing_worker import PreprocessingWorker
from ocr_pipeline.quality_worker import QualityWorker


class TestOCRPipeline(unittest.TestCase):
    def setUp(self):
        base_dir = Path(__file__).resolve().parent.parent
        self.tupi_words_path = base_dir / "tupi_user_words.txt"
        self.lexicon_data_path = base_dir / "pedagogico" / "lexicon_data.py"

    def test_quality_worker_metrics_and_calibration(self):
        worker = QualityWorker()
        # Imagem sintética cinza com gradiente
        arr = np.zeros((200, 200), dtype=np.uint8)
        arr[50:150, 50:150] = 255
        metrics = worker.compute_iqa_metrics(arr)
        
        self.assertIn("blur_laplacian", metrics)
        self.assertIn("contrast_rms", metrics)
        self.assertIn("entropy", metrics)
        self.assertIn("skew_angle", metrics)
        
        calib_score = worker.calculate_calibrated_iqa(metrics)
        self.assertGreaterEqual(calib_score, 0.0)
        self.assertLessEqual(calib_score, 100.0)

    def test_routing_table(self):
        worker = QualityWorker()
        self.assertEqual(worker.route_page(99.0), RoutingDecision.OCR_RAPIDO)
        self.assertEqual(worker.route_page(95.0), RoutingDecision.OCR_PADRAO)
        self.assertEqual(worker.route_page(92.0), RoutingDecision.FASE1_REFORCADO)
        self.assertEqual(worker.route_page(87.0), RoutingDecision.FASE1_ATENCAO)
        self.assertEqual(worker.route_page(80.0), RoutingDecision.FASE1_REVISAO)

    def test_sauvola_binarization(self):
        preproc = PreprocessingWorker()
        # Simula imagem com mancha cinza de bleed-through
        gray = np.full((100, 100), 240, dtype=np.uint8)
        gray[20:30, 20:30] = 200 # mancha de bleed-through fraca
        gray[50:80, 50:80] = 30  # texto nítido na frente
        
        binary = preproc.apply_sauvola_binarization(gray, window_size=15, k=0.25)
        # O texto frontal deve virar 0 (preto)
        self.assertEqual(binary[60, 60], 0)
        # O bleed-through deve ser removido para 255 (branco)
        self.assertEqual(binary[25, 25], 255)

    def test_layout_2_columns_separation(self):
        layout = LayoutWorker()
        # Cria imagem com duas colunas nítidas
        img = Image.new("L", (1000, 1200), color=255)
        draw = ImageDraw.Draw(img)
        # Coluna 1
        draw.rectangle((50, 100, 450, 1100), fill=50)
        # Coluna 2
        draw.rectangle((550, 100, 950, 1100), fill=50)
        
        blocks = layout.analyze_and_segment(img, num_columns=2)
        # Deve encontrar pelo menos coluna esquerda e direita
        col_names = [b[2] for b in blocks]
        self.assertIn("column_left", col_names)
        self.assertIn("column_right", col_names)

    def test_lexicon_safeguard_never_corrupts_tupi(self):
        lex = LexiconWorker(
            tupi_words_file=self.tupi_words_path,
            lexicon_data_path=self.lexicon_data_path
        )
        
        # Teste 1: Palavra Tupi autêntica "morubixaba" e "oka" nunca viram português
        text = "morubixaba oka peẽ iandé"
        before, after, corrections = lex.correct_text(text)
        self.assertIn("morubixaba", after.lower())
        self.assertIn("oka", after.lower())
        
        # Teste 2: Typo em palavra Tupi é restaurado para Tupi canônico, NÃO para português
        # E com preservação rigorosa da caixa original (Seção 1.4)
        _, after_lower, corr_lower = lex.correct_text("morubbaba")
        self.assertEqual(after_lower, "morubixaba")
        self.assertEqual(corr_lower[0]["type"], "tupi_restoration")

        _, after_title, _ = lex.correct_text("Morubbaba")
        self.assertEqual(after_title, "Morubixaba")

        _, after_upper, _ = lex.correct_text("MORUBBABA")
        self.assertEqual(after_upper, "MORUBIXABA")

    def test_dictionary_chunking_upper_bound_and_inheritance(self):
        # max_chunk_chars=120 força a subdivisão do verbete de 208 chars
        chunker = ChunkWorker(max_chunk_chars=120)
        
        # Verbete longo excedendo 120 caracteres com múltiplas acepções
        long_entry = (
            "Aba, s. Homem, ser humano, indivíduo indígena.\n"
            "1. Pessoa da aldeia que caça e protege a comunidade.\n"
            "2. Indivíduo adulto em oposição a kunumĩ (menino) e kuñataĩ (menina).\n"
            "Ex: Aba puranga taba pupé oiko oikóba."
        )
        
        chunks = chunker.chunk_text(long_entry, "dicionario_teste.pdf", 1)
        self.assertGreater(len(chunks), 1)
        
        # Cada sub-chunk deve herdar o lema no prefixo
        for c in chunks:
            self.assertIn("[Aba", c.text)
            self.assertTrue(c.is_subdivided)
            self.assertLessEqual(len(c.text), 350) # Respeita limite superior com prefixo herdado

    def test_deterministic_cache(self):
        test_bytes = b"fake_page_image_content_12345"
        h = DeterministicCacheManager.compute_page_hash(test_bytes)
        
        fake_profile = {"test_key": "val", "quality_score": 92.5}
        DeterministicCacheManager.set_cached_profile(h, fake_profile)
        
        retrieved = DeterministicCacheManager.get_cached_profile(h)
        self.assertIsNotNone(retrieved)
        self.assertEqual(retrieved["quality_score"], 92.5)

if __name__ == "__main__":
    unittest.main()
