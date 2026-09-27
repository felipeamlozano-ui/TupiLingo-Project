"""
Escalonador de Páginas e Tiles com Controle de Concorrência e Memória — TupiLingo OCR Forense v3.0
Gerencia filas de processamento sem sobrecarregar a memória do Ryzen 5 5500U.
"""
import gc
import time
from collections.abc import Generator

from PIL import Image

from .metrics import ForensicMetricsCollector


class MemoryAwareScheduler:
    def __init__(self, max_memory_mb: int = 1500):
        self.max_memory_mb = max_memory_mb

    def check_memory_headroom(self) -> bool:
        """Verifica se há memória livre suficiente antes de iniciar a próxima tarefa."""
        telemetry = ForensicMetricsCollector.get_snapshot()
        if telemetry.process_rss_mb > self.max_memory_mb:
            gc.collect()
            time.sleep(0.5)
            telemetry = ForensicMetricsCollector.get_snapshot()
            if telemetry.process_rss_mb > self.max_memory_mb:
                return False
        return True

    @staticmethod
    def slice_tiles(
        pil_img: Image.Image,
        tile_size: int = 256,
        overlap: int = 32
    ) -> Generator[tuple[Image.Image, tuple[int, int, int, int]], None, None]:
        """Divide uma imagem em tiles retangulares com sobreposição para processamento local."""
        w, h = pil_img.size
        step = max(1, tile_size - overlap)

        for y in range(0, h, step):
            for x in range(0, w, step):
                x2 = min(w, x + tile_size)
                y2 = min(h, y + tile_size)
                tile_crop = pil_img.crop((x, y, x2, y2))
                yield tile_crop, (x, y, x2, y2)
