"""Auth (gate #2 acotado por CR-002).

- App (voluntarios): el `sub` opaco de Google (sin PII) se mapea a una cuenta y deriva un **handle**
  de presentación; el **código de respaldo** queda como legado (arranque limpio).
- Backend (administrador/evaluador/analista): **usuario + contraseña** con hash **argon2**.
- La recuperación legada usa el hash del código de respaldo (PBKDF2).
- El token (JWT firmado con `AUTH_SECRET`) lleva en el payload solo `sub` (account_id),
  `handle` y `role`. **Sin PII** (nunca email/nombre).
"""

from __future__ import annotations

import hashlib
import hmac
import secrets
import uuid
from datetime import datetime, timedelta, timezone

from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
from jose import JWTError, jwt

from .config import get_settings

# Alfabeto sin caracteres ambiguos para el código de respaldo legible.
_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

# Hasher de contraseñas de los roles de backend (CR-002). argon2id por defecto.
_password_hasher = PasswordHasher()

# Hash del código de respaldo: PBKDF2-HMAC-SHA256 con sal por código (sin dependencias nativas;
# evita la fragilidad passlib↔bcrypt entre versiones). Formato: "pbkdf2_sha256$iter$salt$hash".
_PBKDF2_ITERATIONS = 200_000


def _pbkdf2(code: str, salt: bytes, iterations: int) -> bytes:
    return hashlib.pbkdf2_hmac("sha256", code.encode("utf-8"), salt, iterations)


def generate_handle() -> str:
    """Handle seudonimizado, único y sin PII (p.ej. ``obs-7HQ4K2``)."""
    suffix = "".join(secrets.choice(_ALPHABET) for _ in range(6))
    return f"obs-{suffix}"


def generate_backup_code() -> str:
    """Código de respaldo de un solo uso para recuperación sin PII (p.ej. ``MZQ-4F7K-9PQR``)."""
    part1 = "".join(secrets.choice(_ALPHABET) for _ in range(4))
    part2 = "".join(secrets.choice(_ALPHABET) for _ in range(4))
    return f"MZQ-{part1}-{part2}"


def hash_backup_code(code: str) -> str:
    """Hash PBKDF2 del código de respaldo (lo único que persiste; el código plano no se guarda)."""
    norm = code.strip().upper()
    salt = secrets.token_bytes(16)
    digest = _pbkdf2(norm, salt, _PBKDF2_ITERATIONS)
    return f"pbkdf2_sha256${_PBKDF2_ITERATIONS}${salt.hex()}${digest.hex()}"


def verify_backup_code(code: str, hashed: str) -> bool:
    try:
        scheme, iters, salt_hex, digest_hex = hashed.split("$")
        if scheme != "pbkdf2_sha256":
            return False
        expected = bytes.fromhex(digest_hex)
        actual = _pbkdf2(code.strip().upper(), bytes.fromhex(salt_hex), int(iters))
        return hmac.compare_digest(actual, expected)
    except (ValueError, AttributeError):
        return False


def create_token(*, account_id: uuid.UUID, handle: str, role: str) -> str:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(account_id),
        "handle": handle,
        "role": role,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(seconds=settings.auth_token_ttl_seconds)).timestamp()),
    }
    return jwt.encode(payload, settings.auth_secret, algorithm=settings.auth_algorithm)


def decode_token(token: str) -> dict:
    """Decodifica y valida el token. Lanza ``ValueError`` si es inválido/expirado."""
    settings = get_settings()
    try:
        return jwt.decode(token, settings.auth_secret, algorithms=[settings.auth_algorithm])
    except JWTError as exc:
        raise ValueError("token inválido o expirado") from exc


# --- Contraseñas de los roles de backend (CR-002, hash argon2) ---


def hash_password(password: str) -> str:
    """Hash argon2id de la contraseña (lo único que se persiste; el plano no se guarda)."""
    return _password_hasher.hash(password)


def verify_password(password: str, hashed: str | None) -> bool:
    """Verifica la contraseña contra su hash argon2. ``False`` si no hay hash o no coincide."""
    if not hashed:
        return False
    try:
        return _password_hasher.verify(hashed, password)
    except (VerifyMismatchError, ValueError, TypeError):
        return False


def generate_temp_password() -> str:
    """Contraseña temporal de invitación (la cambia el usuario al primer login)."""
    part1 = "".join(secrets.choice(_ALPHABET) for _ in range(4))
    part2 = "".join(secrets.choice(_ALPHABET) for _ in range(4))
    return f"Mzq-{part1}-{part2}"


# --- Handle de presentación derivado del `sub` opaco de Google (CR-002, sin PII) ---


def handle_from_subject(provider: str, subject: str) -> str:
    """Handle estable y sin PII derivado de ``provider:subject``.

    Determinista (mismo `sub` ⇒ mismo handle), corto y legible (p.ej. ``obs-7HQ4K2``). NO contiene
    email/nombre: solo un hash truncado del id opaco del proveedor.
    """
    digest = hashlib.sha256(f"{provider}:{subject}".encode("utf-8")).digest()
    # Mapea los primeros bytes al alfabeto legible (6 caracteres).
    suffix = "".join(_ALPHABET[b % len(_ALPHABET)] for b in digest[:6])
    return f"obs-{suffix}"
