"""Gestión de usuarios de backend por el **administrador** (CR-002).

- ``GET  /admin/users`` — lista de usuarios de backend (sin exponer email; solo `has_email`).
- ``POST /admin/users`` — crea evaluador/analista/administrador con username + contraseña temporal.
- ``PATCH /admin/users/{id}`` — cambia el rol.
- ``POST /admin/users/{id}/reset`` — el administrador dispara un reset (nueva contraseña temporal).

Gate de rol: SOLO ``administrador`` (no `admin_consorcio`, que gestiona la consola del consorcio).
Gate #2 acotado: ``email`` SOLO es válido para `administrador`; el endpoint lo valida y nunca lo
expone en las respuestas (solo `has_email`).
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..deps import CurrentUser, require_role
from ..db import get_db
from ..models import EMAIL_ALLOWED_ROLES, Account
from ..schemas import (
    AdminCreateUserRequest,
    AdminCreateUserResponse,
    AdminPatchUserRequest,
    AdminResetResponse,
    AdminUserResponse,
)
from ..security import generate_handle, generate_temp_password, hash_password

router = APIRouter(prefix="/admin/users", tags=["admin-users"])

_administrador = require_role("administrador")

_BACKEND_ROLES = ("administrador", "evaluador", "analista")


def _to_response(account: Account) -> AdminUserResponse:
    return AdminUserResponse(
        id=account.id,
        handle=account.handle,
        username=account.username,
        role=account.role,
        has_email=bool(account.email),
        must_change_password=account.must_change_password,
    )


@router.get("", response_model=list[AdminUserResponse])
def list_users(
    user: CurrentUser = Depends(_administrador), db: Session = Depends(get_db)
) -> list[AdminUserResponse]:
    rows = (
        db.query(Account)
        .filter(Account.auth_provider == "password")
        .order_by(Account.username)
        .all()
    )
    return [_to_response(a) for a in rows]


@router.post("", response_model=AdminCreateUserResponse, status_code=status.HTTP_201_CREATED)
def create_user(
    body: AdminCreateUserRequest,
    user: CurrentUser = Depends(_administrador),
    db: Session = Depends(get_db),
) -> AdminCreateUserResponse:
    """Crea un usuario de backend con contraseña temporal (invitación)."""
    if body.email and body.role not in EMAIL_ALLOWED_ROLES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="solo el rol 'administrador' puede tener email (gate #2 acotado)",
        )

    temp_password = generate_temp_password()
    # Reintenta ante colisión improbable de handle.
    account: Account | None = None
    for _ in range(5):
        candidate = Account(
            handle=generate_handle(),
            auth_provider="password",
            username=body.username,
            password_hash=hash_password(temp_password),
            email=body.email if body.role in EMAIL_ALLOWED_ROLES else None,
            role=body.role,
            must_change_password=True,
        )
        db.add(candidate)
        try:
            db.commit()
            account = candidate
            break
        except IntegrityError:
            db.rollback()
            # Si el choque es por username (no por handle), no insistir: es un 409.
            exists = (
                db.query(Account).filter(Account.username == body.username).count() > 0
            )
            if exists:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="el nombre de usuario ya existe",
                )
    if account is None:  # pragma: no cover
        raise HTTPException(status_code=500, detail="no se pudo crear el usuario")

    db.refresh(account)
    base = _to_response(account)
    return AdminCreateUserResponse(**base.model_dump(), temp_password=temp_password)


@router.patch("/{user_id}", response_model=AdminUserResponse)
def patch_user(
    user_id: uuid.UUID,
    body: AdminPatchUserRequest,
    user: CurrentUser = Depends(_administrador),
    db: Session = Depends(get_db),
) -> AdminUserResponse:
    account = db.get(Account, user_id)
    if account is None or account.auth_provider != "password":
        raise HTTPException(status_code=404, detail="usuario no encontrado")
    if body.role is not None:
        if body.role not in _BACKEND_ROLES:
            raise HTTPException(status_code=400, detail="rol inválido")
        # Si baja de administrador, el email deja de ser válido (gate #2 acotado): se limpia.
        if body.role not in EMAIL_ALLOWED_ROLES:
            account.email = None
        account.role = body.role
    db.commit()
    db.refresh(account)
    return _to_response(account)


@router.post("/{user_id}/reset", response_model=AdminResetResponse)
def reset_user(
    user_id: uuid.UUID,
    user: CurrentUser = Depends(_administrador),
    db: Session = Depends(get_db),
) -> AdminResetResponse:
    """El administrador dispara un reset: nueva contraseña temporal (para evaluador/analista sin email)."""
    account = db.get(Account, user_id)
    if account is None or account.auth_provider != "password":
        raise HTTPException(status_code=404, detail="usuario no encontrado")
    temp = generate_temp_password()
    account.password_hash = hash_password(temp)
    account.must_change_password = True
    db.commit()
    db.refresh(account)
    return AdminResetResponse(id=account.id, username=account.username, temp_password=temp)
