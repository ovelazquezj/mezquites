# Modelo de datos PostGIS

> Materializa Q2, Q3, Q5.A, Q5.B, Q5.D, Q6, Q8 sobre PostgreSQL 16 + PostGIS 3. El DDL es un
> **boceto de referencia** para el Incremento 2 (migraciones Alembic); los parámetros marcados son
> *refinables por AU2* (H8) sin reabrir decisiones.

## Convenciones

- Geometría de captura almacenada como `geography(Point, 4326)` (metros reales en cálculos de
  distancia, sin proyectar).
- Sin PII en ninguna tabla (gate #2).
- Estados de validación: `pendiente` → (`valida` | `ruido`). No hay otros (§6.4).

## Tablas núcleo

### `account` — cuenta seudonimizada (Q5.D-D1)
```sql
CREATE TABLE account (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    handle        text UNIQUE NOT NULL,                -- identidad pública; sin PII
    recovery_hash text NOT NULL,                       -- hash del código de respaldo / QR (sin PII)
    role          text NOT NULL DEFAULT 'voluntario'   -- voluntario | aliado_firmante | admin_consorcio
                  CHECK (role IN ('voluntario','aliado_firmante','admin_consorcio')),
    institution_id uuid REFERENCES institution(id),    -- F3; NULL ⇒ "Independiente"
    identity_label text NOT NULL DEFAULT 'nuevo_observador',  -- E3 (sin desbloquear funciones)
    created_at    timestamptz NOT NULL DEFAULT now()
);
```
> No hay columnas de email/teléfono/nombre. La recuperación usa `recovery_hash` (gate #2).

### `institution` — lista F3 (Q4)
```sql
CREATE TABLE institution (
    id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name      text NOT NULL,
    estado    text,                 -- dimensión geográfica para rankings C2 (Q8)
    status    text NOT NULL DEFAULT 'aprobada'   -- aprobada | solicitada (ticket a EA3)
              CHECK (status IN ('aprobada','solicitada'))
);
```

### `tree` — identidad de árbol por radio 10 m (Q2 R3)
```sql
CREATE TABLE tree (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    centroid    geography(Point, 4326) NOT NULL,   -- centroide de las observaciones agrupadas
    estado      text,
    municipio   text,
    created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX tree_centroid_gix ON tree USING gist (centroid);
```

### `observation` — 8 etiquetas de captura (Q2, Q3)
```sql
CREATE TABLE observation (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id      uuid NOT NULL REFERENCES account(id),
    handle          text NOT NULL,                 -- atribución pública I2 (denormalizado)
    image_ref       text NOT NULL,                 -- clave StorageProvider; nunca el binario
    -- EXIF (cámara nativa; gate #4)
    geom            geography(Point, 4326) NOT NULL,
    captured_at     timestamptz NOT NULL,
    -- triple etiqueta M3 (Q3) — AUTODECLARADAS, no validadas (gate #8)
    nivel_g4        text NOT NULL CHECK (nivel_g4 IN ('sano','leve','moderado','severo')),
    flag_cuscuta    boolean NOT NULL DEFAULT false,
    flag_danio      boolean NOT NULL DEFAULT false,
    -- campos adicionales V3 (Q2)
    tamanio         text CHECK (tamanio IN ('pequeno','mediano','grande','no_estimable')),
    contexto        text CHECK (contexto IN ('campo_abierto','borde_cultivo','urbano','ripario','otro')),
    -- agrupamiento / serie temporal (R3)
    tree_id         uuid REFERENCES tree(id),
    observation_seq integer,                        -- posición en la serie temporal del árbol
    -- dimensión geográfica (Q8)
    estado          text,
    municipio       text,
    -- validación (§6)
    validation_state text NOT NULL DEFAULT 'pendiente'
                     CHECK (validation_state IN ('pendiente','valida','ruido')),
    model_version    text,                          -- de quién vino el veredicto ('mock' | real)
    validated_at     timestamptz,
    created_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX observation_geom_gix ON observation USING gist (geom);
CREATE INDEX observation_tree_idx ON observation (tree_id, captured_at);
```
> El `validation_state` lo fija **solo** el consumidor de resultados del backend, aplicando la regla
> autoritativa §6.3. La UI del voluntario **no** expone este estado individual (gate Q5.A-D1).

### `validation_event` — idempotencia y auditoría (§6.4)
```sql
CREATE TABLE validation_event (
    observation_id uuid PRIMARY KEY REFERENCES observation(id),  -- 1 resultado aplicado por obs
    es_arbol       boolean NOT NULL,
    parasitos      boolean NOT NULL,
    veredicto      text NOT NULL CHECK (veredicto IN ('valida','ruido')),
    score_arbol    real,
    score_parasitos real,
    model_version  text NOT NULL,
    applied_at     timestamptz NOT NULL DEFAULT now()
);
```
> El PK por `observation_id` hace **idempotente** la aplicación del resultado: una reentrega de la
> cola hace `INSERT ... ON CONFLICT DO NOTHING` y **no duplica puntos** (gate #9, §6.4).

### `points_ledger` — recompensa diferida (Q4)
```sql
CREATE TABLE points_ledger (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id     uuid NOT NULL REFERENCES account(id),
    observation_id uuid REFERENCES observation(id),
    kind           text NOT NULL CHECK (kind IN ('base','diferida')),
    points         integer NOT NULL,
    created_at     timestamptz NOT NULL DEFAULT now(),
    UNIQUE (observation_id, kind)   -- 'diferida' una sola vez por observación válida
);
```

## Consultas clave (criterios de aceptación)

### Agrupar dentro de 10 m → asignar `tree_id` (Q2/R3, criterio T3)
```sql
-- ¿existe ya un árbol a ≤ 10 m del punto capturado?
SELECT id
FROM   tree
WHERE  ST_DWithin(centroid, :geom, 10)   -- metros (geography)
ORDER  BY ST_Distance(centroid, :geom)
LIMIT  1;
-- si no existe → INSERT tree; si existe → reutilizar id.
-- observation_seq: nº de observaciones previas del árbol con gap > 30 días respecto a la última.
```

### Serie temporal (≥ 2 obs, gap > 30 días) (Q2/R3, Q6 ecológico)
```sql
SELECT tree_id
FROM   observation
GROUP  BY tree_id
HAVING count(*) >= 2
   AND (max(captured_at) - min(captured_at)) > interval '30 days';
```

### Agregación por celda para el mapa de calor (binning)
```sql
-- Binning del mapa de calor: agrupa observaciones por celda (densidad/severidad).
SELECT ST_SnapToGrid(geom::geometry, 0.01)::geography AS celda   -- ~1 km en lat; ver nota
FROM   observation;
```
> Nota: 0.01° ≈ 1.11 km en latitud y varía en longitud. Para una celda métrica se usa `ST_SnapToGrid`
> sobre una proyección métrica (p.ej. EPSG:6372 México) y se reproyecta; el backend implementa el helper
> `geo.obfuscate_to_grid` con la proyección métrica.
> **CR-025 (2026-07-12):** las vistas públicas muestran la **ubicación exacta** del árbol; esta
> agregación se conserva **solo** como *binning* del mapa de calor (no es un límite de privacidad).

### Dimensión estado/municipio desde EXIF (Q8, gate de escalamiento)
```sql
-- join espacial a límites administrativos (tabla admin_boundary, cargada por separado)
SELECT ab.estado, ab.municipio
FROM   admin_boundary ab
WHERE  ST_Contains(ab.geom, :geom::geometry)
LIMIT  1;
```

## Parámetros refinables por AU2 (H8) — no reabren decisiones
- Radio de agrupamiento: **10 m** (R3).
- Ventana de revisita / serie temporal: **30 días** (R3).
- Cortes % de la escala G4: sano 0 / leve ≤25 / moderado ≤50 / severo >50 (Q3, A2).
- Tamaño de celda del **mapa de calor** (binning): **300 m** (`obfuscation_grid_m`). **CR-025:** ya no
  es un mínimo de privacidad público (la vista pública es exacta); solo controla la agregación del calor.
