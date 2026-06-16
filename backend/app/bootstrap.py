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

from .config import get_settings
from .db import get_sessionmaker
from .models import Account
from .security import generate_handle, hash_password


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
