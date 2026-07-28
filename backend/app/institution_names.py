"""Nombre canónico de institución — regla antiduplicados (CR-028).

**Una sola definición** de "el mismo nombre", usada por las tres capas que deben coincidir:

- el **índice único** de PostgreSQL (`ux_institution_nombre_norm`), vía :data:`NORMALIZED_NAME_SQL`;
- el **backend**, al buscar si ya existe antes de insertar, vía :func:`normalize_institution_name`;
- la **app**, que replica la misma regla en Dart (``Institution.normalizeName``) para avisar antes
  de mandar.

Dos nombres son el mismo si coinciden tras: quitar acentos, pasar a minúsculas, colapsar los
espacios internos y recortar los de los extremos. Así ``"  UNIVERSIDAD   Cuauhtémoc "`` y
``"universidad cuauhtemoc"`` son la misma institución.

Por qué el mapeo de acentos incluye MAYÚSCULAS y minúsculas: ``lower()`` de PostgreSQL solo pliega
caracteres no-ASCII si la base se inicializó con un locale UTF-8. La unicidad de un dato del
producto no puede depender de cómo se hizo el ``initdb`` del servidor, así que la traducción de
acentos se hace con ``translate()`` (independiente del locale) **antes** de bajar a minúsculas.

Gates: no toca PII (gate #2) ni gatea nada (gate #3) — el voluntario que escribe un nombre ya
existente queda afiliado a la institución existente, nunca bloqueado.
"""

from __future__ import annotations

import re
import unicodedata
from typing import TYPE_CHECKING

if TYPE_CHECKING:  # pragma: no cover - solo para anotaciones
    from sqlalchemy.orm import Session

    from .models import Institution

# (base, variantes acentuadas) — se construyen los dos argumentos de `translate` en paralelo para
# que sea imposible que queden desalineados.
_MAPA_ACENTOS: tuple[tuple[str, str], ...] = (
    ("A", "ÁÀÂÄÃ"),
    ("E", "ÉÈÊË"),
    ("I", "ÍÌÎÏ"),
    ("O", "ÓÒÔÖÕ"),
    ("U", "ÚÙÛÜ"),
    ("N", "Ñ"),
    ("C", "Ç"),
)

_ACENTOS = "".join(v for _, v in _MAPA_ACENTOS) + "".join(v.lower() for _, v in _MAPA_ACENTOS)
_BASES = "".join(b * len(v) for b, v in _MAPA_ACENTOS) + "".join(
    b.lower() * len(v) for b, v in _MAPA_ACENTOS
)

#: Expresión SQL que produce la forma canónica de ``institution.name``. Se usa tal cual en el índice
#: único (migración 0007) y en las búsquedas del backend. Referencia ``name`` sin calificar porque
#: PostgreSQL no admite nombres calificados dentro de una expresión de índice.
NORMALIZED_NAME_SQL = (
    "btrim(regexp_replace("
    f"lower(translate(name, '{_ACENTOS}', '{_BASES}'))"
    r", '\s+', ' ', 'g'))"
)

#: Nombre del índice único. Compartido por la migración y por el modelo (create_all en pruebas).
NORMALIZED_NAME_INDEX = "ux_institution_nombre_norm"


def normalize_institution_name(name: str) -> str:
    """Forma canónica de un nombre de institución. Debe coincidir con :data:`NORMALIZED_NAME_SQL`.

    ``unicodedata`` descompone y descarta los diacríticos, lo que cubre más alfabetos que el mapeo
    de ``translate``. La divergencia solo puede hacer que Python considere iguales dos nombres que
    el índice ve distintos (se reusa uno y no se inserta: inofensivo); el caso contrario lo atrapa
    el índice con un ``IntegrityError`` que los routers manejan.
    """
    descompuesto = unicodedata.normalize("NFKD", name)
    sin_acentos = "".join(c for c in descompuesto if not unicodedata.combining(c))
    return re.sub(r"\s+", " ", sin_acentos).strip().lower()


def find_by_normalized_name(db: Session, name: str) -> Institution | None:
    """La institución cuyo nombre canónico coincide con ``name``, o ``None``.

    Si por un histórico previo al índice hubiera más de una, devuelve la ``aprobada`` (ordena por
    ``status``: 'aprobada' < 'solicitada'), que es la que el voluntario debería poder elegir.
    """
    # Import diferido: `models` importa este módulo para declarar el índice, así que importarlo
    # arriba cerraría el ciclo.
    from sqlalchemy import text

    from .models import Institution

    return (
        db.query(Institution)
        .filter(text(f"{NORMALIZED_NAME_SQL} = :nombre_canonico"))
        .params(nombre_canonico=normalize_institution_name(name))
        .order_by(Institution.status)
        .first()
    )
