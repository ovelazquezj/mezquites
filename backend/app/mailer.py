"""Envío de correo para el reset de contraseña del administrador (CR-002).

Solo el ``administrador`` guarda email (gate #2 acotado), así que el reset por correo solo aplica a
ese rol. Si **no hay SMTP configurado**, el envío **degrada** a "reset por el administrador"
(riesgo §9 del CR) devolviendo ``False`` sin lanzar: el flujo sigue, pero sin correo.
"""

from __future__ import annotations

import smtplib
from email.message import EmailMessage

from .config import Settings, get_settings


def smtp_configured(settings: Settings | None = None) -> bool:
    settings = settings or get_settings()
    return bool(settings.smtp_host)


def send_password_reset(
    *, to_email: str, temp_password: str, settings: Settings | None = None
) -> bool:
    """Envía la contraseña temporal por SMTP. Devuelve ``True`` si se envió, ``False`` si degrada.

    No lanza ante fallos de red/SMTP: el reset sigue siendo válido (la contraseña ya se actualizó);
    el correo es el canal de entrega, y si falla el administrador la comunica manualmente.
    """
    settings = settings or get_settings()
    if not settings.smtp_host:
        return False

    msg = EmailMessage()
    msg["Subject"] = "Mezquite — Restablecimiento de contraseña"
    msg["From"] = settings.smtp_from
    msg["To"] = to_email
    msg.set_content(
        "Hola,\n\n"
        "Se restableció tu contraseña de la consola de administración de Mezquite.\n"
        f"Contraseña temporal: {temp_password}\n\n"
        "Inicia sesión y cámbiala de inmediato.\n"
    )

    try:
        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=10) as smtp:
            smtp.starttls()
            if settings.smtp_user and settings.smtp_password:
                smtp.login(settings.smtp_user, settings.smtp_password)
            smtp.send_message(msg)
        return True
    except Exception:  # noqa: BLE001 - degradar sin romper el reset
        return False
