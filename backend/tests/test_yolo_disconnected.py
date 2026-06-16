"""YOLO desconectado (CR-001): el submit ya no encola y los workers quedan inactivos.

Antes (Inc 2) el submit publicaba un ValidationJob y un ``result_worker`` aplicaba el veredicto
automático (``valida``/``ruido``). El CR-001 retira esa cadena: aceptación por defecto + revisión
humana. Estas pruebas blindan que la frontera §6 quedó **inactiva** (gate #10 superado), sin borrar
el código (sigue importable para reactivar a futuro).
"""

from __future__ import annotations

import inspect

from mezquite_contract.channels import JOBS_STREAM, VALIDATOR_GROUP

from backend.app.routers import observations as obs_router
from .helpers import register, submit_observation


def test_submit_does_not_import_or_call_enqueue():
    """El router de observaciones ya NO usa enqueue_validation_job (frontera §6 inactiva)."""
    src = inspect.getsource(obs_router)
    assert "enqueue_validation_job" not in src
    assert "JOBS_STREAM" not in src


def test_submit_leaves_jobs_stream_empty(client, db_session):
    """AC7: tras varios submits, JOBS_STREAM sigue vacío (no se encola nada)."""
    reg = register(client)
    for _ in range(3):
        submit_observation(client, reg["token"], lat=21.88, lon=-102.29)

    broker = client.broker
    broker.ensure_group(JOBS_STREAM, VALIDATOR_GROUP)
    jobs = broker.consume(JOBS_STREAM, VALIDATOR_GROUP, "test-validator", count=50)
    assert jobs == []


def test_validation_apply_still_importable_but_unused():
    """El código YOLO se conserva (importable) aunque ya no se ejecute en el piloto."""
    from backend.app import validation_apply  # noqa: F401
    from backend import result_worker  # noqa: F401

    assert hasattr(validation_apply, "apply_validation_result")
    assert hasattr(result_worker, "process_once")
