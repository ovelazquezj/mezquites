"""CR-034: ``offset`` en las tres listas de observaciones de la consola.

El ``limit`` solo, sin ``offset``, era un tope silencioso: el cliente pedía UNA página y el resto
del dataset quedaba invisible aunque existiera en la base (mismo defecto que corrigió CR-033 en
``/review/queue``). Estas pruebas verifican que ``/public/observations``,
``/restricted/observations`` y ``/admin/analytics/observations`` se pueden recorrer completos por
páginas: páginas disjuntas, en orden ``captured_at DESC``, y cuya unión es el dataset entero.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from .helpers import auth_header, confirm_observation, register, submit_observation

_BASE = datetime(2026, 7, 1, 12, 0, tzinfo=timezone.utc)


def _seed(client, *, n: int, confirm: bool) -> list[str]:
    """Siembra ``n`` observaciones con ``captured_at`` escalonado (orden determinista)."""
    vol = register(client)
    ids: list[str] = []
    for i in range(n):
        resp = submit_observation(
            client,
            vol["token"],
            lat=21.88 + i * 0.001,
            lon=-102.29,
            captured_at=_BASE + timedelta(minutes=i),
        )
        assert resp.status_code == 201, resp.text
        oid = resp.json()["observation_id"]
        if confirm:
            confirm_observation(oid)
        ids.append(oid)
    return ids


def test_public_observations_offset_recorre_todo(client, db_session):
    """/public/observations: 3 páginas de 2 cubren las 5 confirmadas, sin traslapes."""
    _seed(client, n=5, confirm=True)

    paginas = []
    for offset in (0, 2, 4):
        resp = client.get(f"/api/v1/public/observations?limit=2&offset={offset}")
        assert resp.status_code == 200, resp.text
        paginas.append(resp.json())

    assert [len(p) for p in paginas] == [2, 2, 1]
    todas = [r["captured_at"] for p in paginas for r in p]
    # Sin traslapes entre páginas y en el mismo orden (captured_at DESC) que la consulta completa.
    assert len(set(todas)) == 5
    completa = client.get("/api/v1/public/observations").json()
    assert [r["captured_at"] for r in completa] == todas


def test_restricted_observations_offset_recorre_todo(client, db_session):
    """/restricted/observations pagina TODOS los estados de revisión (vista de trabajo)."""
    _seed(client, n=4, confirm=False)  # quedan `aceptada`: la vista restringida las incluye
    admin = register(client, role="administrador")

    p1 = client.get(
        "/api/v1/restricted/observations?limit=3&offset=0",
        headers=auth_header(admin["token"]),
    )
    p2 = client.get(
        "/api/v1/restricted/observations?limit=3&offset=3",
        headers=auth_header(admin["token"]),
    )
    assert p1.status_code == 200 and p2.status_code == 200
    assert len(p1.json()) == 3
    assert len(p2.json()) == 1
    fechas = [r["captured_at"] for r in p1.json() + p2.json()]
    assert len(set(fechas)) == 4


def test_analytics_observations_offset_recorre_todo(client, db_session):
    """/admin/analytics/observations: la unión de páginas por id es el dataset completo."""
    ids = _seed(client, n=5, confirm=False)
    analista = register(client, role="analista")

    juntadas: list[str] = []
    for offset in (0, 2, 4):
        resp = client.get(
            f"/api/v1/admin/analytics/observations?limit=2&offset={offset}",
            headers=auth_header(analista["token"]),
        )
        assert resp.status_code == 200, resp.text
        juntadas.extend(r["observation_id"] for r in resp.json())

    assert sorted(juntadas) == sorted(ids)


def test_offset_negativo_es_422(client, db_session):
    """``offset`` negativo se rechaza (ge=0), no se interpreta en silencio."""
    resp = client.get("/api/v1/public/observations?offset=-1")
    assert resp.status_code == 422
