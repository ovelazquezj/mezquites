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
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="cuenta no existe")
    # El rol autoritativo es el de la DB (no el del token), por si cambió.
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
