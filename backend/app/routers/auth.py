"""Auth sin PII (gate #2, Q5.D-D1).

- ``POST /auth/register`` — crea un handle seudonimizado, devuelve token + código de respaldo.
  NO pide ni almacena email/teléfono/nombre.
- ``POST /auth/recover`` — recuperación por código de respaldo (hash). Sin PII.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..db import get_db
from ..models import Account
from ..schemas import RecoverRequest, RegisterRequest, RegisterResponse, TokenResponse
from ..security import (
    create_token,
    generate_backup_code,
    generate_handle,
    hash_backup_code,
    verify_backup_code,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=RegisterResponse, status_code=status.HTTP_201_CREATED)
def register(body: RegisterRequest, db: Session = Depends(get_db)) -> RegisterResponse:
    """Crea una cuenta seudonimizada. Sin PII (gate #2)."""
    backup_code = generate_backup_code()
    # Reintenta ante colisión improbable de handle.
    for _ in range(5):
        handle = generate_handle()
        account = Account(
            handle=handle,
            recovery_hash=hash_backup_code(backup_code),
            role=body.role,
            institution_id=body.institution_id,
        )
        db.add(account)
        try:
            db.commit()
            break
        except IntegrityError:
            db.rollback()
    else:  # pragma: no cover
        raise HTTPException(status_code=500, detail="no se pudo generar un handle único")

    db.refresh(account)
    token = create_token(account_id=account.id, handle=account.handle, role=account.role)
    return RegisterResponse(
        handle=account.handle, role=account.role, token=token, backup_code=backup_code
    )


@router.post("/recover", response_model=TokenResponse)
def recover(body: RecoverRequest, db: Session = Depends(get_db)) -> TokenResponse:
    """Recuperación de cuenta por código de respaldo (hash). Sin PII (gate #2)."""
    account = db.query(Account).filter(Account.handle == body.handle).one_or_none()
    if account is None or not verify_backup_code(body.backup_code, account.recovery_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="handle o código de respaldo inválido",
        )
    token = create_token(account_id=account.id, handle=account.handle, role=account.role)
    return TokenResponse(handle=account.handle, role=account.role, token=token)
