"""
Testes unitários para o ForensicLayoutEngine.
"""
import unittest

from PIL import Image, ImageDraw

from ocr_pipeline.layout_engine import ForensicLayoutEngine


class TestForensicLayoutEngine(unittest.TestCase):
    def setUp(self):
        self.engine = ForensicLayoutEngine()

    def test_two_columns_layout(self):
        # Página sintética de 1000x1200 com duas colunas nítidas
        img = Image.new("L", (1000, 1200), color=255)
        draw = ImageDraw.Draw(img)
        # Cabeçalho
        draw.text((100, 30), "DICIONARIO TUPI HISTORICO", fill=0)
        # Coluna 1
        draw.rectangle((50, 120, 450, 1100), fill=50)
        # Coluna 2
        draw.rectangle((550, 120, 950, 1100), fill=50)
        # Rodapé
        draw.text((500, 1150), "- 42 -", fill=0)

        regions = self.engine.analyze_layout(img)
        labels = [r.label for r in regions]
        self.assertIn("header", labels)
        self.assertIn("column_left", labels)
        self.assertIn("column_right", labels)
        self.assertIn("footer", labels)

        # Validar renderização de anotação
        annotated = self.engine.render_annotated_image(img, regions)
        self.assertEqual(annotated.size, (1000, 1200))

if __name__ == "__main__":
    unittest.main()
