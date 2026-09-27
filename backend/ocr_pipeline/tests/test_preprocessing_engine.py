"""
Testes unitários automatizados para o MultiBranchPreprocessingEngine (30 branches).
"""
import unittest

import numpy as np
from PIL import Image, ImageDraw

from ocr_pipeline.preprocessing_engine import MultiBranchPreprocessingEngine


class TestMultiBranchPreprocessingEngine(unittest.TestCase):
    def setUp(self):
        self.engine = MultiBranchPreprocessingEngine()
        # Imagem sintética cinza com texto e manchas
        self.img = Image.new("RGB", (300, 300), color=(240, 235, 210))
        draw = ImageDraw.Draw(self.img)
        draw.text((30, 40), "Tupinambá Morubixaba", fill=(20, 20, 20))
        draw.rectangle((100, 150, 180, 220), fill=(200, 190, 160)) # mancha suave

    def test_all_30_branches_execute_successfully(self):
        results = self.engine.process_all_branches(self.img)
        self.assertEqual(len(results), 30)

        # Checar que cada branch gerou uma imagem válida com as mesmas dimensões
        for branch_name, branch_img in results.items():
            self.assertEqual(branch_img.size, (300, 300), f"Dimensão incorreta no branch: {branch_name}")
            arr = np.array(branch_img)
            self.assertGreater(arr.size, 0)

    def test_specific_core_branches(self):
        gray = np.array(self.img.convert("L"))
        
        sauvola = self.engine.branch_sauvola(gray)
        self.assertEqual(sauvola.shape, (300, 300))
        self.assertTrue(np.isin(sauvola, [0, 255]).all())

        clahe = self.engine.branch_clahe(gray)
        self.assertEqual(clahe.shape, (300, 300))

        deskew = self.engine.branch_deskew_projection(gray)
        self.assertEqual(deskew.shape, (300, 300))

if __name__ == "__main__":
    unittest.main()
