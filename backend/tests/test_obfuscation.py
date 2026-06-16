"""Obfuscación a la celda de obfuscación (gate #5; CR-009: 300 m). Pura, sin DB.

CR-009 baja la celda pública de 1 km a 300 m. El parámetro es conmutable por config
(``settings.obfuscation_grid_m``, gate #6); estas pruebas validan el comportamiento con el valor
por defecto (300 m): el centro de celda está a < 300 m del punto, vecinos a ~50 m caen en la misma
celda, puntos lejanos caen en celdas distintas y NUNCA se devuelve la coord exacta.
"""

from __future__ import annotations

import math

from backend.app.config import get_settings
from backend.app.geo import obfuscate_1km, obfuscate_to_grid

# Aguascalientes, MX.
LAT, LON = 21.8853, -102.2916


def _haversine_m(a, b):
    R = 6371000.0
    lat1, lon1, lat2, lon2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    dlat, dlon = lat2 - lat1, lon2 - lon1
    h = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    return 2 * R * math.asin(math.sqrt(h))


def test_grid_default_is_300m():
    # CR-009: la celda pública por defecto es 300 m (gate #5, más fina que antes pero nunca exacta).
    assert get_settings().obfuscation_grid_m == 300.0


def test_alias_obfuscate_1km_still_points_to_grid():
    # El alias legado debe seguir resolviendo a la misma función (no romper imports existentes).
    assert obfuscate_1km is obfuscate_to_grid


def test_obfuscation_moves_to_cell_center_within_300m():
    lat_o, lon_o = obfuscate_to_grid(LAT, LON)
    # El centro de una celda de 300 m está a < 300 m del punto original (diagonal/2 ≈ 212 m).
    assert _haversine_m((LAT, LON), (lat_o, lon_o)) < 300.0


def test_obfuscation_is_deterministic_and_snaps_neighbors_together():
    # Partimos del CENTRO de una celda y tomamos un vecino a ~5 m: ambos caen en la misma celda de
    # 300 m → coords obfuscadas idénticas (no más finas que la celda). Anclar en el centro evita la
    # ambigüedad de frontera de celda.
    center = obfuscate_to_grid(LAT, LON)
    p1 = obfuscate_to_grid(center[0], center[1])
    p2 = obfuscate_to_grid(center[0] + 0.00004, center[1] + 0.00004)  # ~5 m
    assert p1 == p2 == center


def test_obfuscation_distinct_cells_for_far_points():
    a = obfuscate_to_grid(LAT, LON)
    b = obfuscate_to_grid(LAT + 0.05, LON + 0.05)  # ~7 km
    assert a != b


def test_obfuscation_distinct_cells_for_points_one_cell_apart():
    # Dos puntos separados ~600 m (≈ 2 celdas de 300 m) deben caer en celdas distintas.
    a = obfuscate_to_grid(LAT, LON)
    b = obfuscate_to_grid(LAT + 0.0055, LON)  # ~610 m al norte
    assert a != b
    assert _haversine_m((LAT, LON), (LAT + 0.0055, LON)) > 300.0


def test_obfuscation_never_returns_exact_input():
    # Nunca debe devolver la coord exacta (gate #5): siempre el centro de celda.
    lat_o, lon_o = obfuscate_to_grid(LAT, LON)
    assert (lat_o, lon_o) != (LAT, LON)
