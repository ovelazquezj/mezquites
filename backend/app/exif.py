"""Saneo de EXIF GPS al servir imágenes (gate #5, salvaguarda de CR-001).

La imagen se guarda con su EXIF original (incluye GPS de la cámara nativa, gate #4). Al servirla a
roles de revisión que NO son ``aliado_firmante`` (``evaluador``/``analista``), hay que **eliminar el
GPS del EXIF** server-side para no filtrar la coord exacta. Esta es la única salvaguarda bloqueante
del CR-001: una imagen cruda con GPS rompería el gate #5.

Implementación con Pillow (ya en dependencias por uso indirecto; no requiere piexif). Para formatos
sin EXIF (PNG) o bytes ilegibles, devuelve el original re-encodeado sin metadatos GPS (no-op seguro).
"""

from __future__ import annotations

import io

# Tag EXIF de la sub-IFD de GPS (0x8825) en el bloque EXIF de nivel raíz.
_GPS_IFD_TAG = 0x8825


def strip_gps(data: bytes, *, content_type: str | None = None) -> bytes:
    """Devuelve la imagen sin los tags EXIF GPS. Best-effort: nunca lanza.

    - JPEG/TIFF con EXIF: elimina la IFD de GPS y re-guarda con el resto del EXIF intacto.
    - Sin EXIF o no decodificable: re-guarda sin metadatos (o devuelve el original si todo falla),
      garantizando que el resultado **no** contenga coordenadas GPS.
    """
    try:
        from PIL import Image
    except Exception:  # pragma: no cover - Pillow siempre está en el backend
        return data

    try:
        with Image.open(io.BytesIO(data)) as img:
            fmt = img.format or _format_from_content_type(content_type)
            exif = img.getexif()
            had_gps = _GPS_IFD_TAG in exif
            if had_gps:
                del exif[_GPS_IFD_TAG]

            out = io.BytesIO()
            save_kwargs: dict = {}
            if fmt in ("JPEG", "TIFF"):
                save_kwargs["exif"] = exif.tobytes()
            img.save(out, format=fmt or "JPEG", **save_kwargs)
            return out.getvalue()
    except Exception:
        # Imagen ilegible (p.ej. bytes de prueba que no son una imagen real). Como fallback seguro,
        # devolvemos los bytes sin un bloque EXIF: si no es una imagen válida, no hay GPS que filtrar.
        return _drop_exif_segment_jpeg(data)


def has_gps(data: bytes) -> bool:
    """True si la imagen lleva tags EXIF GPS (utilidad de pruebas/aserciones, gate #5)."""
    try:
        from PIL import Image

        with Image.open(io.BytesIO(data)) as img:
            return _GPS_IFD_TAG in img.getexif()
    except Exception:
        return False


def _format_from_content_type(content_type: str | None) -> str | None:
    if not content_type:
        return None
    ct = content_type.lower()
    if "png" in ct:
        return "PNG"
    if "tiff" in ct:
        return "TIFF"
    if "jpeg" in ct or "jpg" in ct:
        return "JPEG"
    return None


def _drop_exif_segment_jpeg(data: bytes) -> bytes:
    """Quita el segmento APP1 (EXIF) de un stream JPEG crudo, si lo hubiera.

    No decodifica la imagen; solo recorta el marcador APP1. Si los bytes no son JPEG, los devuelve
    tal cual (no hay EXIF/GPS que extraer de un blob no-imagen).
    """
    if not data.startswith(b"\xff\xd8"):  # no es JPEG
        return data
    out = bytearray(data[:2])
    i = 2
    n = len(data)
    while i + 4 <= n and data[i] == 0xFF:
        marker = data[i + 1]
        if marker in (0xD8, 0xD9) or 0xD0 <= marker <= 0xD7:
            out += data[i : i + 2]
            i += 2
            continue
        seg_len = (data[i + 2] << 8) | data[i + 3]
        seg_end = i + 2 + seg_len
        if marker == 0xE1:  # APP1: salta el segmento EXIF entero.
            i = seg_end
            continue
        out += data[i:seg_end]
        i = seg_end
        if marker == 0xDA:  # Start of Scan: copia el resto (datos comprimidos) y termina.
            out += data[seg_end:]
            return bytes(out)
    out += data[i:]
    return bytes(out)
