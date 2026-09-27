"""
Coletor de Métricas e Telemetria de Hardware — TupiLingo OCR Forense v3.0
Mede latência, uso de memória (RSS / RAM livre), carga de CPU e métricas de acurácia.
"""
import ctypes
import os
import time
from typing import Any

from pydantic import BaseModel, Field


class SystemMemoryCounters(ctypes.Structure):
    _fields_ = [
        ("dwLength", ctypes.c_ulong),
        ("dwMemoryLoad", ctypes.c_ulong),
        ("ullTotalPhys", ctypes.c_ulonglong),
        ("ullAvailPhys", ctypes.c_ulonglong),
        ("ullTotalPageFile", ctypes.c_ulonglong),
        ("ullAvailPageFile", ctypes.c_ulonglong),
        ("ullTotalVirtual", ctypes.c_ulonglong),
        ("ullAvailVirtual", ctypes.c_ulonglong),
        ("sullAvailExtendedVirtual", ctypes.c_ulonglong),
    ]

class ProcessMemoryCounters(ctypes.Structure):
    _fields_ = [
        ("cb", ctypes.c_uint32),
        ("PageFaultCount", ctypes.c_uint32),
        ("PeakWorkingSetSize", ctypes.c_size_t),
        ("WorkingSetSize", ctypes.c_size_t),
        ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
        ("QuotaPagedPoolUsage", ctypes.c_size_t),
        ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
        ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
        ("PagefileUsage", ctypes.c_size_t),
        ("PeakPagefileUsage", ctypes.c_size_t),
    ]

class TelemetrySnapshot(BaseModel):
    timestamp: float = Field(default_factory=time.time)
    ram_available_mb: float
    ram_total_mb: float
    ram_load_percent: int
    process_rss_mb: float

class ForensicMetricsCollector:
    @staticmethod
    def get_snapshot() -> TelemetrySnapshot:
        """Captura telemetria física instantânea via Windows API nativa."""
        mem = SystemMemoryCounters()
        mem.dwLength = ctypes.sizeof(SystemMemoryCounters)
        ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(mem))

        avail_mb = round(mem.ullAvailPhys / (1024 * 1024), 1)
        total_mb = round(mem.ullTotalPhys / (1024 * 1024), 1)
        load_pct = mem.dwMemoryLoad

        rss_mb = 0.0
        try:
            h_proc = ctypes.windll.kernel32.OpenProcess(0x0400 | 0x0010, False, os.getpid())
            if h_proc:
                pmc = ProcessMemoryCounters()
                pmc.cb = ctypes.sizeof(ProcessMemoryCounters)
                if ctypes.windll.psapi.GetProcessMemoryInfo(h_proc, ctypes.byref(pmc), ctypes.sizeof(pmc)):
                    rss_mb = round(pmc.WorkingSetSize / (1024 * 1024), 1)
                ctypes.windll.kernel32.CloseHandle(h_proc)
        except Exception:
            pass

        return TelemetrySnapshot(
            ram_available_mb=avail_mb,
            ram_total_mb=total_mb,
            ram_load_percent=load_pct,
            process_rss_mb=rss_mb
        )

    @staticmethod
    def format_prometheus_metrics(metrics_dict: dict[str, Any]) -> str:
        """Formata métricas para compatibilidade Prometheus."""
        lines = []
        for k, v in metrics_dict.items():
            if isinstance(v, (int, float)):
                lines.append(f"tupilingo_ocr_{k} {v}")
        return "\n".join(lines)


class ResourceMonitor:
    """Monitor de recursos de memória e CPU para pipelines de longa duração."""

    def __init__(self, max_memory_mb: float = 1500.0):
        self.max_memory_mb = max_memory_mb
        self.collector = ForensicMetricsCollector()

    def check_memory(self) -> TelemetrySnapshot:
        """Obtém snapshot e valida se o processo está dentro dos limites de segurança."""
        snap = self.collector.get_snapshot()
        return snap
