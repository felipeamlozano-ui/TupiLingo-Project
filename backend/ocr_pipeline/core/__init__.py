"""
Pacote Core — TupiLingo OCR Forense v3.0
"""

from .checkpoint_manager import CheckpointManager
from .config import GLOBAL_CONFIG, ForensePipelineConfig
from .metrics import ForensicMetricsCollector, ResourceMonitor, TelemetrySnapshot
from .provenance import BoundingBox, PageAuditTrail, RegionProvenance, TokenProvenance
from .scheduler import MemoryAwareScheduler
from .gpu_orchestrator import GPUResourceOrchestrator, GPUTelemetry
from .dataset_versioning import DatasetVersionManager, PDFDatasetManifest, DatasetVersionSnapshot
from .quality_certification import QualityCertifier, QualityTier, CertificationResult


def __getattr__(name: str):
    if name in ("ForensicPipelineOrchestrator", "PageProcessingSummary"):
        from .orchestrator import ForensicPipelineOrchestrator, PageProcessingSummary

        return locals()[name]
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")


__all__ = [
    "GLOBAL_CONFIG",
    "BoundingBox",
    "CheckpointManager",
    "ForensePipelineConfig",
    "ForensicMetricsCollector",
    "ForensicPipelineOrchestrator",
    "MemoryAwareScheduler",
    "PageAuditTrail",
    "PageProcessingSummary",
    "RegionProvenance",
    "ResourceMonitor",
    "TelemetrySnapshot",
    "TokenProvenance",
    "GPUResourceOrchestrator",
    "GPUTelemetry",
    "DatasetVersionManager",
    "PDFDatasetManifest",
    "DatasetVersionSnapshot",
    "QualityCertifier",
    "QualityTier",
    "CertificationResult",
]

