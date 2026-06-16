"""Indicadores de éxito Q6 — calculados automáticamente, **régimen U1 (sin umbrales/targets)**.

Gate (Q6/U1): **ningún indicador dispara lógica de aprobación/reprobación**. Solo se cuenta y se
expone. El régimen es de seguimiento, no de evaluación.

Categorías (Q6-D1):
- Social: registrados; activos (≥1 obs/30 días); observaciones totales y confirmadas por revisión
  humana (CR-001); instituciones activas (F3).
- Educativo: engagement formativo (placeholders agregados; los datos de Aprendizaje los aporta el
  cliente móvil en Inc 3); distribución de etiquetas de identidad E3; proporción de observaciones
  no-rechazadas (revisión humana, CR-001).
- Ecológico: árboles únicos (tree_id); árboles en serie temporal (≥2 obs, gap >30 días); cobertura
  geográfica (# municipios con ≥1 obs); distribución de niveles de infestación.
- Organizacional: capturado manualmente en la web admin (tabla `organizational_indicator`).
"""

from __future__ import annotations

from sqlalchemy import text
from sqlalchemy.orm import Session

CAVEAT = (
    "Datos de origen ciudadano, sin validación por expertos; "
    "especie y nivel autodeclarados."
)


def _estado_clause(col: str = "estado") -> str:
    # CAST explícito: psycopg3 no infiere el tipo de un parámetro usado como `:p IS NULL`.
    return f"(CAST(:estado AS text) IS NULL OR {col} = :estado)"


def compute_indicators(db: Session, *, estado: str | None = None) -> dict:
    """Computa los indicadores Q6. Filtrable por ``estado`` (Q8). Sin umbrales (U1)."""
    obs_filter = f"WHERE {_estado_clause()}"
    params = {"estado": estado}

    social = {
        "registrados": db.execute(text("SELECT count(*) FROM account")).scalar_one(),
        "activos_30d": db.execute(
            text(
                f"""
                SELECT count(DISTINCT account_id) FROM observation
                {obs_filter} AND captured_at >= now() - interval '30 days'
                """
            ),
            params,
        ).scalar_one(),
        "observaciones_totales": db.execute(
            text(f"SELECT count(*) FROM observation {obs_filter}"), params
        ).scalar_one(),
        "observaciones_confirmadas": db.execute(
            text(f"SELECT count(*) FROM observation {obs_filter} AND estado_revision = 'confirmada'"),
            params,
        ).scalar_one(),
        "instituciones_activas": db.execute(
            text(
                f"""
                SELECT count(DISTINCT a.institution_id)
                FROM observation o JOIN account a ON a.id = o.account_id
                WHERE {_estado_clause('o.estado')} AND a.institution_id IS NOT NULL
                """
            ),
            params,
        ).scalar_one(),
    }

    # Distribución de etiquetas de identidad E3 y tasa de validación promedio por activo.
    identity_dist = {
        row[0]: row[1]
        for row in db.execute(
            text("SELECT identity_label, count(*) FROM account GROUP BY identity_label")
        ).all()
    }
    # Proporción de observaciones NO-rechazadas (revisión humana, CR-001). Sin umbrales (U1).
    val_rate = db.execute(
        text(
            f"""
            SELECT COALESCE(
                avg(CASE WHEN estado_revision <> 'rechazada' THEN 1.0 ELSE 0.0 END), 0)
            FROM observation {obs_filter}
            """
        ),
        params,
    ).scalar_one()
    educativo = {
        # Engagement formativo: lo aporta el cliente móvil (Inc 3); aquí queda el agregado disponible.
        "distribucion_identidad_e3": identity_dist,
        "proporcion_no_rechazadas": round(float(val_rate or 0.0), 4),
    }

    arboles_unicos = db.execute(text("SELECT count(*) FROM tree")).scalar_one()
    arboles_serie = db.execute(
        text(
            """
            SELECT count(*) FROM (
                SELECT tree_id FROM observation
                WHERE tree_id IS NOT NULL
                GROUP BY tree_id
                HAVING count(*) >= 2
                   AND (max(captured_at) - min(captured_at)) > interval '30 days'
            ) s
            """
        )
    ).scalar_one()
    municipios = db.execute(
        text(
            f"SELECT count(DISTINCT municipio) FROM observation {obs_filter} AND municipio IS NOT NULL"
        ),
        params,
    ).scalar_one()
    niveles = {
        row[0]: row[1]
        for row in db.execute(
            text(
                f"SELECT nivel_g4, count(*) FROM observation {obs_filter} GROUP BY nivel_g4"
            ),
            params,
        ).all()
    }
    ecologico = {
        "arboles_unicos": arboles_unicos,
        "arboles_serie_temporal": arboles_serie,
        "cobertura_municipios": municipios,
        "distribucion_niveles": niveles,
    }

    org_rows = db.execute(
        text(
            """
            SELECT key, value FROM organizational_indicator
            WHERE (CAST(:estado AS text) IS NULL OR estado = :estado)
            """
        ),
        params,
    ).all()
    organizacional = {row[0]: row[1] for row in org_rows}

    return {
        "social": social,
        "educativo": educativo,
        "ecologico": ecologico,
        "organizacional": organizacional,
    }
