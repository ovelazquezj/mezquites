"""StorageProvider conmutable (T4 / gate #6).

Interfaz mínima (`ARCHITECTURE.md` §7): ``put / get / url / delete``. Dos implementaciones
seleccionables por ``STORAGE_BACKEND`` **sin tocar código de aplicación**:

- ``LocalFSStorage``      — filesystem local (dev/QA, sin nube).
- ``S3CompatibleStorage`` — object storage S3-compatible vía boto3 (stg/prod).

La DB guarda **solo la clave** (`image_ref`), nunca el binario.
"""

from __future__ import annotations

import os
import shutil
import uuid
from abc import ABC, abstractmethod
from pathlib import Path

from .config import Settings, get_settings


class StorageProvider(ABC):
    @abstractmethod
    def put(self, key: str, data: bytes, *, content_type: str = "application/octet-stream") -> str:
        """Guarda el binario bajo ``key`` y devuelve la referencia (clave) almacenable en DB."""

    @abstractmethod
    def get(self, key: str) -> bytes: ...

    @abstractmethod
    def url(self, key: str) -> str:
        """URL para servir/descargar el objeto (ruta local o presigned URL S3)."""

    @abstractmethod
    def delete(self, key: str) -> None: ...


class LocalFSStorage(StorageProvider):
    """Filesystem local (dev/QA). No requiere nube."""

    def __init__(self, root: str | os.PathLike[str], public_base_url: str = "/files") -> None:
        self._root = Path(root)
        self._root.mkdir(parents=True, exist_ok=True)
        self._base = public_base_url.rstrip("/")

    def _path(self, key: str) -> Path:
        # Evita escapes fuera de la raíz (path traversal).
        safe = Path(key.lstrip("/"))
        if ".." in safe.parts:
            raise ValueError(f"clave inválida: {key!r}")
        return self._root / safe

    def put(self, key: str, data: bytes, *, content_type: str = "application/octet-stream") -> str:
        path = self._path(key)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return key

    def get(self, key: str) -> bytes:
        return self._path(key).read_bytes()

    def url(self, key: str) -> str:
        return f"{self._base}/{key.lstrip('/')}"

    def delete(self, key: str) -> None:
        path = self._path(key)
        if path.exists():
            path.unlink()

    def reset(self) -> None:  # pragma: no cover - utilidad de pruebas
        if self._root.exists():
            shutil.rmtree(self._root)
        self._root.mkdir(parents=True, exist_ok=True)


class S3CompatibleStorage(StorageProvider):
    """Object storage S3-compatible (stg/prod). Soporta AWS S3 y MinIO vía ``endpoint_url``."""

    def __init__(
        self,
        bucket: str,
        *,
        endpoint_url: str | None = None,
        region: str = "us-east-1",
        access_key: str | None = None,
        secret_key: str | None = None,
        presign_ttl: int = 3600,
        client=None,
    ) -> None:
        self._bucket = bucket
        self._presign_ttl = presign_ttl
        if client is not None:
            self._s3 = client
        else:
            import boto3

            self._s3 = boto3.client(
                "s3",
                endpoint_url=endpoint_url,
                region_name=region,
                aws_access_key_id=access_key,
                aws_secret_access_key=secret_key,
            )

    def put(self, key: str, data: bytes, *, content_type: str = "application/octet-stream") -> str:
        self._s3.put_object(Bucket=self._bucket, Key=key, Body=data, ContentType=content_type)
        return key

    def get(self, key: str) -> bytes:
        resp = self._s3.get_object(Bucket=self._bucket, Key=key)
        return resp["Body"].read()

    def url(self, key: str) -> str:
        return self._s3.generate_presigned_url(
            "get_object",
            Params={"Bucket": self._bucket, "Key": key},
            ExpiresIn=self._presign_ttl,
        )

    def delete(self, key: str) -> None:
        self._s3.delete_object(Bucket=self._bucket, Key=key)


def build_storage(settings: Settings | None = None) -> StorageProvider:
    """Fábrica conmutable por ``STORAGE_BACKEND`` (gate #6). dev/QA → local; stg/prod → s3."""
    settings = settings or get_settings()
    backend = (settings.storage_backend or "local").lower()
    if backend == "local":
        return LocalFSStorage(settings.storage_local_dir, settings.storage_public_base_url)
    if backend == "s3":
        return S3CompatibleStorage(
            settings.s3_bucket,
            endpoint_url=settings.s3_endpoint_url,
            region=settings.s3_region,
            access_key=settings.s3_access_key,
            secret_key=settings.s3_secret_key,
            presign_ttl=settings.s3_presign_ttl,
        )
    raise ValueError(f"STORAGE_BACKEND desconocido: {backend!r} (use 'local' o 's3')")


_storage: StorageProvider | None = None


def get_storage() -> StorageProvider:
    """Singleton perezoso para dependencia FastAPI."""
    global _storage
    if _storage is None:
        _storage = build_storage()
    return _storage


def new_image_key(observation_id: uuid.UUID, suffix: str = ".jpg") -> str:
    """Clave determinista por observación: ``observations/<id>/<rand><suffix>``."""
    rand = uuid.uuid4().hex[:8]
    return f"observations/{observation_id}/{rand}{suffix}"
