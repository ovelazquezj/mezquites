"""Dependencias FastAPI de autenticación y rol (3 roles, sin PII).

Roles (gate de roles): ``voluntario``, ``aliado_firmante``, ``admin_consorcio``.
``require_role`` exige un rol específico; la jerarquía es plana (no hay gating por nivel/
capacitación — gate #3: el rol es de **acceso a vistas**, nunca de funcionalidad por progreso).
"""

from __future__ import annotations

import uuid

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from .db import get_db
from .models import Account
from .security import decode_token


class CurrentUser:
    def __init__(self, account_id: uuid.UUID, handle: str, role: str) -> None:
        self.account_id = account_id
        self.handle = handle
        self.role = role


def _extract_bearer(authorization: str | None) -> str:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="falta el token Bearer",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return authorization.split(" ", 1)[1].strip()


def get_current_user(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> CurrentUser:
    token = _extract_bearer(authorization)
    try:
        payload = decode_token(token)
        account_id = uuid.UUID(payload["sub"])
    except (ValueError, KeyError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="token inválido",
            headers={"WWW-Authenticate": "Bearer"},
        )
    account = db.get(Account, account_id)
    if account is None:
        # CR-031: **410 Gone**, no 401. El token es válido pero la cuenta ya no existe (cancelación
        # ARCO, CR-006). La app necesita distinguir los dos casos porque hace lo CONTRARIO en cada
        # uno: ante 401 (token vencido) **conserva** las capturas sin subir y pide volver a entrar;
        # ante 410 **borra** la cola local, porque esa cuenta pidió dejar de existir. Antes ambos
        # eran 401 y solo se diferenciaban por el texto en español del `detail`: ramificar sobre esa
        # cadena significaba que reescribir un mensaje podía convertir "vuelve a entrar" en "borra
        # el trabajo del voluntario".
        raise HTTPException(status_code=status.HTTP_410_GONE, detail="cuenta eliminada")
    # El rol autoritativo es el de la DB (no el del token), por si cambió.
    return CurrentUser(account.id, account.handle, account.role)


def get_current_user_optional(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> CurrentUser | None:
    """Auth OPCIONAL (CR-019, gate #3): devuelve el usuario si el token es válido; ``None`` si falta
    o es inválido (NUNCA lanza 401). Reutiliza la misma decodificación que ``get_current_user`` para
    habilitar endpoints accesibles sin sesión (p.ej. reportar un problema antes de iniciar sesión).
    """
    if not authorization or not authorization.lower().startswith("bearer "):
        return None
    token = authorization.split(" ", 1)[1].strip()
    try:
        payload = decode_token(token)
        account_id = uuid.UUID(payload["sub"])
    except (ValueError, KeyError):
        return None
    account = db.get(Account, account_id)
    if account is None:
        return None
    return CurrentUser(account.id, account.handle, account.role)


def require_role(*roles: str):
    """Factoría de dependencia que exige uno de ``roles``."""

    def _dep(user: CurrentUser = Depends(get_current_user)) -> CurrentUser:
        if user.role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"requiere rol {' o '.join(roles)}",
            )
        return user

    return _dep
