"""GET /institutions público (Q4): el voluntario lista instituciones aprobadas sin auth."""

from __future__ import annotations

from backend.app.models import Institution


def _seed(db_session):
    db_session.add_all(
        [
            Institution(name="Prepa Aguascalientes", estado="Aguascalientes", status="aprobada"),
            Institution(name="Universidad Bajío", estado="Guanajuato", status="aprobada"),
            Institution(name="Pendiente C", estado="Jalisco", status="solicitada"),
        ]
    )
    db_session.commit()


def test_lists_only_approved_without_auth(client, db_session):
    _seed(db_session)
    r = client.get("/api/v1/institutions")  # sin token: el alta ocurre antes de tener cuenta
    assert r.status_code == 200, r.text
    data = r.json()
    names = {i["name"] for i in data}
    assert {"Prepa Aguascalientes", "Universidad Bajío"} <= names
    assert "Pendiente C" not in names  # las solicitadas (ticket EA3) no se exponen
    assert all(i["status"] == "aprobada" for i in data)


def test_filter_by_estado(client, db_session):
    _seed(db_session)
    r = client.get("/api/v1/institutions", params={"estado": "Guanajuato"})
    assert r.status_code == 200
    assert [i["name"] for i in r.json()] == ["Universidad Bajío"]


def test_empty_when_none_approved(client, db_session):
    db_session.add(Institution(name="Solo Solicitada", estado="X", status="solicitada"))
    db_session.commit()
    r = client.get("/api/v1/institutions")
    assert r.status_code == 200
    assert r.json() == []
