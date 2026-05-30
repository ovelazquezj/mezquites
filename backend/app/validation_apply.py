"""Aplicación autoritativa e idempotente del resultado de validación (§6.3, §6.4, gate #9).

Esta es la lógica que el ``result_worker`` ejecuta por cada mensaje de ``RESULTS_STREAM``:

1. **Recompute autoritativo** del veredicto con ``compute_verdict`` (vía
   ``ValidationResult.authoritative_verdict``). NUNCA confía en el campo ``veredicto`` del mensaje
   (gate #9). Si el productor envió un veredicto incoherente, se registra (``is_consistent``).
2. **Idempotencia** vía ``validation_event`` (PK por ``observation_id``): INSERT … ON CONFLICT
   DO NOTHING. Si el evento ya existía, no se reaplica nada (no duplica puntos).
3. Actualiza ``observation.validation_state`` a ``valida`` | ``ruido`` y sella ``model_version`` /
   ``validated_at``.
4. **Otorga puntos diferidos SOLO si válida** (UNIQUE(observation_id,'diferida') refuerza la
   unicidad incluso ante carreras). Refresca la etiqueta L3.

Si el resultado no llega (timeout / validador caído), la observación **permanece 'pendiente'**:
nada en este módulo auto-etiqueta sin un resultado explícito (§6.4).
"""

from __future__ import annotations

import logging
import uuid

from mezquite_contract.models import ValidationResult
from sqlalchemy import text
from sqlalchemy.orm import Session

from .config import get_settings
from .gamification import refresh_identity_label

log = logging.getLogger("mezquite.validation")


class ApplyOutcome:
    def __init__(self, *, applied: bool, verdict: str, points_awarded: int, duplicate: bool):
        self.applied = applied  # True si este mensaje produjo el cambio (no fue duplicado)
        self.verdict = verdict
        self.points_awarded = points_awarded
        self.duplicate = duplicate


def apply_validation_result(db: Session, result: ValidationResult) -> ApplyOutcome:
    """Aplica un resultado de validación de forma autoritativa e idempotente. Hace commit."""
    settings = get_settings()
    obs_id: uuid.UUID = result.observation_id

    # (1) Veredicto AUTORITATIVO recomputado en el backend (gate #9).
    verdict = result.authoritative_verdict
    if not result.is_consistent:
        log.warning(
            "Resultado con veredicto incoherente para %s: mensaje=%s autoritativo=%s",
            obs_id,
            result.veredicto,
            verdict,
        )

    # (2) Idempotencia: intenta insertar el evento; si ya existe, no reaplica (gate #9, §6.4).
    inserted = db.execute(
        text(
            """
            INSERT INTO validation_event
                (observation_id, es_arbol, parasitos, veredicto,
                 score_arbol, score_parasitos, model_version)
            VALUES
                (:oid, :es_arbol, :parasitos, :veredicto,
                 :s_arbol, :s_parasitos, :model_version)
            ON CONFLICT (observation_id) DO NOTHING
            RETURNING observation_id
            """
        ),
        {
            "oid": obs_id,
            "es_arbol": result.es_arbol,
            "parasitos": result.parasitos_presentes,
            "veredicto": verdict,
            "s_arbol": result.scores.arbol,
            "s_parasitos": result.scores.parasitos,
            "model_version": result.model_version,
        },
    ).first()

    if inserted is None:
        # Reentrega de la cola: ya se aplicó. No duplica puntos ni reescribe estado.
        db.rollback()
        return ApplyOutcome(applied=False, verdict=verdict, points_awarded=0, duplicate=True)

    # (3) Etiqueta la observación con el estado autoritativo.
    obs_row = db.execute(
        text(
            """
            UPDATE observation
            SET validation_state = :verdict,
                model_version = :model_version,
                validated_at = now()
            WHERE id = :oid
            RETURNING account_id
            """
        ),
        {"verdict": verdict, "model_version": result.model_version, "oid": obs_id},
    ).first()

    points_awarded = 0
    if obs_row is not None and verdict == "valida":
        account_id = obs_row[0]
        # (4) Puntos diferidos SOLO si válida; UNIQUE(observation_id,'diferida') evita duplicados.
        awarded = db.execute(
            text(
                """
                INSERT INTO points_ledger (account_id, observation_id, kind, points)
                VALUES (:account_id, :oid, 'diferida', :points)
                ON CONFLICT (observation_id, kind) DO NOTHING
                RETURNING points
                """
            ),
            {"account_id": account_id, "oid": obs_id, "points": settings.points_deferred},
        ).first()
        if awarded is not None:
            points_awarded = int(awarded[0])
            refresh_identity_label(db, account_id)

    db.commit()
    return ApplyOutcome(
        applied=True, verdict=verdict, points_awarded=points_awarded, duplicate=False
    )
