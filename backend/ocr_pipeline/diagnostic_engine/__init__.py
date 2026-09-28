"""
Pacote Diagnostic Engine — TupiLingo OCR Forense v3.0
"""
from .forensic_analyzer import ForensicDiagnosticEngine, ForensicDiagnosticReport, PageProfile
from .region_quality import RegionQualityEngine, RegionQualityAssessment, PageRegionQualityReport

__all__ = [
    "ForensicDiagnosticEngine",
    "ForensicDiagnosticReport",
    "PageProfile",
    "RegionQualityEngine",
    "RegionQualityAssessment",
    "PageRegionQualityReport",
]

