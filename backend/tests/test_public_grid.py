"""Mapa de calor público agregado por celda (CR-009, §4.1; gate #5).

``GET /public/grid``:
- agrega las observaciones **no-rechazadas** por celda de obfuscación (CR-009: 300 m);
- devuelve por celda: lat/lon (centro obfuscado), n, n_paxtle, n_cuscuta, g4_indice, snapshot;
- NUNCA expone coords más finas que la celda ni listas de árboles individuales (gate #5).
"""

from __future__ import annotations

from sqlalchemy import text

from backend.app.geo import obfuscate_to_grid
from .helpers import auth_header, register, submit_observation

# Aguascalientes, MX.
LAT, LON = 21.8853, -102.2916


def test_grid_aggregates_neighbors_into_one_cell(client, db_session):
    """Dos observaciones a ~5 m del centro de una celda se agregan en UNA celda (gate #5)."""
    reg = register(client)
    # Ancla en el centro de la celda para evitar ambigüedad de frontera.
    center = obfuscate_to_grid(LAT, LON)
    submit_observation(
        client, reg["token"], lat=center[0], lon=center[1], nivel_g4="severo", flag_danio=True
    )
    submit_observation(
        client,
        reg["token"],
        lat=center[0] + 0.00004,  # ~5 m
        lon=center[1] + 0.00004,
        nivel_g4="severo",
        flag_cuscuta=True,
    )

    grid = client.get("/api/v1/public/grid").json()
    assert len(grid) == 1, grid
    cell = grid[0]
    assert cell["n"] == 2
    assert cell["n_paxtle"] == 1  # solo una con flag_danio
    assert cell["n_cuscuta"] == 1  # solo una con flag_cuscuta
    # severo=3 en ambas ⇒ promedio 3.0
    assert cell["g4_indice"] == 3.0
    # El centro de celda obfuscado, NO la coord exacta.
    assert (cell["lat"], cell["lon"]) == center
    assert "snapshot_quarter" in cell


def test_grid_separates_far_points_into_distinct_cells(client, db_session):
    """Puntos a > 300 m caen en celdas distintas; cada una con su propio conteo."""
    reg = register(client)
    submit_observation(client, reg["token"], lat=LAT, lon=LON, nivel_g4="sano")
    # ~610 m al norte ⇒ otra celda.
    submit_observation(client, reg["token"], lat=LAT + 0.0055, lon=LON, nivel_g4="moderado")

    grid = client.get("/api/v1/public/grid").json()
    assert len(grid) == 2, grid
    assert {c["n"] for c in grid} == {1}


def test_grid_excludes_rejected_observations(client, db_session):
    """Solo no-rechazadas entran al mapa de calor (igual que /public/observations, CR-001)."""
    reg = register(client)
    submit_observation(client, reg["token"], lat=LAT, lon=LON, nivel_g4="leve")
    submit_observation(client, reg["token"], lat=LAT + 0.0055, lon=LON, nivel_g4="severo")
    # Rechaza la segunda observación (veredicto humano).
    db_session.execute(
        text(
            "UPDATE observation SET estado_revision='rechazada' "
            "WHERE nivel_g4='severo'"
        )
    )
    db_session.commit()

    grid = client.get("/api/v1/public/grid").json()
    assert len(grid) == 1, grid
    assert grid[0]["n"] == 1


def test_grid_never_exposes_finer_than_cell(client, db_session):
    """Gate #5: la respuesta agregada nunca devuelve la coord exacta capturada."""
    reg = register(client)
    exact_lat, exact_lon = 21.885311, -102.291622
    submit_observation(client, reg["token"], lat=exact_lat, lon=exact_lon)

    grid = client.get("/api/v1/public/grid").json()
    assert len(grid) == 1
    cell = grid[0]
    # La celda nunca coincide con la coord exacta; es el centro de celda obfuscado.
    assert (cell["lat"], cell["lon"]) != (exact_lat, exact_lon)
    assert (cell["lat"], cell["lon"]) == obfuscate_to_grid(exact_lat, exact_lon)
    # No expone listas de árboles ni ids individuales.
    assert set(cell.keys()) == {
        "lat",
        "lon",
        "n",
        "n_paxtle",
        "n_cuscuta",
        "g4_indice",
        "snapshot_quarter",
    }


def test_grid_g4_index_is_average_0_to_3(client, db_session):
    """g4_indice = promedio del nivel G4 mapeado 0..3 (sano=0..severo=3), autodeclarado (gate #8)."""
    reg = register(client)
    center = obfuscate_to_grid(LAT, LON)
    # sano=0 y severo=3 en la misma celda ⇒ promedio 1.5
    submit_observation(client, reg["token"], lat=center[0], lon=center[1], nivel_g4="sano")
    submit_observation(
        client, reg["token"], lat=center[0] + 0.00004, lon=center[1] + 0.00004, nivel_g4="severo"
    )

    grid = client.get("/api/v1/public/grid").json()
    assert len(grid) == 1
    assert grid[0]["g4_indice"] == 1.5


def test_grid_filter_by_estado(client, db_session):
    """Acepta `estado` como /public/observations."""
    reg = register(client)
    submit_observation(client, reg["token"], lat=LAT, lon=LON)
    db_session.execute(text("UPDATE observation SET estado='Aguascalientes'"))
    db_session.commit()

    ags = client.get("/api/v1/public/grid?estado=Aguascalientes").json()
    other = client.get("/api/v1/public/grid?estado=Jalisco").json()
    assert len(ags) == 1
    assert other == []
