"""Proveedor de auth social CONMUTABLE (CR-002, salvaguarda del gate #6).

El login social no puede correr offline, así que —igual que broker/storage— se introduce una
abstracción ``AuthProvider`` con dos implementaciones seleccionables por ``AUTH_PROVIDER``:

- ``MockAuthProvider`` (``AUTH_PROVIDER=mock``): dev/QA/test. Acepta un token de prueba SIN red ni
  Google y devuelve un ``sub`` opaco (fijo o embebido en el token con el formato ``mock:<sub>``).
- ``FirebaseAuthProvider`` (``AUTH_PROVIDER=firebase``): prod. Verifica el **ID token** de Google
  server-side con ``google-auth`` (valida firma, ``aud``/``iss``) y extrae el ``sub``.

Gate #2 acotado: el proveedor devuelve **solo** el id opaco (``provider`` + ``subject``). El email y
el nombre del token de Google **se descartan** (jamás se persisten).
"""

from __future__ import annotations

import base64
import json
import logging
from dataclasses import dataclass

from .config import Settings, get_settings

# Logger de uvicorn: garantiza que los WARNING aparezcan en `docker compose logs api`.
logger = logging.getLogger("uvicorn.error")


def _peek_unverified(id_token: str | None) -> str:
    """Decodifica SIN verificar el payload del JWT, solo para diagnóstico de fallos de login.

    Devuelve únicamente ``aud``/``iss``/``exp``/``iat``/``azp`` (no son PII; nunca ``email``/``sub``)
    para distinguir audiencia equivocada vs. token expirado vs. "no es un ID token" en los logs.
    """
    try:
        parts = (id_token or "").split(".")
        if len(parts) != 3:
            return f"no-es-jwt (segmentos={len(parts)}, len={len(id_token or '')})"
        pad = parts[1] + "=" * (-len(parts[1]) % 4)
        payload = json.loads(base64.urlsafe_b64decode(pad))
        return repr({k: payload.get(k) for k in ("aud", "iss", "exp", "iat", "azp")})
    except Exception as exc:  # noqa: BLE001
        return f"no-decodificable: {exc}"


class AuthVerificationError(Exception):
    """El ID token no es válido (firma/audiencia/emisor o token mock desconocido)."""


@dataclass(frozen=True)
class VerifiedIdentity:
    """Identidad verificada del proveedor social. SOLO el id opaco (sin PII)."""

    provider: str  # p.ej. "social_google"
    subject: str   # el `sub` opaco del proveedor (Google)


class AuthProvider:
    """Interfaz del verificador de ID token social."""

    provider_name: str = "social_google"

    def verify_id_token(self, id_token: str) -> VerifiedIdentity:  # pragma: no cover - interfaz
        raise NotImplementedError


class MockAuthProvider(AuthProvider):
    """Verificador offline para dev/QA/test (sin red ni Google).

    Acepta:
    - el token fijo configurado (``MOCK_GOOGLE_TOKEN``) → ``sub`` fijo ``mock-sub-default``;
    - cualquier token con el prefijo ``mock:`` → el ``sub`` es lo que sigue al prefijo
      (p.ej. ``mock:alice`` → ``sub=alice``), útil para simular varios usuarios en pruebas.
    """

    def __init__(self, accepted_token: str) -> None:
        self._accepted_token = accepted_token

    def verify_id_token(self, id_token: str) -> VerifiedIdentity:
        token = (id_token or "").strip()
        if token.startswith("mock:") and len(token) > len("mock:"):
            return VerifiedIdentity(self.provider_name, token[len("mock:") :])
        if token and token == self._accepted_token:
            return VerifiedIdentity(self.provider_name, "mock-sub-default")
        raise AuthVerificationError("token de prueba inválido para el MockAuthProvider")


class FirebaseAuthProvider(AuthProvider):
    """Verificador real del ID token de Google/Firebase (prod).

    Usa ``google-auth`` contra las llaves públicas de Google y valida ``aud``/``iss``. Importa
    ``google-auth`` de forma perezosa para no exigirlo en dev/QA (donde se usa el mock).
    """

    def __init__(self, audience: str | None, project_id: str | None) -> None:
        # aud esperado: el client id OAuth (o el project id de Firebase si coincide).
        self._audience = audience or project_id
        self._project_id = project_id

    def verify_id_token(self, id_token: str) -> VerifiedIdentity:
        try:
            from google.auth.transport import requests as google_requests
            from google.oauth2 import id_token as google_id_token
        except ImportError as exc:  # pragma: no cover - solo en entornos sin google-auth
            raise AuthVerificationError(
                "google-auth no está instalado; requerido para AUTH_PROVIDER=firebase"
            ) from exc

        try:
            claims = google_id_token.verify_oauth2_token(
                id_token,
                google_requests.Request(),
                self._audience,
                # Tolera desfase de reloj (gotcha clásico que produce 401 espurios "used too early").
                clock_skew_in_seconds=10,
            )
        except Exception as exc:  # noqa: BLE001 - google levanta ValueError genéricos
            logger.warning(
                "Verificación de ID token de Google falló (aud esperado=%r): %s | claims sin verificar: %s",
                self._audience,
                exc,
                _peek_unverified(id_token),
            )
            raise AuthVerificationError("ID token de Google inválido") from exc

        # Validar emisor (Firebase/Google).
        iss = claims.get("iss", "")
        valid_issuers = {"https://accounts.google.com", "accounts.google.com"}
        if self._project_id:
            valid_issuers.add(f"https://securetoken.google.com/{self._project_id}")
        if iss not in valid_issuers:
            raise AuthVerificationError(f"emisor del ID token no confiable: {iss}")

        subject = claims.get("sub")
        if not subject:
            raise AuthVerificationError("ID token sin 'sub'")
        # Gate #2 acotado: descartamos email/nombre del token; SOLO el id opaco.
        return VerifiedIdentity(self.provider_name, subject)


def build_auth_provider(settings: Settings | None = None) -> AuthProvider:
    """Construye el proveedor según ``AUTH_PROVIDER`` (mock por defecto, gate #6)."""
    settings = settings or get_settings()
    kind = (settings.auth_provider or "mock").strip().lower()
    if kind == "firebase":
        return FirebaseAuthProvider(
            audience=settings.google_oauth_audience,
            project_id=settings.firebase_project_id,
        )
    # Default seguro para dev/QA/test: mock offline.
    return MockAuthProvider(accepted_token=settings.mock_google_token)


# Permite override en pruebas (igual patrón que broker/storage).
_provider: AuthProvider | None = None


def get_auth_provider() -> AuthProvider:
    global _provider
    if _provider is None:
        _provider = build_auth_provider()
    return _provider


def set_auth_provider(provider: AuthProvider | None) -> None:
    """Inyecta un proveedor (pruebas) o resetea a ``None`` para reconstruir desde config."""
    global _provider
    _provider = provider
