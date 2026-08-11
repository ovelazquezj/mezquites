"""CR-036 (2026-08-10): geografía derivada del servidor — claves INEGI y precisión del GPS.

Origen: aparecieron en producción 39 observaciones al oeste de −102.867 (el punto más occidental de
Aguascalientes), todas etiquetadas "Calvillo, Aguascalientes". No fue descuido de captura: el
dropdown de la app tenía **una sola opción** de estado y ``municipioMasCercano`` elegía el centroide
más próximo de una lista de 11 **sin techo de distancia**, así que una captura en Zacatecas recibía
"Calvillo" automáticamente. El respaldo autoritativo por PostGIS (``derive_estado_municipio``) nunca
corría porque ``admin_boundary`` estaba vacía y, aun cargada, el valor del cliente ganaba.

Esta migración prepara el terreno para que **el servidor derive la geografía de las coordenadas**:

- **Claves INEGI (``cve_ent``/``cve_mun``)** en ``observation`` y en ``admin_boundary``. Los
  dashboards agrupan por **clave**, no por cadena. Es lo que evita que un acento parta una categoría
  y, sobre todo, que un homónimo funda dos: **"Jesús María" existe en Aguascalientes, en Jalisco y en
  Nayarit**, y con nombres los tres caerían en el mismo cubo de ``summary.por_municipio``. Los nombres
  se conservan (legibles, y siguen sirviendo como filtro por compatibilidad).
- **``gps_accuracy_m``**: la app ya pedía ``LocationAccuracy.best`` pero **nunca guardaba el valor**.
  Al retirar los dropdowns de la captura ya no queda ningún humano que pueda notar un fix malo cerca
  de un límite estatal, así que la precisión pasa a ser la única señal de calidad de la ubicación.

Tres decisiones de forma:

- **Todo nullable.** Las 2 185 observaciones históricas no tienen claves ni precisión. El backfill
  (fase aparte del despliegue, con simulacro y guarda) llena las claves; la precisión solo puede
  existir hacia adelante — nadie puede reconstruir el error de un GPS del pasado.
- **``admin_boundary`` guarda solo el nivel MUNICIPAL.** No hace falta una capa de entidades: el
  municipio ya trae su ``cve_ent`` y el nombre del estado, así que ``/geo/estados`` sale de un
  ``SELECT DISTINCT``. Una tabla, un nivel, sin ambigüedad sobre qué fila gana en el punto-en-polígono.
- **Índice único por clave en ``admin_boundary``.** Cargar los límites dos veces duplicaría los
  polígonos y el join espacial devolvería filas repetidas; que lo impida la base y no el cargador.

Revision ID: 0009_geografia_derivada
Revises: 0008_client_capture_id
Create Date: 2026-08-10
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0009_geografia_derivada"
down_revision = "0008_client_capture_id"
branch_labels = None
depends_on = None

IDX_OBS_CVE = "observation_cve_idx"
IDX_BOUNDARY_CVE = "ux_admin_boundary_cve"


def upgrade() -> None:
    # --- claves INEGI en las observaciones ---
    op.add_column("observation", sa.Column("cve_ent", sa.Text(), nullable=True))
    op.add_column("observation", sa.Column("cve_mun", sa.Text(), nullable=True))
    # Precisión reportada por el dispositivo, en metros (nunca negativa).
    op.add_column("observation", sa.Column("gps_accuracy_m", sa.Float(), nullable=True))
    op.create_check_constraint(
        "ck_obs_gps_accuracy_no_negativa",
        "observation",
        "gps_accuracy_m IS NULL OR gps_accuracy_m >= 0",
    )
    # Los dashboards filtran y agrupan por clave: (cve_ent) sola y (cve_ent, cve_mun).
    op.execute(f"CREATE INDEX {IDX_OBS_CVE} ON observation (cve_ent, cve_mun)")

    # --- claves INEGI en los límites administrativos ---
    op.add_column("admin_boundary", sa.Column("cve_ent", sa.Text(), nullable=True))
    op.add_column("admin_boundary", sa.Column("cve_mun", sa.Text(), nullable=True))
    # Un municipio, una fila. Impide que una segunda carga duplique polígonos y que el join
    # espacial devuelva el mismo municipio dos veces.
    op.execute(
        f"CREATE UNIQUE INDEX {IDX_BOUNDARY_CVE} ON admin_boundary (cve_ent, cve_mun) "
        "WHERE cve_ent IS NOT NULL AND cve_mun IS NOT NULL"
    )


def downgrade() -> None:
    op.execute(f"DROP INDEX IF EXISTS {IDX_BOUNDARY_CVE}")
    op.drop_column("admin_boundary", "cve_mun")
    op.drop_column("admin_boundary", "cve_ent")

    op.execute(f"DROP INDEX IF EXISTS {IDX_OBS_CVE}")
    op.drop_constraint("ck_obs_gps_accuracy_no_negativa", "observation", type_="check")
    op.drop_column("observation", "gps_accuracy_m")
    op.drop_column("observation", "cve_mun")
    op.drop_column("observation", "cve_ent")
