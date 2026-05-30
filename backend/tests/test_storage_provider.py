"""StorageProvider conmutable local↔s3 (T4, gate #6). Sin DB."""

from __future__ import annotations

import uuid

import pytest

from backend.app.config import Settings
from backend.app.storage import (
    LocalFSStorage,
    S3CompatibleStorage,
    StorageProvider,
    build_storage,
    new_image_key,
)


def test_local_storage_roundtrip(tmp_path):
    store = LocalFSStorage(str(tmp_path), public_base_url="/files")
    key = new_image_key(uuid.uuid4())
    ref = store.put(key, b"imagen-bytes", content_type="image/jpeg")
    assert ref == key
    assert store.get(key) == b"imagen-bytes"
    assert store.url(key).startswith("/files/observations/")
    store.delete(key)
    with pytest.raises(FileNotFoundError):
        store.get(key)


def test_local_storage_rejects_path_traversal(tmp_path):
    store = LocalFSStorage(str(tmp_path))
    with pytest.raises(ValueError):
        store.put("../escape.txt", b"x")


def test_build_storage_switches_by_config(tmp_path):
    local = build_storage(Settings(storage_backend="local", storage_local_dir=str(tmp_path)))
    assert isinstance(local, LocalFSStorage)
    # s3 sin credenciales construye el cliente perezosamente; no hace I/O hasta usarlo.
    s3 = build_storage(Settings(storage_backend="s3", s3_bucket="b", s3_region="us-east-1"))
    assert isinstance(s3, S3CompatibleStorage)


def test_build_storage_unknown_backend_raises():
    with pytest.raises(ValueError):
        build_storage(Settings(storage_backend="azure-blob"))


def test_both_implementations_satisfy_interface():
    assert issubclass(LocalFSStorage, StorageProvider)
    assert issubclass(S3CompatibleStorage, StorageProvider)


@pytest.mark.skipif(
    pytest.importorskip("moto", reason="moto no instalado") is None, reason="moto no instalado"
)
def test_s3_storage_roundtrip_with_moto():
    """S3CompatibleStorage funcional contra un S3 simulado (moto) — paridad stg/prod (T4)."""
    import boto3
    from moto import mock_aws

    with mock_aws():
        client = boto3.client("s3", region_name="us-east-1")
        client.create_bucket(Bucket="mezquite-test")
        store = S3CompatibleStorage("mezquite-test", client=client)
        key = new_image_key(uuid.uuid4())
        store.put(key, b"s3-bytes", content_type="image/jpeg")
        assert store.get(key) == b"s3-bytes"
        assert "mezquite-test" in store.url(key)
        store.delete(key)
