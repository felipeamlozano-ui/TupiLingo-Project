"""
Testes unitários para o Motor de Rollback e Recuperação Iterativa (Etapas 10 e 11).
"""

import pytest

from ocr_pipeline.core.provenance import BoundingBox
from ocr_pipeline.rollback_engine.rollback_manager import (
    IterativeRecoveryEngine,
    RollbackManager,
)


@pytest.fixture
def temp_audit_log(tmp_path):
    return tmp_path / "test_audit.jsonl"


@pytest.fixture
def rollback_manager(temp_audit_log):
    return RollbackManager(audit_log_path=temp_audit_log)


def test_rollback_on_confidence_degradation(rollback_manager):
    # Se a confiança proposta for menor que a original, deve fazer rollback
    token, final_conf, rolled_back = rollback_manager.evaluate_and_enforce(
        original_token="tuba",
        proposed_token="tubo",
        conf_before=0.88,
        conf_after=0.72,
        page_num=1,
        engine="lexical_worker",
    )
    assert rolled_back is True
    assert token == "tuba"
    assert final_conf == 0.88
    assert rollback_manager.total_rollbacks == 1


def test_rollback_on_number_corruption(rollback_manager):
    # Números nunca podem ser corrompidos
    token, _final_conf, rolled_back = rollback_manager.evaluate_and_enforce(
        original_token="1554",
        proposed_token="IS54",
        conf_before=0.92,
        conf_after=0.95,
        page_num=1,
        engine="fuzzy_matcher",
    )
    assert rolled_back is True
    assert token == "1554"
    assert rollback_manager.total_rollbacks == 1


def test_iterative_recovery_engine(rollback_manager):
    recovery = IterativeRecoveryEngine(rollback_manager, max_iterations=5)

    # Simular função de processamento que melhora a confiança na 3ª iteração
    def mock_processor(filter_name, engine_name, scale):
        if filter_name == "retinex":
            return "palavra_recuperada", 0.94
        return "ruido", 0.70

    bbox = BoundingBox(x1=10, y1=10, x2=100, y2=40, page_num=1)
    history = recovery.recover_region(
        region_id="reg_01",
        bbox=bbox,
        initial_text="ruido_inicial",
        initial_conf=0.65,
        region_processor_fn=mock_processor,
    )

    assert history.successful is True
    assert history.final_confidence == 0.94
    assert len(history.iterations) >= 3
    assert history.chosen_iteration == 3
