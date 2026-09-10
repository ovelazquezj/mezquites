"""Bootstrap del primer **administrador** (CR-002, cierra el hueco del gate #5).

No hay auto-registro de roles: el primer administrador se siembra por **config/CLI**, no por la API.

Uso:
    python -m backend.app.bootstrap --username admin --password 'S3cr3t' [--email admin@org.mx]

O por config (variables de entorno), idempotente al arranque/manual:
    BOOTSTRAP_ADMIN_USERNAME=admin BOOTSTRAP_ADMIN_PASSWORD=... python -m backend.app.bootstrap

Idempotente: si ya existe un usuario con ese ``username``, no hace nada (no pisa la contraseña).
"""

from __future__ import annotations

import argparse
import sys

from sqlalchemy.orm import Session

from .config import Settings, get_settings
from .db import get_sessionmaker
from .models import Account
from .security import generate_handle, hash_password


def es_cuenta_protegida(account: Account | None, settings: Settings) -> bool:
    """¿Es la **cuenta de administrador principal** (la sembrada por bootstrap)?

    CR-040: la consola ya administra cuentas de backend (buscar por `username`, eliminar por ARCO,
    cambiar rol). Sin una cuenta blindada, un administrador puede dejar el sistema **sin ningún
    administrador** — eliminando al último o degradándolo a `analista` — y entonces nadie puede
    volver a crear uno desde la API (el alta de administradores exige ser administrador; solo
    quedaría entrar al servidor a correr ``python -m backend.app.bootstrap``).

    La cuenta protegida es la que coincide con ``BOOTSTRAP_ADMIN_USERNAME`` (config). Si la variable
    no está configurada (o está vacía) **no hay cuenta protegida**: no se inventa una, porque
    blindar la cuenta equivocada sería peor que no blindar ninguna.
    """
    if account is None:
        return False
    protegido = (settings.bootstrap_admin_username or "").strip()
    if not protegido:
        return False
    return (account.username or "").strip() == protegido


def ensure_admin(
    db: Session, *, username: str, password: str, email: str | None = None
) -> tuple[Account, bool]:
    """Crea el administrador si no existe. Devuelve ``(account, created)``.

    Idempotente: si el username ya existe, lo devuelve sin tocarlo (``created=False``).
    """
    existing = db.query(Account).filter(Account.username == username).one_or_none()
    if existing is not None:
        return existing, False

    account = Account(
        handle=generate_handle(),
        auth_provider="password",
        username=username,
        password_hash=hash_password(password),
        email=email,  # permitido: rol administrador (gate #2 acotado)
        role="administrador",
        must_change_password=False,
    )
    db.add(account)
    db.commit()
    db.refresh(account)
    return account, True


def main(argv: list[str] | None = None) -> int:
    settings = get_settings()
    parser = argparse.ArgumentParser(description="Siembra el primer administrador (CR-002).")
    parser.add_argument("--username", default=settings.bootstrap_admin_username)
    parser.add_argument("--password", default=settings.bootstrap_admin_password)
    parser.add_argument("--email", default=settings.bootstrap_admin_email)
    args = parser.parse_args(argv)

    if not args.username or not args.password:
        print(
            "error: faltan --username/--password (o BOOTSTRAP_ADMIN_USERNAME/"
            "BOOTSTRAP_ADMIN_PASSWORD).",
            file=sys.stderr,
        )
        return 2

    SessionLocal = get_sessionmaker()
    db = SessionLocal()
    try:
        account, created = ensure_admin(
            db, username=args.username, password=args.password, email=args.email
        )
    finally:
        db.close()

    if created:
        print(f"administrador creado: username={account.username} handle={account.handle}")
    else:
        print(f"administrador ya existía: username={account.username} (sin cambios)")
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
