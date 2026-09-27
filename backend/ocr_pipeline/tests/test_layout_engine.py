"""
Testes unitários automatizados para o ForensicLayoutEngine e ReadingOrderGraph — Capítulo 5.
"""
import unittest

from PIL import Image, ImageDraw

from ocr_pipeline.layout_engine import ForensicLayoutEngine, LayoutRegion, ReadingOrderGraph
from ocr_pipeline.core.provenance import BoundingBox


class TestForensicLayoutEngine(unittest.TestCase):
    def setUp(self):
        self.engine = ForensicLayoutEngine()

    def test_reading_order_graph_topological_sort(self):
        graph = ReadingOrderGraph()
        r_head = LayoutRegion(region_id="head", label="header", confidence=0.9, bbox=BoundingBox(x1=0, y1=0, x2=800, y2=50))
        r_left = LayoutRegion(region_id="col1", label="column_left", confidence=0.9, bbox=BoundingBox(x1=0, y1=60, x2=390, y2=900))
        r_right = LayoutRegion(region_id="col2", label="column_right", confidence=0.9, bbox=BoundingBox(x1=410, y1=60, x2=800, y2=900))
        r_foot = LayoutRegion(region_id="foot", label="footer", confidence=0.9, bbox=BoundingBox(x1=0, y1=950, x2=800, y2=1000))

        for r in [r_head, r_right, r_left, r_foot]:  # Inserção fora de ordem
            graph.add_region(r)

        graph.add_edge("head", "col1")
        graph.add_edge("head", "col2")
        graph.add_edge("col1", "col2")
        graph.add_edge("col1", "foot")
        graph.add_edge("col2", "foot")

        sorted_regions = graph.topological_sort()
        ids = [r.region_id for r in sorted_regions]
        # Ordem estrita esperada: head -> col1 -> col2 -> foot
        self.assertEqual(ids, ["head", "col1", "col2", "foot"])
        self.assertEqual([r.reading_order_index for r in sorted_regions], [1, 2, 3, 4])

    def test_two_columns_layout_with_reading_order(self):
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

        # Checar sequência de leitura garantida pelo grafo
        label_order = [r.label for r in regions]
        self.assertEqual(label_order[0], "header")
        self.assertEqual(label_order[1], "column_left")
        self.assertEqual(label_order[2], "column_right")
        self.assertEqual(label_order[3], "footer")

        # Validar renderização de anotação
        annotated = self.engine.render_annotated_image(img, regions)
        self.assertEqual(annotated.size, (1000, 1200))


if __name__ == "__main__":
    unittest.main()
