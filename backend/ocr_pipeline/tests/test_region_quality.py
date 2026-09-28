"""
Testes unitários para o RegionQualityEngine (Capítulo 28 - Region Quality Engine).
"""
import unittest
from PIL import Image, ImageDraw

from ocr_pipeline.diagnostic_engine.region_quality import (
    RegionQualityEngine,
    PageRegionQualityReport,
    RegionQualityAssessment,
)


class TestRegionQualityEngine(unittest.TestCase):
    def setUp(self):
        self.engine = RegionQualityEngine(min_quality_threshold=0.70, max_acceptable_cer=0.15)
        self.img = Image.new("RGB", (600, 800), color=(255, 255, 255))
        draw = ImageDraw.Draw(self.img)
        # Cabeçalho nítido
        draw.text((50, 30), "VOCABULARIO NA LINGUA BRASILICA", fill=(0, 0, 0))
        # Corpo de texto
        draw.text((50, 150), "oka, s. f. habitação dos índios", fill=(0, 0, 0))

    def test_evaluate_page_regions_and_heatmap(self):
        regions_def = [
            {"region_type": "header", "bbox": [40, 20, 500, 80], "ocr_confidence": 95.0},
            {"region_type": "column_left", "bbox": [40, 100, 280, 700], "ocr_confidence": 90.0},
            {"region_type": "column_right", "bbox": [300, 100, 560, 700], "ocr_confidence": 45.0},  # Baixa confiança
            {"region_type": "illustrations", "bbox": [100, 720, 500, 780]},
        ]

        report, heatmap = self.engine.evaluate_page_regions(self.img, regions_def)
        self.assertIsInstance(report, PageRegionQualityReport)
        self.assertEqual(report.regions_count, 4)
        self.assertIsInstance(heatmap, Image.Image)
        self.assertEqual(heatmap.size, self.img.size)

        # A coluna da direita com 45% de confiança DEVE requerer recuperação iterativa
        recovery_types = [a.region_type for a in report.assessments if a.needs_iterative_recovery]
        self.assertIn("column_right", recovery_types)

        # O cabeçalho com 95% NÃO deve requerer recuperação
        header_asm = next(a for a in report.assessments if a.region_type == "header")
        self.assertFalse(header_asm.needs_iterative_recovery)


if __name__ == "__main__":
    unittest.main()
