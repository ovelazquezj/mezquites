"""Reportar un problema (CR-019) — diagnóstico de fallas para depurar.

- ``POST /problem-reports`` — auth OPCIONAL (gate #3, sin gating): el botón es accesible ANTES de
  iniciar sesión (p.ej. desde el error de cámara). Si hay token válido se adjunta ``account_id``/
  ``handle``; si falta o es inválido, el reporte es anónimo (201 igual). Gate #2 (sin PII): solo
  metadatos técnicos de diagnóstico + handle seudónimo; NUNCA email/nombre/teléfono.
- ``GET  /admin/problem-reports`` — el administrador (consola) consulta los reportes para depurar.
- ``POST /admin/problem-reports/{id}/status`` — marca 'visto'/'resuelto' (o de vuelta a 'nuevo').
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ..db import get_db
from ..deps import CurrentUser, get_current_user_optional, require_role
from ..models import ProblemReport
from ..schemas import ProblemReportCreate, ProblemReportOut, ProblemReportStatusIn

router = APIRouter(tags=["problem-reports"])

# Mismo set de roles de "consola del proyecto" que admin.py (require_role("admin_consorcio",
# "administrador")): el administrador (y el legacy admin_consorcio) ven/depuran los reportes.
_admin = require_role("admin_consorcio", "administrador")


def _to_out(r: ProblemReport) -> ProblemReportOut:
    return ProblemReportOut(
        id=r.id,
        created_at=r.created_at,
        status=r.status,
        handle=r.handle,
        context=r.context,
        message=r.message,
        error_detail=r.error_detail,
        user_agent=r.user_agent,
        platform=r.platform,
        app_version=r.app_version,
    )


@router.post(
    "/problem-reports",
    response_model=ProblemReportOut,
    status_code=status.HTTP_201_CREATED,
)
def create_problem_report(
    body: ProblemReportCreate,
    user: CurrentUser | None = Depends(get_current_user_optional),
    db: Session = Depends(get_db),
) -> ProblemReportOut:
    """Crea un reporte de problema. Auth OPCIONAL (gate #3): anónimo si no hay sesión válida."""
    report = ProblemReport(
        account_id=user.account_id if user else None,
        handle=user.handle if user else None,
        context=body.context,
        message=body.message,
        error_detail=body.error_detail,
        user_agent=body.user_agent,
        platform=body.platform,
        app_version=body.app_version,
        status="nuevo",
    )
    db.add(report)
    db.commit()
    db.refresh(report)
    return _to_out(report)


@router.get("/admin/problem-reports", response_model=list[ProblemReportOut])
def list_problem_reports(
    user: CurrentUser = Depends(_admin),
    db: Session = Depends(get_db),
) -> list[ProblemReportOut]:
    """Lista los reportes para depurar, más recientes primero."""
    rows = db.query(ProblemReport).order_by(ProblemReport.created_at.desc()).all()
    return [_to_out(r) for r in rows]


@router.post("/admin/problem-reports/{report_id}/status", response_model=ProblemReportOut)
def set_problem_report_status(
    report_id: uuid.UUID,
    body: ProblemReportStatusIn,
    user: CurrentUser = Depends(_admin),
    db: Session = Depends(get_db),
) -> ProblemReportOut:
    """Marca el reporte como 'visto'/'resuelto' (o de vuelta a 'nuevo')."""
    report = db.get(ProblemReport, report_id)
    if report is None:
        raise HTTPException(status_code=404, detail="reporte no encontrado")
    report.status = body.status
    db.commit()
    db.refresh(report)
    return _to_out(report)
