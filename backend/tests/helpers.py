"""Utilidades compartidas por las pruebas con DB."""

from __future__ import annotations

import io
import json
from datetime import datetime, timezone


def fake_jpeg(payload: bytes = b"fake-image-bytes") -> tuple[str, io.BytesIO, str]:
    return ("obs.jpg", io.BytesIO(payload), "image/jpeg")


def jpeg_with_gps() -> bytes:
    """JPEG real (Pillow) con tags EXIF GPS, para probar el saneo del gate #5 (CR-001)."""
    from PIL import Image

    img = Image.new("RGB", (8, 8), (10, 120, 60))
    exif = Image.Exif()
    exif[0x010F] = "TestCam"  # Make (tag NO-GPS; debe sobrevivir al saneo)
    gps = exif.get_ifd(0x8825)
    gps[1] = "N"
    gps[2] = (21.0, 53.0, 7.0)
    gps[3] = "W"
    gps[4] = (102.0, 17.0, 30.0)
    buf = io.BytesIO()
    img.save(buf, format="JPEG", exif=exif)
    return buf.getvalue()


def submit_jpeg_with_gps(client, token: str, *, lat: float = 21.88, lon: float = -102.29) -> str:
    """Sube una observación cuya imagen lleva GPS en EXIF. Devuelve el observation_id."""
    captured_at = datetime.now(timezone.utc)
    payload = {
        "lat": lat,
        "lon": lon,
        "captured_at": captured_at.isoformat(),
        "nivel_g4": "leve",
        "flag_cuscuta": False,
        "flag_danio": False,
        "tamanio": "mediano",
        "contexto": "campo_abierto",
    }
    resp = client.post(
        "/api/v1/observations",
        headers=auth_header(token),
        data={"payload": json.dumps(payload)},
        files={"image": ("obs.jpg", io.BytesIO(jpeg_with_gps()), "image/jpeg")},
    )
    assert resp.status_code == 201, resp.text
    return resp.json()["observation_id"]


def register(client, role: str = "voluntario", institution_id: str | None = None) -> dict:
    """Alta de cuenta para pruebas.

    CR-002: ``POST /auth/register`` ya NO acepta `role` (cierra el hueco del gate #5). Para
    ``voluntario`` se usa el endpoint real; para roles de backend/consorcio (que la API ya no
    concede) se siembra la cuenta directamente en la DB y se emite un token, igual que hace el
    administrador/bootstrap por dentro.
    """
    if role == "voluntario":
        body: dict = {}
        if institution_id:
            body["institution_id"] = institution_id
        resp = client.post("/api/v1/auth/register", json=body)
        assert resp.status_code == 201, resp.text
        return resp.json()
    return _seed_account_with_role(role, institution_id)


def _seed_account_with_role(role: str, institution_id: str | None = None) -> dict:
    """Crea una cuenta con un rol dado en la DB y devuelve {handle, role, token}."""
    import uuid as _uuid

    from backend.app import db as db_module
    from backend.app.models import Account
    from backend.app.security import create_token, generate_handle

    session = db_module.get_sessionmaker()()
    try:
        account = Account(
            handle=generate_handle(),
            auth_provider="social_google",
            provider_subject=f"seed-{_uuid.uuid4().hex}",
            role=role,
            institution_id=_uuid.UUID(institution_id) if institution_id else None,
        )
        session.add(account)
        session.commit()
        session.refresh(account)
        token = create_token(account_id=account.id, handle=account.handle, role=account.role)
        return {"handle": account.handle, "role": account.role, "token": token}
    finally:
        session.close()


def auth_header(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def submit_observation(
    client,
    token: str,
    *,
    lat: float,
    lon: float,
    nivel_g4: str = "leve",
    flag_cuscuta: bool = False,
    flag_danio: bool = False,
    tamanio: str = "mediano",
    contexto: str = "campo_abierto",
    captured_at: datetime | None = None,
):
    captured_at = captured_at or datetime.now(timezone.utc)
    payload = {
        "lat": lat,
        "lon": lon,
        "captured_at": captured_at.isoformat(),
        "nivel_g4": nivel_g4,
        "flag_cuscuta": flag_cuscuta,
        "flag_danio": flag_danio,
        "tamanio": tamanio,
        "contexto": contexto,
    }
    return client.post(
        "/api/v1/observations",
        headers=auth_header(token),
        data={"payload": json.dumps(payload)},
        files={"image": fake_jpeg()},
    )
