"""Prepara `admin_boundary` con los límites municipales del INEGI (CR-036).

**Qué hace y por qué existe.** El servidor deriva estado y municipio de las coordenadas de cada
observación (CR-036), así que necesita los polígonos municipales en su propio PostGIS. Este script
convierte el **Marco Geoestadístico** del INEGI a la tabla `admin_boundary` y genera un volcado
listo para restaurar en producción.

**Se corre en la máquina de desarrollo, NUNCA en la VM del piloto.** La VM (2 vCPU / 4 GB) no es
lugar para procesar geometría nacional, igual que no compila Flutter: recibe el volcado ya hecho.

**Sin GDAL.** Lee el shapefile con `pyshp` (Python puro) y deja la reproyección a PostGIS
(`ST_Transform`), que ya está instalado. El origen viene en EPSG:6372 (MEXICO_ITRF_2008_LCC), el
mismo SRID métrico que el backend usa para el binning del mapa de calor.

**Descarga selectiva.** El paquete nacional del INEGI pesa 2.77 GB, pero solo se necesita la capa
municipal. El script usa *HTTP range requests* para leer el índice del ZIP remoto y bajar únicamente
la entrada `mg_2025_integrado.zip` (245 MB), de la que extrae `00mun.*`. Son ~9 % de los bytes.

Uso típico::

    python scripts/geo/preparar_limites_inegi.py --todo --dsn postgresql://...

Fuente: INEGI, Marco Geoestadístico 2025. Datos de libre uso citando la fuente
(«Términos de Libre Uso de la Información del INEGI»).
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import subprocess
import sys
import time
import zipfile
from pathlib import Path

import psycopg
import requests
import shapefile

# --- constantes del origen ---------------------------------------------------------------------

URL_MG = (
    "https://www.inegi.org.mx/contenidos/productos/prod_serv/contenidos/espanol/"
    "bvinegi/productos/geografia/marcogeo/794551163061_s.zip"
)
ENTRADA_INTEGRADO = "mg_2025_integrado.zip"
CAPA_MUNICIPAL = "conjunto_de_datos/00mun"
CATALOGO_ESTATAL = "catalogos/áreas_geoestadísticas_estatales.csv"
SRID_ORIGEN = 6372  # MEXICO_ITRF_2008_LCC, declarado en 00mun.prj
ENCODING_INEGI = "latin-1"  # lo declara 00mun.cpg (ISO 8859-1)

FUENTE = "INEGI, Marco Geoestadístico 2025"

# Puntos de control: coordenadas REALES de producción y referencias conocidas.
# El cluster de 21.63–21.65 N / −102.97 W son las observaciones que destaparon CR-036: la app las
# etiquetó "Calvillo, Aguascalientes" y en realidad están del lado de Zacatecas.
PUNTOS_DE_CONTROL: list[tuple[float, float, str, str]] = [
    (21.6452, -102.9731, "Zacatecas", "Jalpa"),
    (21.6470, -102.9710, "Zacatecas", "Jalpa"),
    (21.6274, -102.9765, "Zacatecas", "Jalpa"),
    (21.6335, -102.9750, "Zacatecas", "Jalpa"),
    (21.8853, -102.2916, "Aguascalientes", "Aguascalientes"),
    (21.9613, -102.3436, "Aguascalientes", "Jesús María"),
    (21.8470, -102.7180, "Aguascalientes", "Calvillo"),
    (22.1470, -102.2760, "Aguascalientes", "Pabellón de Arteaga"),
]


# --- descarga selectiva ------------------------------------------------------------------------


class ArchivoHTTP(io.RawIOBase):
    """Archivo de solo lectura respaldado por peticiones HTTP Range.

    Permite abrir un ZIP remoto con `zipfile` y traer solo los bytes de la entrada que interesa,
    en vez de descargar el paquete completo.
    """

    def __init__(self, url: str) -> None:
        self.url = url
        self.session = requests.Session()
        head = self.session.head(url, timeout=60, allow_redirects=True)
        head.raise_for_status()
        self._size = int(head.headers["Content-Length"])
        self._pos = 0
        self.bytes_traidos = 0

    def readable(self) -> bool:
        return True

    def seekable(self) -> bool:
        return True

    def tell(self) -> int:
        return self._pos

    def seek(self, offset: int, whence: int = io.SEEK_SET) -> int:
        if whence == io.SEEK_SET:
            self._pos = offset
        elif whence == io.SEEK_CUR:
            self._pos += offset
        elif whence == io.SEEK_END:
            self._pos = self._size + offset
        return self._pos

    def read(self, size: int = -1) -> bytes:
        if size < 0:
            size = self._size - self._pos
        if size <= 0 or self._pos >= self._size:
            return b""
        fin = min(self._pos + size, self._size) - 1
        r = self.session.get(
            self.url, headers={"Range": f"bytes={self._pos}-{fin}"}, timeout=300
        )
        r.raise_for_status()
        data = r.content
        self._pos += len(data)
        self.bytes_traidos += len(data)
        return data

    def readinto(self, b) -> int:  # noqa: ANN001
        data = self.read(len(b))
        b[: len(data)] = data
        return len(data)


def descargar(destino: Path) -> Path:
    """Baja el integrado del MG y extrae la capa municipal + el catálogo estatal."""
    destino.mkdir(parents=True, exist_ok=True)
    integrado = destino / ENTRADA_INTEGRADO

    if not integrado.exists():
        print(f"descargando {ENTRADA_INTEGRADO} (range requests sobre 2.77 GB)…", flush=True)
        t0 = time.time()
        raw = ArchivoHTTP(URL_MG)
        with zipfile.ZipFile(io.BufferedReader(raw, buffer_size=8 << 20)) as zf:
            with zf.open(ENTRADA_INTEGRADO) as src, integrado.open("wb") as dst:
                while chunk := src.read(4 << 20):
                    dst.write(chunk)
        print(
            f"  {integrado.stat().st_size/1024/1024:.1f} MB en {time.time()-t0:.0f} s "
            f"({raw.bytes_traidos/1024/1024:.0f} MB por HTTP)",
            flush=True,
        )
    else:
        print(f"ya estaba: {integrado}", flush=True)

    with zipfile.ZipFile(integrado) as zf:
        for nombre in zf.namelist():
            if nombre.startswith(CAPA_MUNICIPAL + ".") or nombre == CATALOGO_ESTATAL:
                salida = destino / nombre.rsplit("/", 1)[-1]
                salida.write_bytes(zf.read(nombre))
    return destino


def leer_estados(directorio: Path) -> dict[str, str]:
    """Clave de entidad → nombre del estado, desde el catálogo del INEGI."""
    ruta = directorio / CATALOGO_ESTATAL.rsplit("/", 1)[-1]
    texto = ruta.read_bytes().decode(ENCODING_INEGI)
    estados: dict[str, str] = {}
    for fila in csv.reader(io.StringIO(texto)):
        if len(fila) >= 2 and fila[0].strip().isdigit() and len(fila[0].strip()) == 2:
            estados[fila[0].strip()] = fila[1].strip()
    if len(estados) != 32:
        raise SystemExit(f"catálogo estatal inesperado: {len(estados)} entidades (se esperaban 32)")
    return estados


# --- carga a PostGIS ---------------------------------------------------------------------------


def cargar(dsn: str, directorio: Path) -> int:
    """Vacía y repuebla `admin_boundary` con la capa municipal. Devuelve el nº de filas."""
    estados = leer_estados(directorio)
    lector = shapefile.Reader(str(directorio / "00mun"), encoding=ENCODING_INEGI)
    campos = [f[0] for f in lector.fields[1:]]
    total = len(lector)
    print(f"shapefile: {total} municipios · campos {campos}", flush=True)

    with psycopg.connect(dsn, autocommit=False) as conn, conn.cursor() as cur:
        cur.execute("CREATE EXTENSION IF NOT EXISTS postgis")
        # En la base de PREPARACIÓN la tabla no existe (no corre alembic aquí). En producción sí:
        # la crea 0001 y la migración 0009 le añade las claves, así que este DDL no aplica allá y el
        # volcado es `--data-only`. Debe reflejar la MISMA forma que `models.AdminBoundary`.
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS admin_boundary (
                id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                estado    text,
                municipio text,
                cve_ent   text,
                cve_mun   text,
                geom      geography(MultiPolygon, 4326) NOT NULL
            )
            """
        )
        cur.execute(
            "CREATE INDEX IF NOT EXISTS admin_boundary_geom_gix ON admin_boundary USING gist (geom)"
        )
        # Recarga completa: la tabla es un catálogo derivado, no un histórico.
        cur.execute("TRUNCATE admin_boundary")

        insertados = 0
        t0 = time.time()
        for sr in lector.iterShapeRecords():
            d = dict(zip(campos, sr.record))
            cve_ent, cve_mun = d["CVE_ENT"], d["CVE_MUN"]
            estado = estados.get(cve_ent)
            if estado is None:
                raise SystemExit(f"clave de entidad desconocida: {cve_ent}")

            geojson = json.dumps(sr.shape.__geo_interface__)
            cur.execute(
                """
                INSERT INTO admin_boundary (estado, municipio, cve_ent, cve_mun, geom)
                VALUES (
                    %(estado)s, %(municipio)s, %(cve_ent)s, %(cve_mun)s,
                    ST_Multi(
                        ST_MakeValid(
                            ST_Transform(
                                ST_SetSRID(ST_GeomFromGeoJSON(%(geojson)s), %(srid)s),
                                4326
                            )
                        )
                    )::geography
                )
                """,
                {
                    "estado": estado,
                    "municipio": d["NOMGEO"],
                    "cve_ent": cve_ent,
                    "cve_mun": cve_mun,
                    "geojson": geojson,
                    "srid": SRID_ORIGEN,
                },
            )
            insertados += 1
            if insertados % 250 == 0:
                print(f"  {insertados}/{total} ({time.time()-t0:.0f} s)", flush=True)

        conn.commit()
        cur.execute("ANALYZE admin_boundary")
        conn.commit()

    print(f"cargados {insertados} municipios en {time.time()-t0:.0f} s", flush=True)
    return insertados


# --- verificación ------------------------------------------------------------------------------

SQL_RESOLVER = """
SELECT estado, municipio, cve_ent, cve_mun
FROM admin_boundary
WHERE ST_Intersects(geom, ST_SetSRID(ST_MakePoint(%(lon)s, %(lat)s), 4326)::geography)
ORDER BY cve_ent, cve_mun
LIMIT 1
"""


def verificar(dsn: str) -> bool:
    """Prueba de aceptación del dataset (AC1/AC5). Devuelve True si todo cuadra."""
    ok = True
    with psycopg.connect(dsn) as conn, conn.cursor() as cur:
        cur.execute("SELECT count(*), count(DISTINCT cve_ent) FROM admin_boundary")
        filas, entidades = cur.fetchone()
        print(f"\nfilas: {filas} · entidades distintas: {entidades}")
        if entidades != 32:
            print(f"  FALLA: se esperaban 32 entidades, hay {entidades}")
            ok = False

        cur.execute("SELECT count(*) FROM admin_boundary WHERE NOT ST_IsValid(geom::geometry)")
        invalidas = cur.fetchone()[0]
        print(f"geometrías inválidas: {invalidas}")
        if invalidas:
            print("  FALLA: hay geometrías inválidas tras ST_MakeValid")
            ok = False

        print("\npuntos de control:")
        for lat, lon, esperado_estado, esperado_mun in PUNTOS_DE_CONTROL:
            t0 = time.perf_counter()
            cur.execute(SQL_RESOLVER, {"lat": lat, "lon": lon})
            fila = cur.fetchone()
            ms = (time.perf_counter() - t0) * 1000
            obtenido = f"{fila[1]}, {fila[0]}" if fila else "(sin resolver)"
            bien = bool(fila) and fila[0] == esperado_estado and fila[1] == esperado_mun
            ok = ok and bien
            print(
                f"  [{'ok ' if bien else 'FALLA'}] {lat:>9.4f},{lon:>10.4f} -> {obtenido:<38}"
                f" ({ms:5.1f} ms)   esperado: {esperado_mun}, {esperado_estado}"
            )
    return ok


def volcar(dsn: str, salida: Path) -> None:
    """Genera el volcado de `admin_boundary` listo para restaurar en producción."""
    salida.parent.mkdir(parents=True, exist_ok=True)
    cmd = ["pg_dump", "--format=custom", "--table=admin_boundary", "--data-only", "--file", str(salida), dsn]
    print(f"\nvolcando -> {salida}", flush=True)
    subprocess.run(cmd, check=True)
    print(f"  {salida.stat().st_size/1024/1024:.1f} MB", flush=True)


# --- CLI ---------------------------------------------------------------------------------------


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--dsn", default="postgresql://mezquite:mezquite@localhost:55432/geoprep")
    p.add_argument("--dir", type=Path, default=Path("./.geo-inegi"))
    p.add_argument("--descargar", action="store_true")
    p.add_argument("--cargar", action="store_true")
    p.add_argument("--verificar", action="store_true")
    p.add_argument("--volcar", type=Path, default=None)
    p.add_argument("--todo", action="store_true", help="descargar + cargar + verificar")
    a = p.parse_args()

    if a.todo or a.descargar:
        descargar(a.dir)
    if a.todo or a.cargar:
        cargar(a.dsn, a.dir)
    if a.todo or a.verificar:
        if not verificar(a.dsn):
            print("\nLA PRUEBA DE ACEPTACIÓN FALLÓ: el dataset no se publica.", file=sys.stderr)
            return 1
        print("\nprueba de aceptación: OK")
    if a.volcar:
        volcar(a.dsn, a.volcar)
    return 0


if __name__ == "__main__":
    sys.exit(main())
