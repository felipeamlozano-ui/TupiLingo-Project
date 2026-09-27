"""
Módulo de Rollback Forense, Invariantes e Recuperação Iterativa.
"""

from .rollback_manager import (
    AuditEvent,
    ForensicAuditLogger,
    IterationAttempt,
    IterativeRecoveryEngine,
    RegionRecoveryHistory,
    RollbackManager,
)

__all__ = [
    "AuditEvent",
    "ForensicAuditLogger",
    "IterationAttempt",
    "IterativeRecoveryEngine",
    "RegionRecoveryHistory",
    "RollbackManager",
]
