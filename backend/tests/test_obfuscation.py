"""Obfuscación a grid 1 km (gate #5, criterio Q5.B / T3). Pura, sin DB."""

from __future__ import annotations

import math

from backend.app.geo import obfuscate_1km

# Aguascalientes, MX.
LAT, LON = 21.8853, -102.2916


def _haversine_m(a, b):
    R = 6371000.0
    lat1, lon1, lat2, lon2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    dlat, dlon = lat2 - lat1, lon2 - lon1
    h = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    return 2 * R * math.asin(math.sqrt(h))


def test_obfuscation_moves_to_cell_center_within_1km():
    lat_o, lon_o = obfuscate_1km(LAT, LON)
    # El centro de celda está a < 1 km del punto original (celda de 1 km, centro a ≤ ~707 m).
    assert _haversine_m((LAT, LON), (lat_o, lon_o)) < 1000.0


def test_obfuscation_is_deterministic_and_snaps_neighbors_together():
    # Dos puntos a ~50 m caen en la misma celda → coords obfuscadas idénticas (no más finas que 1 km).
    p1 = obfuscate_1km(LAT, LON)
    p2 = obfuscate_1km(LAT + 0.0004, LON + 0.0004)  # ~50 m
    assert p1 == p2


def test_obfuscation_distinct_cells_for_far_points():
    a = obfuscate_1km(LAT, LON)
    b = obfuscate_1km(LAT + 0.05, LON + 0.05)  # ~7 km
    assert a != b


def test_obfuscation_never_returns_exact_input():
    # Nunca debe devolver la coord exacta (gate #5): siempre el centro de celda.
    lat_o, lon_o = obfuscate_1km(LAT, LON)
    assert (lat_o, lon_o) != (LAT, LON)
