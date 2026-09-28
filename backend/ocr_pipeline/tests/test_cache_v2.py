"""
Testes unitários para o Cache Inteligente v2 (Capítulo 30).
"""
import shutil
import tempfile
import unittest
from pathlib import Path

from ocr_pipeline.cache_manager import DistributedCacheManager


class TestCacheInteligenteV2(unittest.TestCase):
    def setUp(self):
        self.tmp_dir = Path(tempfile.mkdtemp())
        self.cache = DistributedCacheManager(cache_dir=self.tmp_dir)

    def tearDown(self):
        self.cache.close()
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    def test_multi_layer_caching(self):
        # 1. Cache de Layout
        layout_data = [{"label": "header", "bbox": [0, 0, 100, 50]}]
        h_layout = self.cache.compute_transform_hash(b"fake_img", "layout")
        self.cache.set_cached_layout(h_layout, layout_data)
        ret_layout = self.cache.get_cached_layout(h_layout)
        self.assertEqual(ret_layout, layout_data)

        # 2. Cache de Super Resolução
        sr_data = {"scale": 2, "model": "real_esrgan", "gain": 12.5}
        h_sr = self.cache.compute_transform_hash(b"fake_crop", "super_res")
        self.cache.set_cached_super_res(h_sr, sr_data)
        self.assertEqual(self.cache.get_cached_super_res(h_sr), sr_data)

        # 3. Cache de Filtro
        f_data = {"filter": "clahe", "clip_limit": 2.5}
        self.cache.set_cached_filter("img_123", "clahe", f_data)
        self.assertEqual(self.cache.get_cached_filter("img_123", "clahe"), f_data)

        # 4. Cache de Token
        tok_data = {"token": "oka", "confidence": 98.2}
        h_tok = self.cache.compute_sha256("oka_context_1")
        self.cache.set_cached_token(h_tok, tok_data)
        self.assertEqual(self.cache.get_cached_token(h_tok), tok_data)


if __name__ == "__main__":
    unittest.main()
