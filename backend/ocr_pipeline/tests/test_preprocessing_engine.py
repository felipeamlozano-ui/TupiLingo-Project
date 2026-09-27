"""
Testes unitários automatizados para o MultiBranchPreprocessingEngine — Capítulo 4 (40 branches).
"""
import shutil
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from ocr_pipeline.preprocessing_engine import MultiBranchPreprocessingEngine


class TestMultiBranchPreprocessingEngine(unittest.TestCase):
    def setUp(self):
        self.tmp_dir = Path(tempfile.mkdtemp())
        self.engine = MultiBranchPreprocessingEngine(cache_dir=self.tmp_dir)
        # Imagem sintética cinza com texto e manchas
        self.img = Image.new("RGB", (300, 300), color=(240, 235, 210))
        draw = ImageDraw.Draw(self.img)
        draw.text((30, 40), "Tupinambá Morubixaba", fill=(20, 20, 20))
        draw.rectangle((100, 150, 180, 220), fill=(200, 190, 160))  # mancha suave

    def tearDown(self):
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    def test_all_branches_count_and_execution(self):
        # Deve ter pelo menos 40 branches cadastradas
        self.assertGreaterEqual(len(self.engine.branches), 40)
        results = self.engine.process_all_branches(self.img)
        self.assertGreaterEqual(len(results), 40)

        # Checar que cada branch gerou uma imagem válida com as mesmas dimensões
        for branch_name, branch_img in results.items():
            self.assertEqual(branch_img.size, (300, 300), f"Dimensão incorreta no branch: {branch_name}")
            arr = np.array(branch_img)
            self.assertGreater(arr.size, 0)

    def test_spurious_ink_density_metric(self):
        # 1. Imagem limpa com texto puro
        clean_img = np.full((100, 100), 255, dtype=np.uint8)
        clean_img[40:60, 20:80] = 0  # Bloco nítido conectado de texto
        density_clean = self.engine.compute_spurious_ink_density(clean_img)

        # 2. Imagem cheia de speckles/pimenta isolada (ruído espúrio)
        noisy_img = clean_img.copy()
        # Injetar 50 pontinhos de ruído isolado (1x1 ou 2x2)
        np.random.seed(42)
        for _ in range(50):
            ry, rx = np.random.randint(0, 100), np.random.randint(0, 100)
            noisy_img[ry, rx] = 0

        density_noisy = self.engine.compute_spurious_ink_density(noisy_img)
        self.assertGreater(density_noisy, density_clean, "Densidade de tinta espúria deve ser maior na imagem com ruído.")

    def test_selective_persistence_top_3_to_5(self):
        # Executa ranking com spurious ink density
        top_variants, metrics = self.engine.evaluate_and_rank_branches(self.img, top_k=4)
        self.assertEqual(len(top_variants), 4)
        self.assertEqual(len(metrics), 4)

        # Persistir em disco
        saved_paths = self.engine.persist_top_variants("test_page_1", top_variants)
        self.assertEqual(len(saved_paths), 4)
        for p in saved_paths:
            self.assertTrue(p.exists())
            self.assertGreater(p.stat().st_size, 0)

    def test_bm3d_optional_fallback(self):
        gray = np.array(self.img.convert("L"))
        # Não deve levantar exceção mesmo se bm3d não estiver instalado (faz fallback gracioso)
        res = self.engine.branch_bm3d_optional(gray)
        self.assertEqual(res.shape, (300, 300))


if __name__ == "__main__":
    unittest.main()
