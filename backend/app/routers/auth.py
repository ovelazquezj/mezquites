"""Auth (gate #2 acotado por CR-002).

- ``POST /auth/register`` — alta de **voluntario** seudónimo legado (sin `role`; cierra el hueco del
  gate #5). NO pide ni almacena email/teléfono/nombre.
- ``POST /auth/google`` — login social de la app: verifica el ID token de Google (mock|firebase),
  mapea ``social_google:sub`` → cuenta (la crea en el primer login con rol ``voluntario``) y emite
  nuestro JWT. Guarda SOLO el `sub` opaco (gate #2 acotado).
- ``POST /auth/login`` — usuario + contraseña (roles de backend, hash argon2) → JWT.
- ``POST /auth/recover`` — recuperación legada por código de respaldo (hash). Sin PII.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..auth_provider import AuthVerificationError, get_auth_provider
from ..config import get_settings
from ..db import get_db
from ..mailer import send_password_reset
from ..models import Account
from ..schemas import (
    GoogleLoginRequest,
    LoginRequest,
    PasswordResetRequest,
    PasswordResetResponse,
    RecoverRequest,
    RegisterRequest,
    RegisterResponse,
    TokenResponse,
)
from ..security import (
    create_token,
    generate_backup_code,
    generate_handle,
    generate_temp_password,
    handle_from_subject,
    hash_backup_code,
    hash_password,
    verify_backup_code,
    verify_password,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=RegisterResponse, status_code=status.HTTP_201_CREATED)
def register(body: RegisterRequest, db: Session = Depends(get_db)) -> RegisterResponse:
    """Alta de **voluntario** seudónimo (legado). Sin PII (gate #2).

    CR-002: el rol SIEMPRE es ``voluntario`` (el cliente no puede elegirlo). Esto cierra el hueco del
    gate #5 (auto-asignación de `aliado_firmante`/`admin_consorcio`/roles de backend). Los roles de
    backend los crea el administrador; el primer administrador se siembra por config/CLI.
    """
    backup_code = generate_backup_code()
    # Reintenta ante colisión improbable de handle.
    for _ in range(5):
        handle = generate_handle()
        account = Account(
            handle=handle,
            recovery_hash=hash_backup_code(backup_code),
            role="voluntario",  # CR-002: forzado; el cliente no asigna rol.
            auth_provider="social_google",
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


@router.post("/google", response_model=TokenResponse)
def login_google(body: GoogleLoginRequest, db: Session = Depends(get_db)) -> TokenResponse:
    """Login social de la app (CR-002). Verifica el ID token y mapea ``social_google:sub`` → cuenta.

    Gate #2 acotado: guarda SOLO el `sub` opaco (`provider_subject`); descarta email/nombre. En el
    primer login crea la cuenta con rol ``voluntario`` y un handle derivado del `sub`.
    """
    provider = get_auth_provider()
    try:
        identity = provider.verify_id_token(body.id_token)
    except AuthVerificationError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="ID token de Google inválido",
        ) from exc

    account = (
        db.query(Account)
        .filter(Account.provider_subject == identity.subject)
        .one_or_none()
    )
    if account is None:
        # Primer login: crea la cuenta (voluntario) con solo el id opaco.
        account = Account(
            handle=handle_from_subject(identity.provider, identity.subject),
            auth_provider="social_google",
            provider_subject=identity.subject,
            role="voluntario",
            institution_id=body.institution_id,
        )
        db.add(account)
        try:
            db.commit()
        except IntegrityError:
            # Carrera improbable: otra petición creó la cuenta; recupérala.
            db.rollback()
            account = (
                db.query(Account)
                .filter(Account.provider_subject == identity.subject)
                .one()
            )
        else:
            db.refresh(account)

    token = create_token(account_id=account.id, handle=account.handle, role=account.role)
    return TokenResponse(handle=account.handle, role=account.role, token=token)


@router.post("/login", response_model=TokenResponse)
def login(body: LoginRequest, db: Session = Depends(get_db)) -> TokenResponse:
    """Login de los roles de backend (CR-002): usuario + contraseña (hash argon2) → JWT."""
    account = (
        db.query(Account)
        .filter(Account.username == body.username, Account.auth_provider == "password")
        .one_or_none()
    )
    if account is None or not verify_password(body.password, account.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="usuario o contraseña inválidos",
        )
    token = create_token(account_id=account.id, handle=account.handle, role=account.role)
    return TokenResponse(
        handle=account.handle,
        role=account.role,
        token=token,
        must_change_password=account.must_change_password,
    )


@router.post("/password-reset", response_model=PasswordResetResponse)
def password_reset(
    body: PasswordResetRequest, db: Session = Depends(get_db)
) -> PasswordResetResponse:
    """Reset por correo del **administrador** (CR-002). Requiere email + SMTP; degrada si no hay.

    Solo aplica a cuentas ``administrador`` (las únicas con email, gate #2 acotado). Responde igual
    aunque el usuario no exista o no tenga email (no filtra existencia de cuentas).
    """
    settings = get_settings()
    account = (
        db.query(Account)
        .filter(Account.username == body.username, Account.role == "administrador")
        .one_or_none()
    )
    generic = PasswordResetResponse(
        delivered=False,
        message=(
            "Si la cuenta admite reset por correo, recibirás un mensaje. Si no, el administrador "
            "debe restablecer tu contraseña."
        ),
    )
    if account is None or not account.email:
        return generic

    temp = generate_temp_password()
    account.password_hash = hash_password(temp)
    account.must_change_password = True
    db.commit()

    delivered = send_password_reset(
        to_email=account.email, temp_password=temp, settings=settings
    )
    if delivered:
        return PasswordResetResponse(
            delivered=True, message="Te enviamos una contraseña temporal por correo."
        )
    return generic


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
