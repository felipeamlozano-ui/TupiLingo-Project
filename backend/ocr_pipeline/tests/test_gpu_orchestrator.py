"""
Testes unitários para o GPUResourceOrchestrator (Capítulo 31 - GPU Resource Orchestrator).
"""
import unittest

from ocr_pipeline.core.gpu_orchestrator import (
    GPUResourceOrchestrator,
    GPUTelemetry,
)


class TestGPUResourceOrchestrator(unittest.TestCase):
    def setUp(self):
        self.orchestrator = GPUResourceOrchestrator()

    def test_query_telemetry(self):
        telem = self.orchestrator.query_telemetry()
        self.assertIsInstance(telem, GPUTelemetry)
        self.assertGreater(telem.vram_total_mb, 0.0)
        self.assertGreaterEqual(telem.vram_free_mb, 0.0)
        self.assertGreater(telem.temperature_celsius, 0.0)

    def test_schedule_tile_size(self):
        tile_size = self.orchestrator.schedule_tile_size(2000, 3000)
        self.assertIn(tile_size, [256, 512, 1024])

    def test_oom_recovery_flow(self):
        def failing_task():
            raise RuntimeError("CUDA out of memory. Tried to allocate 4.00 GiB")

        def fallback_task():
            return "fallback_success"

        res = self.orchestrator.execute_with_oom_recovery(
            failing_task,
            fallback_cpu_func=fallback_task,
        )
        self.assertEqual(res, "fallback_success")


if __name__ == "__main__":
    unittest.main()
