"""Siembra de demo del mapa de calor público (CR-009, §4.1) — idempotente, por CLI.

Inserta ~10 observaciones alrededor de **Aguascalientes** repartidas en **varias celdas de 300 m**
con **nivel G4 variado** (sano…severo) y mezcla de **paxtle (flag_danio)/cúscuta (flag_cuscuta)**,
para que ``GET /public/grid`` produzca un mapa de calor legible.

Uso:
    python -m backend.app.seed_demo

Idempotente: las filas se siembran bajo una cuenta con ``handle`` fijo (``SEED_HANDLE``). Si esa
cuenta ya tiene observaciones de siembra, no se duplica nada (no inserta de nuevo).

Notas de gates:
- Gate #8: ``nivel_g4`` y los flags son AUTODECLARADOS (datos sintéticos de demo), nunca validados.
- Binning: este script **inserta** las coords exactas (como cualquier submit real); el agrupamiento
  a celda (binning) lo aplica el mapa de calor (``/public/grid``). ``/public/observations`` devuelve
  la ubicación exacta.
- Gate #6: no requiere imágenes reales ni nube; usa una **clave de storage placeholder** en
  ``image_ref`` (la columna exige NOT NULL, pero no se sube binario).

Importante: este módulo es de **demo/seed**, no se ejecuta en producción.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

from .db import get_sessionmaker
from .geo import assign_tree, compute_observation_seq, derive_estado_municipio
from .models import Account, Observation, PointsLedger

# Cuenta sembradora fija: el handle es el ancla de idempotencia (sin PII; provider_subject opaco).
SEED_HANDLE = "seed-demo-mapa-calor"
SEED_PROVIDER_SUBJECT = "seed-demo-mapa-calor-subject"
SEED_IMAGE_REF = "seed-demo/placeholder.jpg"  # clave placeholder (gate #6; no se sube binario)

# Centro aproximado de Aguascalientes.
CENTRO_LAT, CENTRO_LON = 21.8853, -102.2916

# Observaciones de demo: (dlat, dlon, nivel_g4, flag_danio[paxtle], flag_cuscuta).
# Los offsets (~0.003° ≈ 300 m) reparten los puntos en varias celdas de 300 m; algunos pares caen
# en la MISMA celda (offset pequeño) para que el conteo por celda sea > 1 y el mapa sea legible.
SEED_OBSERVACIONES: list[tuple[float, float, str, bool, bool]] = [
    # Celda A (centro): dos puntos muy cercanos (~50 m) ⇒ misma celda, severidad alta.
    (0.0000, 0.0000, "severo", True, True),
    (0.0004, 0.0004, "severo", True, False),
    # Celda B (al norte): paxtle moderado.
    (0.0030, 0.0000, "moderado", True, False),
    (0.0034, 0.0003, "moderado", False, True),
    # Celda C (al este): cúscuta leve.
    (0.0000, 0.0033, "leve", False, True),
    # Celda D (al noreste): sano (sin parásitos).
    (0.0033, 0.0033, "sano", False, False),
    # Celda E (al sur): mezcla paxtle+cúscuta severo.
    (-0.0033, 0.0000, "severo", True, True),
    # Celda F (al oeste): leve con paxtle.
    (0.0000, -0.0033, "leve", True, False),
    # Celda G (al suroeste): moderado con cúscuta.
    (-0.0033, -0.0033, "moderado", False, True),
    # Celda H (al sureste): sano.
    (-0.0033, 0.0033, "sano", False, False),
]


def _ensure_seed_account(db: Session) -> Account:
    """Cuenta sembradora con handle fijo (idempotente). Sin PII (provider_subject opaco)."""
    account = db.query(Account).filter(Account.handle == SEED_HANDLE).one_or_none()
    if account is not None:
        return account
    account = Account(
        handle=SEED_HANDLE,
        auth_provider="social_google",
        provider_subject=SEED_PROVIDER_SUBJECT,
        role="voluntario",
    )
    db.add(account)
    db.commit()
    db.refresh(account)
    return account


def seed_demo(db: Session) -> tuple[int, bool]:
    """Siembra las observaciones de demo. Devuelve ``(insertadas, sembrada_ahora)``.

    Idempotente: si la cuenta sembradora ya tiene observaciones, no inserta nada (devuelve 0 +
    ``False``). El centro de demo es Aguascalientes.
    """
    account = _ensure_seed_account(db)

    ya_sembrado = (
        db.query(Observation).filter(Observation.account_id == account.id).first() is not None
    )
    if ya_sembrado:
        return 0, False

    base_time = datetime.now(timezone.utc)
    insertadas = 0
    for i, (dlat, dlon, nivel_g4, flag_danio, flag_cuscuta) in enumerate(SEED_OBSERVACIONES):
        lat = CENTRO_LAT + dlat
        lon = CENTRO_LON + dlon
        # captured_at escalonado para una serie temporal plausible (no afecta el mapa de calor).
        captured_at = base_time - timedelta(days=i)

        estado, municipio = derive_estado_municipio(db, lat=lat, lon=lon)
        tree_id = assign_tree(db, lat=lat, lon=lon, estado=estado, municipio=municipio)
        seq = compute_observation_seq(db, tree_id, captured_at)

        obs = Observation(
            account_id=account.id,
            handle=account.handle,
            image_ref=SEED_IMAGE_REF,
            geom=f"SRID=4326;POINT({lon} {lat})",
            captured_at=captured_at,
            nivel_g4=nivel_g4,
            flag_cuscuta=flag_cuscuta,
            flag_danio=flag_danio,
            tamanio="mediano",
            contexto="campo_abierto",
            tree_id=tree_id,
            observation_seq=seq,
            estado=estado,
            municipio=municipio,
            # CR-026: la siembra existe para que el mapa público tenga algo que mostrar, y el mapa
            # solo publica confirmadas. Se siembran ya confirmadas, como si un evaluador las hubiera
            # revisado; el flujo real sigue naciendo en 'aceptada' (ver routers/observations.py).
            estado_revision="confirmada",
        )
        db.add(obs)
        db.flush()
        # Recompensa base+diferida al subir (paridad con el flujo real, CR-001).
        db.add(PointsLedger(account_id=account.id, observation_id=obs.id, kind="base", points=5))
        db.add(
            PointsLedger(account_id=account.id, observation_id=obs.id, kind="diferida", points=10)
        )
        insertadas += 1

    db.commit()
    return insertadas, True


def main(argv: list[str] | None = None) -> int:  # pragma: no cover - envoltorio CLI
    SessionLocal = get_sessionmaker()
    db = SessionLocal()
    try:
        insertadas, sembrada = seed_demo(db)
    finally:
        db.close()

    if sembrada:
        print(f"siembra de demo completada: {insertadas} observaciones (handle={SEED_HANDLE})")
    else:
        print(f"siembra de demo ya existía: sin cambios (handle={SEED_HANDLE})")
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
