"""Mapa de calor público agregado por celda (CR-009, §4.1).

``GET /public/grid``:
- agrupa (*binning*) las observaciones **confirmadas** en celdas métricas (CR-009: 300 m; criterio
  público endurecido a ``confirmada`` por CR-026);
- devuelve por celda: lat/lon (centro de la celda del heatmap), n, n_paxtle, n_cuscuta, g4_indice,
  snapshot;
- el heatmap devuelve conteos por celda, no puntos individuales (el binning es agregación de
  densidad/severidad).
"""

from __future__ import annotations

from sqlalchemy import text

from backend.app.geo import obfuscate_to_grid
from .helpers import (
    auth_header,
    register,
    submit_confirmed_observation,
    submit_observation,
)

# Aguascalientes, MX.
LAT, LON = 21.8853, -102.2916


def test_grid_aggregates_neighbors_into_one_cell(client, db_session):
    """Dos observaciones a ~5 m del centro de una celda se agrupan (binning) en UNA celda."""
    reg = register(client)
    # Ancla en el centro de la celda para evitar ambigüedad de frontera.
    center = obfuscate_to_grid(LAT, LON)
    submit_confirmed_observation(
        client, reg["token"], lat=center[0], lon=center[1], nivel_g4="severo", flag_danio=True
    )
    submit_confirmed_observation(
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
    # El centro de la celda del heatmap (binning), no un punto individual.
    assert (cell["lat"], cell["lon"]) == center
    assert "snapshot_quarter" in cell


def test_grid_separates_far_points_into_distinct_cells(client, db_session):
    """Puntos a > 300 m caen en celdas distintas; cada una con su propio conteo."""
    reg = register(client)
    submit_confirmed_observation(client, reg["token"], lat=LAT, lon=LON, nivel_g4="sano")
    # ~610 m al norte ⇒ otra celda.
    submit_confirmed_observation(client, reg["token"], lat=LAT + 0.0055, lon=LON, nivel_g4="moderado")

    grid = client.get("/api/v1/public/grid").json()
    assert len(grid) == 2, grid
    assert {c["n"] for c in grid} == {1}


def test_grid_excludes_rejected_observations(client, db_session):
    """Una observación rechazada sale del mapa de calor (igual que /public/observations)."""
    reg = register(client)
    submit_confirmed_observation(client, reg["token"], lat=LAT, lon=LON, nivel_g4="leve")
    submit_confirmed_observation(client, reg["token"], lat=LAT + 0.0055, lon=LON, nivel_g4="severo")
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


def test_grid_excludes_observations_pending_review(client, db_session):
    """CR-026: una observación recién subida (``aceptada``) NO entra al mapa hasta confirmarse.

    Es el cambio de fondo pedido por las universidades: mientras nadie la revise, una foto que
    podría no ser un mezquite no se publica. Antes (CR-001) bastaba con no estar rechazada.
    """
    reg = register(client)
    # Sin confirmar: queda en 'aceptada' (pendiente de revisión).
    submit_observation(client, reg["token"], lat=LAT, lon=LON, nivel_g4="leve")
    assert client.get("/api/v1/public/grid").json() == []
    assert client.get("/api/v1/public/observations").json() == []

    # Un veredicto de confirmación la publica.
    submit_confirmed_observation(client, reg["token"], lat=LAT, lon=LON, nivel_g4="leve")
    assert len(client.get("/api/v1/public/grid").json()) == 1


def test_grid_returns_binned_cell_not_individual_points(client, db_session):
    """El heatmap agrega por celda (binning): devuelve el centro de celda, no el punto capturado."""
    reg = register(client)
    exact_lat, exact_lon = 21.885311, -102.291622
    submit_confirmed_observation(client, reg["token"], lat=exact_lat, lon=exact_lon)

    grid = client.get("/api/v1/public/grid").json()
    assert len(grid) == 1
    cell = grid[0]
    # La celda del heatmap es el centro de celda del binning, no el punto individual.
    assert (cell["lat"], cell["lon"]) != (exact_lat, exact_lon)
    assert (cell["lat"], cell["lon"]) == obfuscate_to_grid(exact_lat, exact_lon)
    # No expone listas de árboles ni ids individuales: solo conteos agregados.
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
    submit_confirmed_observation(client, reg["token"], lat=center[0], lon=center[1], nivel_g4="sano")
    submit_confirmed_observation(
        client, reg["token"], lat=center[0] + 0.00004, lon=center[1] + 0.00004, nivel_g4="severo"
    )

    grid = client.get("/api/v1/public/grid").json()
    assert len(grid) == 1
    assert grid[0]["g4_indice"] == 1.5


def test_grid_filter_by_estado(client, db_session):
    """Acepta `estado` como /public/observations."""
    reg = register(client)
    submit_confirmed_observation(client, reg["token"], lat=LAT, lon=LON)
    db_session.execute(text("UPDATE observation SET estado='Aguascalientes'"))
    db_session.commit()

    ags = client.get("/api/v1/public/grid?estado=Aguascalientes").json()
    other = client.get("/api/v1/public/grid?estado=Jalisco").json()
    assert len(ags) == 1
    assert other == []
